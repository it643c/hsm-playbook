#!/bin/bash
# =============================================================================
# HSM System Maintenance Playbook – v2.0 FULL (FLAT)
# Directory: ~/hsm-playbook/
# Files expected in same folder:
#   - config.env
#   - partitions.yaml
#   - docs/, grafana/, .github/
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── LOAD LOCAL ENV (config.env) ─────────────────────────────────────────────
[[ -f config.env ]] && source config.env || echo "WARN: config.env not found – using defaults"

# ── CONFIG ───────────────────────────────────────────────────────────────────
: "${HSM_TYPE:=luna}"
: "${HSM_ID:=hsm-prod-01}"
: "${VAULT_ADDR:=https://vault.corp.local:8200}"
: "${CIPHERTRUST_API:=https://ciphertrust.corp/api/v2}"
: "${SLACK_WEBHOOK:=}"
: "${DRY_RUN:=false}"
: "${LOG_FILE:=$HOME/hsm-playbook.log}"
: "${BACKUP_DIR:=/opt/hsm/backup}"
: "${PARTITION_CONFIG:=partitions.yaml}"
: "${GRAFANA_DASHBOARD:=grafana/dashboard.json}"

# ── LOGGING ─────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local msg="$*"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$ts [$HSM_ID] [$level] $msg" >> "$LOG_FILE"
    logger -t "hsm-maint[$HSM_ID]" -p local0."${level,,}" "$msg"
    [[ "$level" == "ERROR" ]] && notify_slack "ERROR: $msg" && exit 1
}

notify_slack() {
    [[ -z "$SLACK_WEBHOOK" ]] && return
    curl -s -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"[HSM] $1\"}"
}

# ── VAULT HELPERS ───────────────────────────────────────────────────────────
vault_get() {
    local path="$1"
    if [[ "$DRY_RUN" == "true" ]]; then echo "[DRY] vault kv get $path"; return 0; fi
    vault kv get -field=data "$path"
}

vault_put() {
    local path="$1" value="$2"
    if [[ "$DRY_RUN" == "true" ]]; then echo "[DRY] vault kv put $path"; return 0; fi
    vault kv put "$path" data="$value"
}

vault_login() {
    if [[ "$DRY_RUN" == "true" ]]; then VAULT_TOKEN="dry-run-token"; export VAULT_TOKEN; return; fi
    VAULT_TOKEN=$(vault login -method=ldap username="$USER" password="$PASS" -format=json | jq -r .auth.client_token)
    export VAULT_TOKEN
}

# ── CIPHERTRUST QUERY ───────────────────────────────────────────────────────
ciphertrust_query() {
    local endpoint="$1"
    if [[ "$DRY_RUN" == "true" ]]; then echo "[DRY] curl $CIPHERTRUST_API/$endpoint"; return 0; fi
    curl -s -H "Authorization: Bearer $CIPHERTRUST_TOKEN" "$CIPHERTRUST_API/$endpoint"
}

# ── PARTITION FRAMEWORK ─────────────────────────────────────────────────────
load_partitions() {
    if [[ ! -f "$PARTITION_CONFIG" ]]; then log "ERROR" "Missing $PARTITION_CONFIG"; fi
    PARTITIONS=$(yq eval '.partitions | to_entries[]' "$PARTITION_CONFIG")
}

create_partition() {
    local name="$1" kek_path="$2" classification="$3" policy="$4"
    log "INFO" "Creating partition: $name ($classification)"
    if [[ "$DRY_RUN" == "false" ]]; then
        case "$HSM_TYPE" in
            luna)
                lunacm <<EOF
partition create -partition $name -password $(vault_get "$kek_path")
quit
EOF
                ;;
            *) log "WARN" "HSM_TYPE $HSM_TYPE not yet implemented for partition creation" ;;
        esac
    fi
    apply_destructive_policy "$name" "$policy"
}

apply_destructive_policy() {
    local partition="$1" policy="$2"
    log "INFO" "Applying policy '$policy' to $partition"
    case "$policy" in
        zeroize_on_tamper)
            [[ "$DRY_RUN" == "true" ]] && return 0
            lunacm <<EOF
