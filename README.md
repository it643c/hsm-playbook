# HSM Playbook — Production HSM Ops in One Command

**Zero-trust. Auditable. Idempotent. FIPS-ready.**

---

## Features
- Health check
- Key inventory
- **Safe rotation** (backup + idempotent)
- **Dry-run mode**
- Full audit log
- Config-driven (no hardcoding)

---

## Quick Start (Demo)

```bash
# 1. Clone
git clone https://github.com/it643c/hsm-playbook
cd hsm-playbook

# 2. Copy config + secrets
cp hsm-config.sh hsm-config-prod.sh
cp .env.example .env
nano .env  # ← Add real PIN

# 3. Test (DRY RUN)
export HSM_PIN=$(grep HSM_PIN .env | cut -d= -f2)
./hsm-maintenance.sh --dry-run

# 4. Run for real
./hsm-maintenance.sh
