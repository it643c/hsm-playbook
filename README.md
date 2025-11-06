# HSM Playbook – Zero-Downtime PKCS#11 Key Rotation Engine

**Production-grade • Dry-run safe • Pure JSONL audit • AES-256 backups • Tamper-zeroize policies**

Drop-in replacement for manual HSM ops on **Thales payShield • Luna NetHSM • AWS CloudHSM • Securosys Primus**

Live repo: https://github.com/it643c/hsm-playbook  
Already forked by two EU banks and one top-20 exchange.

### Full HSM Lifecycle Suite
- `hsm-partition-setup.sh` → one-time onboarding: partitions + destructive policies  
- `hsm-troubleshoot.sh` → hardware incident response bible (every error code known to man)

### Why this exists
Manual HSM ops = single point of failure.  
I’ve seen rotations cost €7-figures in downtime.  
This suite removes the human without removing the proof.

### Architecture
Cron → hsm-partition-setup.sh (once)
   ↓
Cron → hsm-maintenance.sh (monthly per slot)
   ↓
Encrypted backup + append-only JSONL audit → SIEM

### 2-minute production deploy
```bash
git clone https://github.com/it643c/hsm-playbook.git
cd hsm-playbook
cp .env.example .env
# edit .env → PKCS11_MODULE, HSM_PIN, BACKUP_PASS

# 1. Onboard HSM (once)
./hsm-partition-setup.sh --dry-run
./hsm-partition-setup.sh

# 2. Monthly rotation (example slot 0)
SLOT_ID=0 ./hsm-maintenance.sh --dry-run
SLOT_ID=0 ./hsm-maintenance.sh --execute

FeaturesDry-run mode (no changes)
Idempotent everything
Pure JSONL audit log (RFC3339 UTC, one line per event)
AES-256-CBC + PBKDF2 encrypted backups
24 h old-key overlap → zero customer impact
Multi-tenant partition isolation
Tamper → full zeroize + max failed logins → erase
MPC-sharding ready (keys exportable)
Works on any PKCS#11 HSM
Zero runtime dependencies (just bash + pkcs11-tool)

Audit log example (/var/log/hsm-audit.jsonl)json

{"timestamp":"2025-11-06T18:00:00Z","action":"rotation-complete","key_label":"master-encryption-key","slot":"0","backup_path":"/opt/hsm-backups/hsm-keys-20251106-180000Z.aes","dry_run":"false"}

Looking for the next security engineering role in crypto custody, insurance, or government.
Need someone who ships fortified systems that make auditors smile.
DM me.
I deploy next week.

#CryptoSecurity #HSM #PKCS11 #KeyRotation #ZeroTrust #OpenSource
