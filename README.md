# HSM Playbook – Production-Grade HSM Automation

**Zero-downtime key rotation • Full audit trail • FIPS 140-2 ready • Crypto-custody battle-tested**

Used in real production environments for Thales payShield, Luna NetHSM, AWS CloudHSM, and Securosys Primus.

### Why this exists
Manual HSM ops = single point of failure.  
This tool automates the entire key lifecycle (generate → label → rotate → destroy) with:
- Dry-run mode
- Idempotent execution
- Encrypted backups
- On-chain-ready audit logs

### Architecture (30-second overview)

Cron/Scheduler → hsm-maintenance.sh → PyKCS11 → HSM
       ↓
Encrypted backup + JSON audit log (append-only)

FeaturesSafe rotation with 24h old-key overlap
Automatic backup to AES-256 encrypted file
Zero hard-coded secrets
Works with any PKCS#11 HSM
3-line cron setup for monthly rotation
MPC-sharding prep (keys exportable for shamir splits)

Get it running in 2 minutes

### One-command demo
```bash
git clone https://github.com/it643c/hsm-playbook.git
cd hsm-playbook
cp .env.example .env
# edit .env → put your HSM_PIN and SLOT
./hsm-maintenance.sh --dry-run      # see exactly what will happen
./hsm-maintenance.sh --execute      # DO IT

