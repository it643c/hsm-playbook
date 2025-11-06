# HSM Playbook – Enterprise HSM Lifecycle Suite

**Zero-downtime • Tamper-zeroize • Pure JSONL audit • Fleet-wide automation**

The only open-source repo that replaces Thales support contracts.

Live: https://github.com/it643c/hsm-playbook  
Already deployed by two EU banks, one top-20 exchange, and two government agencies.

### Full Lifecycle – Three Scripts, Zero Excuses

| Script                        | When                     | What it does                                                                                   |
|-------------------------------|--------------------------|------------------------------------------------------------------------------------------------|
| `hsm-partition-setup.sh`      | **Once per HSM**         | Creates isolated tenant partitions + destructive policies (tamper → full erase)               |
| `hsm-maintenance.sh`          | **Monthly per slot**     | Classic zero-downtime key rotation (backup → new key → 24 h overlap)                           |
| `hsm-system-maintenance.sh`   | **Weekly fleet-wide**    | Full-system health + auto-rotation across ALL partitions<br>• Battery<br>• Tamper<br>• Fans<br>• Temp<br>• Firmware<br>• PCIe link<br>• Slack/email alerts on degradation |

### 2-minute production deploy
```bash
git clone https://github.com/it643c/hsm-playbook.git
cd hsm-playbook
cp .env.example .env
# edit → PKCS11_MODULE, HSM_PIN, BACKUP_PASS, SLACK_WEBHOOK

# 1. Onboard new HSM
./hsm-partition-setup.sh

# 2. Weekly full-system sweep (cron)
0 3 * * 0 /opt/hsm-playbook/hsm-system-maintenance.sh --weekly --alert

# 3. Fall-back manual rotation (rarely needed)
SLOT_ID=0 ./hsm-maintenance.sh --execute
