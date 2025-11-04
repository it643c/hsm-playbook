#!/bin/bash
# hsm-maintenance.sh
# Author: it643c
# Purpose: Production HSM maintenance with audit, safety, and idempotency

set -euo pipefail

[[ -f "./hsm-config.sh" ]] && source ./hsm-config.sh || { echo "ERROR: hsm-config.sh missing"; exit 1; }

LOG="${LOG:-/var/log/hsm-audit.log}"
MODULE="${MODULE:-/opt/cloudhsm/lib/libcloudhsm.so}"
KEY_LABEL="${KEY_LABEL:-signing-key}"
KEY_ID="${KEY_ID:-02}"
PIN="${HSM_PIN:-}"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

log() {
  local msg="[$(date -Iseconds)] $*"
  echo "$msg" | tee -a "$LOG"
}

check_prereqs() {
  command -v pkcs11-tool >/dev/null || { log "ERROR: pkcs11-tool missing"; exit 1; }
  [[ -f "$MODULE" ]] || { log "ERROR: HSM module not found at $MODULE"; exit 1; }
  [[ -n "$PIN" ]] || { log "ERROR: HSM_PIN not set in environment"; exit 1; }
  mkdir -p "$(dirname "$LOG")"
}

health_check() {
  if pkcs11-tool --module "$MODULE" --show-info >/dev/null 2>&1; then
    log "HSM module loaded and responsive"
  else
    log "ERROR: HSM module not responding"
    exit 1
  fi
}

list_keys() {
  log "Listing HSM objects:"
  pkcs11-tool --module "$MODULE" --login --pin "$PIN" --list-objects | tee -a "$LOG"
}

backup_old_key() {
  local old_label="${KEY_LABEL}-old"
  if pkcs11-tool --module "$MODULE" --login --pin "$PIN" --list-objects | grep -q "Label:.*$old_label"; then
    log "Old key backup already exists: $old_label"
    return
  fi

  if pkcs11-tool --module "$MODULE" --login --pin "$PIN" --list-objects | grep -q "Label:.*$KEY_LABEL"; then
    log "Backing up current key pubkey to ${KEY_LABEL}-old-pubkey.pem"
    if [[ "$DRY_RUN" == false ]]; then
      pkcs11-tool --module "$MODULE" --login --pin "$PIN" \
        --read-object --type pubkey --label "$KEY_LABEL" --output-file "${KEY_LABEL}-old-pubkey.pem"
      pkcs11-tool --module "$MODULE" --login --pin "$PIN" \
        --write-attribute --label "$old_label" --id "$KEY_ID" || true
    fi
    log "Backup complete: ${KEY_LABEL} → $old_label"
  fi
}

rotate_key() {
  if pkcs11-tool --module "$MODULE" --login --pin "$PIN" --list-objects | grep -q "Label:.*$KEY_LABEL"; then
    log "Key '$KEY_LABEL' already exists. Skipping generation (idempotent)."
    return
  fi

  log "Rotating key -> Label: $KEY_LABEL, ID: $KEY_ID"
  if [[ "$DRY_RUN" == true ]]; then
    log "DRY-RUN: Would run: pkcs11-tool --keypairgen --label $KEY_LABEL --id $KEY_ID"
  else
    pkcs11-tool --module "$MODULE" --login --pin "$PIN" \
      --keypairgen --key-type rsa:2048 --label "$KEY_LABEL" --id "$KEY_ID"
    log "New key generated: $KEY_LABEL"
  fi
}

main() {
  log "=== HSM MAINTENANCE RUN STARTED (DRY_RUN=$DRY_RUN) ==="
  check_prereqs
  health_check
  list_keys
  backup_old_key
  rotate_key
  log "=== HSM MAINTENANCE RUN COMPLETED ==="
}

main "$@"
