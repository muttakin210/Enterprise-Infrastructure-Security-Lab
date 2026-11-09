# Assignments and scenarios: where each one is done and proven

| # | Assignment | Script / config | Write-up | Raw evidence |
|---|---|---|---|---|
| 1 | Nmap host discovery | `cybersecurity/scripts/nmap-assessment.sh` | [nmap-assessment.md](../cybersecurity/nmap-assessment.md) | `evidence/a01-discovery.txt` |
| 2 | Port scanning | same | same | `evidence/a02-portscan.txt` |
| 3 | Service enumeration | same | same | `evidence/a03-services.txt` |
| 4 | SSH hardening | `linux/ssh-hardening.sh` | [nmap-assessment.md](../cybersecurity/nmap-assessment.md) (A3b), [IR-003](../troubleshooting/incident-reports/IR-003-failed-ssh-logins.md) | `evidence/a04-ssh-before.txt`, `a04-ssh-after.txt` |
| 5 | Firewall rule testing | `cybersecurity/scripts/connectivity-matrix.sh`, `firewall/pfsense-configure.php` | [firewall/README.md](../firewall/README.md), [IR-007](../troubleshooting/incident-reports/IR-007-dmz-to-management.md) | `evidence/connectivity-matrix.csv` |
| 6 | SNMPv3 security | `cybersecurity/scripts/snmpv3-tests.sh`, `firewall/pfsense-snmpv3.sh` | [IR-004](../troubleshooting/incident-reports/IR-004-fw01-snmpv3-unknown-user.md), [IR-005](../troubleshooting/incident-reports/IR-005-snmp-authnopriv-accepted.md) | `evidence/a06-snmpv3*.txt`, `evidence/librenms-devices.txt` |
| 7 | Wireshark traffic analysis | `cybersecurity/scripts/wireshark-capture.sh` | [wireshark-analysis.md](../cybersecurity/wireshark-analysis.md) | `evidence/a07-lab-traffic.pcap`, `a07-wireshark-analysis.txt` |
| 8 | DNS investigation | `linux/dns/` (BIND, querylog) | [IR-002](../troubleshooting/incident-reports/IR-002-suspicious-dns.md) | `evidence/a08-dns-investigation.txt` |
| 9 | Suricata IDS testing | `cybersecurity/suricata/local.rules`, `linux/suricata-config.py`, `scripts/attack-simulation.sh` | [suricata-alerts.md](../cybersecurity/suricata-alerts.md) | `evidence/a09-suricata-alerts.txt` |
| 10 | Wazuh log analysis | `linux/wazuh-manager-config.py` | [wazuh-analysis.md](../cybersecurity/wazuh-analysis.md) | `evidence/a10-*.txt` |
| 11 | VLAN isolation | `cisco/core-sw1.cfg`, `cisco/fw01-edge.cfg` (Packet Tracer), VirtualBox internal networks | [cisco/README.md](../cisco/README.md) | `evidence/connectivity-matrix.csv`, Packet Tracer screenshots |
| 12 | Incident response | the workflow and 7 reports | [troubleshooting/](../troubleshooting/) | linked from each report |

| Scenario | Report |
|---|---|
| 1 Unauthorised port discovery | [IR-001](../troubleshooting/incident-reports/IR-001-unauthorized-port-discovery.md) |
| 2 Suspicious DNS activity | [IR-002](../troubleshooting/incident-reports/IR-002-suspicious-dns.md) |
| 3 Failed SSH login investigation | [IR-003](../troubleshooting/incident-reports/IR-003-failed-ssh-logins.md) |
| 4 Network segmentation and connectivity matrix | [IR-007](../troubleshooting/incident-reports/IR-007-dmz-to-management.md), `evidence/connectivity-matrix.csv` |

Problems found and fixed while building: [IR-004](../troubleshooting/incident-reports/IR-004-fw01-snmpv3-unknown-user.md),
[IR-005](../troubleshooting/incident-reports/IR-005-snmp-authnopriv-accepted.md),
[IR-006](../troubleshooting/incident-reports/IR-006-suricata-crash-loop.md), and the build log [build-log.md](build-log.md).

All evidence paths are relative to `cybersecurity/`.
