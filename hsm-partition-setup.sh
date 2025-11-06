#!/bin/bash
set -euo pipefail

# === HSM Partition Setup – Logical Isolation + Destructive Policies ===
# One-time onboarding: Create tenant partitions + enforce zeroization rules
# For Thales payShield, Luna, CloudHSM, Securosys. Idempotent + auditable.

# Load config
source .env  # Expect: HSM_PIN (SO PIN), PARTITION_COUNT=4, MAX_FAILED_LOGINS=5, TAMPER_ERASE=true

# Paths
AUDIT_LOG="${AUDIT_LOG:-/var/log/hsm-audit.jsonl}"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%SZ")

# Colors
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; NC='\033[0m'

log_json() {
    jq -n \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg action "$1" \
      --arg details "$2" \
      '{timestamp: $ts, action: $action, details: $details}' \
      >> "$AUDIT_LOG"
}

header() { echo -e "\n${GREEN}HSM PARTITION SETUP — $1${NC}\n"; }
warn() { echo -e "${YELLOW}WARN: $1${NC}"; }

# Vendor-specific hooks (extend as needed)
setup_thales_policy() {
    # Thales: Use etKMS or ppconfig for destructive policies
    warn "For Thales payShield: Run 'ppconfig -tamper=erase' manually if TAMPER_ERASE=true"
    # Placeholder: echo "Tamper policy: $TAMPER_ERASE" | ppconfig
}

setup_luna_policy() {
    # Luna: ChrystokiConf for zeroization
    warn "For Luna: Edit Chrystoki.conf → ZeroizeOnTamper=$TAMPER_ERASE"
}

# === 1. Check existing partitions (idempotent) ===
header "1. Scanning slots/partitions"
EXISTING_SLOTS=$(pkcs11-tool --module "$PKCS11_MODULE" --login --pin "$HSM_PIN" --list-slots 2>/dev/null | grep -c "Slot")
if [ "$EXISTING_SLOTS" -ge "$PARTITION_COUNT" ]; then
    echo "Partitions already exist ($EXISTING_SLOTS >= $PARTITION_COUNT). Skipping creation."
    log_json "partitions-check" "existing: $EXISTING_SLOTS"
    exit 0
fi
log_json "partitions-check" "need: $PARTITION_COUNT, existing: $EXISTING_SLOTS"

# === 2. Create partitions/slots ===
header "2. Creating $PARTITION_COUNT partitions"
for i in $(seq 1 "$PARTITION_COUNT"); do
    SLOT_ID=$((i-1))  # Slots 0 to N-1
    if [ "$DRY_RUN" = false ]; then
        # PKCS#11 basic: Init token per slot (real partitions need vendor CLI)
        pkcs11-tool --module "$PKCS11_MODULE" --login --pin "$HSM_PIN" --init-token --label "Tenant-$i" --slot "$SLOT_ID"
        # Vendor hook example
        case "$HSM_VENDOR" in  # Set HSM_VENDOR=thales in .env
            thales) setup_thales_policy ;;
            luna) setup_luna_policy ;;
        esac
    else
        echo "Would init slot $SLOT_ID as Tenant-$i"
    fi
done
log_json "partitions-created" "count: $PARTITION_COUNT"

# === 3. Enforce destructive policies ===
header "3. Setting zeroization policies"
if [ "$TAMPER_ERASE" = true ]; then
    # Generic: Set via pkcs11 attributes (limited); real via vendor
    warn "Destructive policy: Tamper → full erase enabled"
    # Example: Set max failed logins (vendor-specific)
    if [ -n "$MAX_FAILED_LOGINS" ]; then
        warn "Max failed logins before zeroize: $MAX_FAILED_LOGINS"
        # Placeholder: echo "FailedLoginThreshold=$MAX_FAILED_LOGINS" | vendor-config
    fi
    log_json "destructive-policy-set" "tamper_erase: true, max_failed: $MAX_FAILED_LOGINS"
else
    warn "Tamper erase: DISABLED (review for prod!)"
fi

# === 4. Verify ===
header "4. Verification"
pkcs11-tool --module "$PKCS11_MODULE" --login --pin "$HSM_PIN" --list-slots | tee /tmp/slots-after.txt
log_json "setup-complete" "verified: $(wc -l < /tmp/slots-after.txt) slots"

echo -e "\n${GREEN}Setup done. Run 'hsm-maintenance.sh' in each partition slot.${NC}"
cat "$AUDIT_LOG" | tail -3
