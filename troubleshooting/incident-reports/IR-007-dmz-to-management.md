# IR-007: DMZ host attempts to reach the Management zone (scenario 4, segmentation)

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:45 (UTC+6) |
| Severity | Critical if real: lateral movement from a public-facing host toward the administrators' network |
| Source | dmz-web01 192.168.50.10 |
| Targets | 192.168.10.1:443 (fw01 GUI), 192.168.10.2:22 (CORE-SW1), 192.168.10.50:3389, ICMP to .2 |
| Detected by | Suricata sid 9000030 on the DMZ sensor (enp0s9) |
| Blocked by | fw01 rule "DMZ net → MGMT net: block, log" (filterlog on em5) |
| Evidence | [`scenario-dmz-to-mgmt.txt`](../../cybersecurity/evidence/scenario-dmz-to-mgmt.txt), [`connectivity-matrix.csv`](../../cybersecurity/evidence/connectivity-matrix.csv) |

## What happened

The test simulated a compromised web server probing Management services. Every attempt timed out (a
silent drop, so it learned nothing). Three independent records exist:

1. **Suricata (DMZ sensor, before the firewall):** 4 × sid 9000030 "DMZ host contacting Management zone".
2. **fw01 filter log, via syslog on monitor01:**
   `fw01.corp.lab filterlog: …,em5,match,block,in,4,…,tcp,…,192.168.50.10,192.168.10.2,…,23,…,S`
3. **The connectivity matrix:** every dmz-web01 → internal test is `deny`, except Wazuh 1514 to monitor01.

## Segmentation matrix (summary of 28/28 PASS)

| From \ To | fw01 | monitor01 | srv01 | dmz-web01 | kali01 | Internet |
|---|---|---|---|---|---|---|
| srv01 (Servers) | ✗ | Wazuh only | | ✗ | ✗ | ✓ |
| monitor01 (Servers) | ping, SNMP | | DNS, HTTP, SNMP | SNMP | ✗ | ✓ |
| dmz-web01 (DMZ) | ✗ | Wazuh only | ✗ | | ✗ | ✓ |
| kali01 (Security) | ✗ | ✗ | any (test target) | HTTP (UFW: no SSH) | | ✓ |

## Recommendations

- Keep the DMZ → Management block *above* the generic DMZ → PRIVATE_NETS block. It is redundant on
  purpose: if someone loosens the generic rule, Management stays closed.
- Any 9000030 alert outside a test window is P1: isolate dmz-web01 (move it to the parking network) and
  image it for forensics.