hsm set policy -policy 33 -value 1
quit
EOF
            ;;
        revoke_and_zeroize)
            revoke_keys_in_partition "$partition"
            zeroize_partition "$partition"
            ;;
        *) log "WARN" "Unknown policy: $policy" ;;
    esac
}

zeroize_partition() {
    local partition="$1"
    log "WARN" "ZEROIZING PARTITION $partition"
    [[ "$DRY_RUN" == "true" ]] && return 0
    lunacm <<EOF
partition zeroize -partition $partition -force
quit
EOF
}

revoke_keys_in_partition() {
    local partition="$1"
    log "INFO" "Revoking all keys in $partition (placeholder)"
    # Implement PKCS#11 or vendor API call here
}

# ── DEK/KEK GENERATION ──────────────────────────────────────────────────────
generate_deks() {
    local partition="$1" count="$2" kek_path="$3"
    log "INFO" "Generating $count DEKs for $partition"
    for i in $(seq 1 "$count"); do
        local dek_id="dek-${partition}-$(printf "%03d" $i)"
        local dek_key=$(openssl rand -hex 32)
        vault_put "secret/hsm/dek/$dek_id" "$dek_key"
        log "INFO" "DEK $dek_id stored in Vault"
    done
}

# ── CLASSIFICATION-FLIP MONITOR ─────────────────────────────────────────────
monitor_classifications() {
    log "INFO" "Polling CipherTrust for classification changes..."
    local changes
    changes=$(ciphertrust_query "ddc/classifications?filter=updated>15m" | \
              jq -r '.data[] | "\(.asset_id):\(.old_tag)→\(.new_tag)"' 2>/dev/null || echo "")
    [[ -z "$changes" ]] && { log "INFO" "No recent changes"; return; }

    for c in $changes; do
        local asset=$(echo "$c" | cut -d: -f1)
        log "ALERT" "Classification flip: $c"
        rekey_asset "$asset"
    done
}

rekey_asset() {
    local asset="$1"
    log "INFO" "Rekeying asset $asset under stricter KEK"
    generate_deks "$asset" 1 "secret/hsm/kek/restricted"
}

# ── BACKUP & DR ─────────────────────────────────────────────────────────────
perform_backup_all() {
    log "INFO" "Backing up partitions..."
    [[ "$DRY_RUN" == "true" ]] && return 0
    # Example for one partition – loop over PARTITIONS in prod
    lunacm <<EOF
partition backup -partition payment -slot 2 -password $(vault_get "secret/hsm/backup-pass")
quit
EOF
}

dr_drill() {
    log "WARN" "=== DR DRILL START ==="
    zeroize_partition "dr-test"
    # restore logic placeholder
    log "INFO" "DR drill completed"
}

export_grafana_dashboard() {
    [[ -f "$GRAFANA_DASHBOARD" ]] && cp "$GRAFANA_DASHBOARD" /shared/grafana/ || true
}

# ── MAIN ORCHESTRATOR ───────────────────────────────────────────────────────
main() {
    log "INFO" "=== HSM Playbook v2.0 FULL STARTED ==="
    vault_login
    load_partitions

    # Process each partition from YAML
    while IFS= read -r entry; do
        local name=$(echo "$entry" | yq eval '.key')
        local class=$(echo "$entry" | yq eval '.value.classification')
        local kek=$(echo "$entry" | yq eval '.value.kek_path')
        local cnt=$(echo "$entry" | yq eval '.value.dek_count // 0')
        local pol=$(echo "$entry" | yq eval '.value.destructive_policy // "none"')

        create_partition "$name" "$kek" "$class" "$pol"
        [[ "$cnt" -gt 0 ]] && generate_deks "$name" "$cnt" "$kek"
    done <<< "$PARTITIONS"

    monitor_classifications
    perform_backup_all
    [[ "${DR_MODE:-false}" == "true" ]] && dr_drill
    export_grafana_dashboard

    log "INFO" "=== PLAYBOOK COMPLETE ==="
}

main "$@"

mkdir -p "$(dirname "$LOG_FILE")"

# (Paste the entire script above here)
