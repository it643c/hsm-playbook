#!/bin/bash
# HSM Hardware Incident Response Bible
# Usage: cat hsm-troubleshoot.sh | less
#        or ./hsm-troubleshoot.sh to print the table

cat << 'EOF'

General HSM Troubleshooting SOP (High-Level Workflow)

Follow this sequence for any HSM incident. Time estimate: 15-60 minutes initial triage; escalate to vendor RMA if unresolved.

1. Isolate & Log the Issue  
*Document symptoms: Error code, timestamp, recent changes (e.g., firmware update, power cycle).  
*Check logs: syslog tail or /var/log/hsm-audit.jsonl (from your repo). Enable verbose: hsm show policies -strict.  
*Verify basics: Power cycle (unplug/replug AC/USB), reseat cables/adapters, and confirm PCIe slot firmness.

2. Run Diagnostics  
*Execute vendor tools: hsmstate (Thales/payShield) or pkcs11-tool --list-slots (PKCS11). Expected: "NORMAL mode, Responding."
*Test connectivity: hsm ped connect -ip <PED_IP> (Luna) or ping HSM IP (Network HSM). Open ports 1792 (TCP/NTLS), 1502-1503 (PED).  
*Dry-run a simple op: ./hsm-maintenance.sh --dry-run (your script) to isolate software vs. hardware.

3. Apply Immediate Remediation  
*See the table below for issue-specific steps. Prioritize non-destructive fixes (e.g., reset over zeroize).

4. Verify & Audit  
*Re-test: hsm information show or list objects (pkcs11-tool --list-objects).  
*Log outcome: Append to JSONL audit (e.g., {"action":"troubleshoot-complete", "issue":"tamper-clear", "resolved":true}).  
*Backup keys/partitions before destructive actions.

5. Escalate if Needed  
*If unresolved: Contact vendor (Thales Support Portal) with serial number, logs, and error codes. For Azure/CloudHSM: Raise a ticket via portal (48-hour SLA for hard reboots).  
*RMA process: Zeroize HSM, package tamper-evident, ship to vendor. Restore from encrypted backups post-replacement.

Hardware Issue Remediation Table

Compiled from Thales Luna/payShield docs, Azure Dedicated HSM, and Keyfactor. Focus on hardware (e.g., failures, tampering, power/memory).

Issue Category  Symptoms/Error Codes               Possible Causes Step-by-Step Remediation                                                                                               Vendor Notes/Source
1. Unresponsive HSM (Power/Firmware Failure)       HSM halts; hsmstate shows "HALTED due to failure"; ALM0015 (PCIe link failure); OOS Code 30 (critical event).                          Firmware bug, low battery, power anomaly, or FM crash   1. Cycle power (unplug/replug AC; wait 30s)\n2. Run hsmreset\n3. Check hsm information show for battery low → hsm time sync\n4. Login as SO → hsm fm recover -erase fm (preserves keys)\n5. Patch firmware via Thales portal (KB0019789)\n6. Verify: hsmstate = "NORMAL"\n7. RMA if persistent Thales Luna 7 Admin Guide; Azure Dedicated HSM
2. Tamper Detection/Zeroization                    "Waiting for tamper cause to be removed"; ALM2029 (clock drift >3s/24h); Failed logins (3x SO = zeroize); Partition locked             Physical tamper, external detector misconfig, failed auth threshold (Policy 15: 10x CO logins)  1. Inspect hardware: reseat PCIe, check tamper pins\n2. Clear tamper: hsm tamper clear (if Policy 48 enabled)\n3. SO zeroize → wait 10 min lockout\n4. Unlock CO: role resetpw -name co\n5. Reboot: hsm restart\n6. Restore from encrypted backup Thales payShield/PCIe; Keyfactor Luna
3. Connectivity/NTLS Failure                       RC_SSL_ERROR, tlsv1 alert unknown ca; No TCP to port 1792; HA sync fails ("conflicting cloning domains").                              Cert expired, network block, ExpressRoute misconfig     1. Open port 1792 TCP\n2. Re-exchange NTLS certs: ntls cert create\n3. HA: hagroup recover (manual)\n4. Add new partition with matching domain → ha synchronize\n5. Test: telnet <HSM_IP> 1792\n6. Restart PEDserver with static IP, Azure Dedicated HSM; Thales Luna
4. Memory/Object Corruption                        CKR_DEVICE_MEMORY (0x00310000); ALM2024 (stored data integrity error); "Sporadic PS10K problems" (fan too fast)                        RAM shortage, flash corruption, overheating     1. Close sessions; delete orphan objects\n2. hsm restart or service restart cbs\n3. Check fan/heat → apply Thales fan-speed patch\n4. Zeroize SMFS: hsm fm recover -erase smfs (backup first!)\n5. Enable Policy 57 (NTP sync), Thales payShield Known Issues; Luna Admin Guide
5. PED/RPED Hardware Disconnect                    CKR_PED_UNPLUGGED (0x00300142); "USB bulk_msg rc=-110"; No menu on PED display  USB timeout, firmware mismatch, cable issue            1. Cycle PED power (unplug/replug USB/AC)\n2. pedserver -mode restart\n3. pedserver -mode config -set -pedwritedelay 50\n4. hsm ped connect -ip <IP> -port 1503\n5. Luna S790: Security page → Clean Up Slots\n6. Verify: pedserver -mode show = "Connected" Keyfactor Luna S790; Thales Luna Admin Guide
6. Adapter/PCIe Hardware Lockup                    System locks post-install; Adapter not found; Slow/stalled under load.   Driver conflict, loose seating, BIOS misconfiguration         1. Power down → remove adapter\n2. Uninstall ALL driver versions\n3. Reseat in PCIe slot\n4. Fresh install from Thales portal\n5. Reset BIOS config data\n6. Test: hsmstate post-reboot Thales ProtectServer PCIe Troubleshooting

EOF
