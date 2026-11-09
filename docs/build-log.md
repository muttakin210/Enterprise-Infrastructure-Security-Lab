# Build log

What was done, in order, with the problems hit and how they were solved.

## Host

| Item | Value |
|---|---|
| Laptop | Windows 11 Pro, Intel Core i5-1235U (12 threads), 16 GB RAM |
| Free RAM with normal apps open | about 3 GB, so VMs run a few at a time (as the project plan advises) |
| Hypervisor | VirtualBox 7.2.4 |
| Lab storage | `E:\VMs\PEL` (dynamically allocated disks) |

## Steps

| # | Step | Result |
|---|---|---|
| 1 | Repository, zones, firewall policy, addressing plan | ✅ |
| 2 | Base Ubuntu 22.04 VM, unattended install from the local ISO (`lab/vbox/new-ubuntu-base.ps1`) | ✅ |
| 3 | kali01 from the official Kali 2025.4 VirtualBox image (`lab/vbox/new-kali.ps1`) | ✅ |
| 4 | monitor01 as a linked clone of the earlier ENL server, which already has LibreNMS (`lab/vbox/new-monitor01.ps1`) | ✅ re-addressed, cleaned |
| 5 | fw01 pfSense CE 2.7.2: interfaces, aliases, rules, NAT, DHCP, SNMPv3, remote syslog (`firewall/`) | ✅ |
| 6 | srv01, dmz-web01, client01 cloned from the base (`linux/server-setup.sh`) | ✅ |
| 7 | Suricata, Wazuh manager and agents, LibreNMS devices on monitor01 (`linux/monitor01-setup.sh`) | ✅ |
| 8 | Assignments 1–12 and scenarios 1–4 with evidence (`cybersecurity/`, `troubleshooting/`) | ✅ |
| 9 | Cisco CORE-SW1 and FW01 in Packet Tracer 9.0 (`cisco/`) | ✅ |
| 10 | Health check `tests/run-all.sh` | ✅ 36/36 |

## Problems and fixes

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | `VBoxManage unattended install` failed: unknown option `--install-additions=false` | Not a valid flag in VirtualBox 7.2 (additions are off unless `--install-additions` is given) | Removed the flag and re-ran the unattended step. |
| 2 | pfSense ISO download at ~30 KB/s (5+ hours) | Netgate's primary server was slow from here and its other mirrors no longer answer; the internet link itself was fine (4–6 MB/s to Ubuntu/Cloudflare) | Used the DSU community mirror with 8 parallel range requests, then verified the file against Netgate's own SHA-256. |
| 3 | monitor01 could not resolve names (apt and `add-apt-repository` failed) | the clone still pointed systemd-resolved at the old lab's BIND on 127.0.0.1 | `monitor01-setup.sh` rewrites the DNS lines in `resolved.conf` and removes the old lab's bridge. |
| 4 | `suricata -T -q` hung | `-q` selects an NFQUEUE, it is not "quiet" | Plain `suricata -T`, output discarded. |
| 5 | Suricata restarted in a loop | the af-packet edit was not idempotent (duplicate interface with the same cluster-id), and 10 worker threads missed the start deadline | [IR-006](../troubleshooting/incident-reports/IR-006-suricata-crash-loop.md); `linux/suricata-config.py` rewrites the block, 1 thread per NIC. |
| 6 | wazuh-manager timed out on start | first start builds its databases slower than systemd's 90 s limit on this laptop | systemd drop-in `TimeoutStartSec=600`; vulnerability detection off (it needs the indexer). |
| 7 | srv01 renamed itself back to the base name after a reboot | cloud-init in the base image | `preserve_hostname: true` in `server-setup.sh`. |
| 8 | dmz-web01 had no DNS | the DMZ may not reach internal zones, including srv01's DNS | the DMZ uses a public resolver (1.1.1.1); policy unchanged. |
| 9 | fw01 SNMPv3 answered "Unknown user name" | the user was not in the persistent snmpd config | [IR-004](../troubleshooting/incident-reports/IR-004-fw01-snmpv3-unknown-user.md). |
| 10 | Ubuntu agents answered authNoPriv | `net-snmp-create-v3-user` adds a bare `rouser` line | [IR-005](../troubleshooting/incident-reports/IR-005-snmp-authnopriv-accepted.md). |
| 11 | Hydra stopped at once | password authentication is off on the targets (by design) | brute force simulated with invalid-user logins, which still triggers Wazuh 5710 → 5712 → active response. |
| 12 | fw01 appeared as `_gateway` and every syslog line twice | no name for 192.168.20.1 on monitor01; "everything" plus the "filter" category both enabled | hosts entry for fw01; only "everything" is sent. |
| 13 | Packet Tracer trunk down after the configs were pasted | the router–switch cable was a cross-over | straight-through cable; details in [cisco/README.md](../cisco/README.md). |
| 14 | Text typed into the Packet Tracer CLI was lost | the automation types through the clipboard, which PT's IOS console ignores | configs pasted with PT's own **Paste** button. |
