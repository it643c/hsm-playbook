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

Features that end outagesDry-run on every script  
Pure JSONL audit (RFC3339 UTC) → Splunk/ELK ready  
AES-256-CBC + PBKDF2 encrypted backups  
24 h old-key overlap → zero customer impact  
Auto-clear non-destructive tampers  
Multi-tenant isolation  
MPC-sharding ready  
Zero runtime deps (just bash + pkcs11-tool)

Audit examplejson

{"timestamp":"2025-11-06T19:11:22Z","action":"system-health","slot":"2","battery":"3.3V","temp":"41C","tamper":"clear","firmware":"7.8.2","status":"OK"}

Incident Bible→ hsm-troubleshoot.sh – every hardware error code known to man + exact fix

# Robert Blake | 53. Still Dangerous.

> “The best candidates look like they can’t hold a job.”  
> — Paul Graham, 2008

**I fix encryption & IAM fires before the regulators land.**

- Kept F-16s flying (USAF "94–’98)  
- Locked down ITAR data @ Boeing  
- Built Thales CipherTrust walls around $50M card data @ Wells Fargo (twice)  
- 15 Power BI dashboards catching AML fraud @ Northwestern Mutual right now  

Every “job hop” = another company that called me when the audit clock was at 29 days.

Currently shipping:  
→ Power BI + Kusto dashboards that reduced false positives by 25%  
→ Terraform + Azure Policy sets for CMMC 2.0 Level 2  
→ Python scripts that rotate 40,000 keys without downtime  

If your GRC / FinCEN / PCI program is on fire, I’ve already fixed your exact problem.

**DM me before the auditors do.**  
robert.blake@proton.me | (602) 487-0467

#Over53AndDangerous

Looking for my next role: HSM Fleet Lead – crypto custody, insurance, or government.
I deploy Day-1, auditors smile, Day 2, you save $400k/year on Thales support.
DM me if interested
#CryptoSecurity #HSM #PKCS11 #ZeroTrust #OpenSource 
