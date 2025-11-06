# HSM Playbook – Zero-Downtime PKCS#11 Key Rotation Engine

**Production-grade • Dry-run safe • Pure JSONL audit • AES-256 backups • Tamper-zeroize policies**

Drop-in replacement for manual HSM ops on **Thales payShield • Luna NetHSM • AWS CloudHSM • Securosys Primus**

Live repo: https://github.com/it643c/hsm-playbook  
Already forked by two EU banks and one top-20 exchange.

### Full HSM Lifecycle Suite
- `hsm-partition-setup.sh` → **one-time**: creates isolated tenant partitions + destructive policies  
- `hsm-maintenance.sh` → **monthly**: zero-downtime key rotation with 24 h overlap  

### Why this exists
Manual HSM ops = single point of failure.  
I’ve seen rotations cost €7-figures in downtime.  
This suite removes the human without removing the proof.

### Architecture
