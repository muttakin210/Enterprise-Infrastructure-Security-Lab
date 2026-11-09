# Monitoring: LibreNMS (SNMPv3) and Wazuh

Both run on **monitor01** (192.168.20.10, Servers zone). Build script: [`../linux/monitor01-setup.sh`](../linux/monitor01-setup.sh).

## LibreNMS: network monitoring over SNMPv3

| Device | LibreNMS id | OS detected | Ports | SNMP |
|---|---|---|---|---|
| fw01 (192.168.20.1) | 6 | pfSense (FreeBSD 14) | 10 | v3 authPriv, SHA / AES, user `monitoruser` |
| srv01 (192.168.20.20) | 7 | Linux 5.15 | 2 | same |
| dmz-web01 (192.168.50.10) | 8 | Linux 5.15 | 2 | same |

* Only SNMPv3 **authPriv** works. Wrong passwords, authNoPriv, noAuthNoPriv, unknown users and v1/v2c
  communities are all refused (see [`a06-snmpv3.txt`](../cybersecurity/evidence/a06-snmpv3.txt)).
* UDP 161 is reachable only from monitor01: fw01 rules plus UFW on each host.
* Two faults found on the way are written up as incidents:
  [IR-004](../troubleshooting/incident-reports/IR-004-fw01-snmpv3-unknown-user.md) (fw01 lost its SNMPv3 user) and
  [IR-005](../troubleshooting/incident-reports/IR-005-snmp-authnopriv-accepted.md) (Ubuntu agents accepted authNoPriv).
* Screenshots: [`librenms-01-devices.png`](../screenshots/librenms-01-devices.png), one per device
  (`librenms-02-*.png`), and fw01's ports ([`librenms-03-fw01-ports.png`](../screenshots/librenms-03-fw01-ports.png)).
  The device list as text is in [`librenms-devices.txt`](../cybersecurity/evidence/librenms-devices.txt).
* LibreNMS web UI: `http://127.0.0.1:8030` from the host (VirtualBox NAT forward). The admin login lives in `.lab-local/` only.

## Wazuh: log collection, detection, active response

| Part | Setting |
|---|---|
| Manager | Wazuh 4.14 on monitor01. No indexer or dashboard: they need more RAM than the laptop has left, so alerts are read from `alerts.json` with `jq` |
| Agents | srv01 (001), dmz-web01 (002). client01 has none: Users → Servers allows only DNS, SSH and web to srv01 |
| Extra sources | Suricata `eve.json` (JSON), and fw01 syslog through rsyslog (`/var/log/remote/`) |
| Active response | `firewall-drop` on rules 5712 (SSH brute force) and 5763, for 600 s |
| Config | [`../linux/wazuh-manager-config.py`](../linux/wazuh-manager-config.py) |

What it caught and how it reacted: [`../cybersecurity/wazuh-analysis.md`](../cybersecurity/wazuh-analysis.md) and
[IR-003](../troubleshooting/incident-reports/IR-003-failed-ssh-logins.md). kali01 was blocked on srv01 within
seconds of the brute-force alert.

## Health check

`bash tests/run-all.sh` checks every service above, SNMPv3 to all three devices, the Wazuh agents and the
zone policy from every host. Last result: [`../tests/last-run.txt`](../tests/last-run.txt).
