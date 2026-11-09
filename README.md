# Enterprise Infrastructure & Cybersecurity Lab

A segmented enterprise network that is built, monitored, attacked (with authorisation, inside the lab only)
and defended, on one 16 GB Windows 11 laptop. It covers the work of a Network Engineer, Linux System
Administrator, Network Security Engineer and Junior Security Analyst.

> Status: **complete.** All 12 assignments and 4 scenarios are done, each with raw evidence
> ([index](docs/assignments.md)). Health check `tests/run-all.sh`: **36/36 PASS**
> ([last run](tests/last-run.txt)). Connectivity matrix: **51/51** as policy says.

## Results at a glance

| Area | What was built and proven | Where |
|---|---|---|
| Segmentation | 5 zones, default-deny pfSense policy; every zone-to-zone pair tested from every host | [firewall/](firewall/README.md), [connectivity-matrix.csv](cybersecurity/evidence/connectivity-matrix.csv) |
| Cisco | CORE-SW1 VLANs, trunk, port security, DHCP snooping; FW01 router-on-a-stick with zone ACLs, in Packet Tracer | [cisco/](cisco/README.md) |
| Monitoring | LibreNMS polls fw01, srv01, dmz-web01 over SNMPv3 authPriv only | [monitoring/](monitoring/README.md) |
| Hardening | SSH key-only, `AllowUsers`, modern ciphers; UFW on every server | [linux/ssh-hardening.sh](linux/ssh-hardening.sh) |
| Detection | Suricata on Servers and DMZ (ET Open + 8 local rules); Wazuh with active response | [suricata-alerts.md](cybersecurity/suricata-alerts.md), [wazuh-analysis.md](cybersecurity/wazuh-analysis.md) |
| Analysis | Nmap assessment, Wireshark capture analysis, DNS investigation | [cybersecurity/](cybersecurity/) |
| Incident response | Workflow and 7 incident reports (4 scenarios, 3 real faults found while building) | [troubleshooting/](troubleshooting/) |

## Architecture

```
                      Internet (VirtualBox NAT)
                               |
                     fw01  pfSense CE 2.7  (routing, firewall, NAT, DHCP, syslog)
          +-----------+--------+---------+-----------+
       VLAN 10     VLAN 20   VLAN 30   VLAN 40     VLAN 50
     Management    Servers    Users    Security      DMZ
    192.168.10/24  .20/24     .30/24    .40/24      .50/24
     CORE-SW1     monitor01  client01   kali01     dmz-web01
       (SVI)       srv01
```

| Zone | VLAN | Network | Purpose | Hosts |
|---|---|---|---|---|
| Management | 10 | 192.168.10.0/24 | Network device management | CORE-SW1 SVI .2 |
| Servers | 20 | 192.168.20.0/24 | Linux server infrastructure | monitor01 .10 (LibreNMS, Suricata, Wazuh), srv01 .20 |
| Users | 30 | 192.168.30.0/24 | Employee/client devices | client01 (DHCP .100–.199) |
| Security | 40 | 192.168.40.0/24 | Security testing and monitoring | kali01 .10 |
| DMZ | 50 | 192.168.50.0/24 | Public-facing test services | dmz-web01 .10 |

In VirtualBox each zone is its own internal network (`pel-mgmt`, `pel-servers`, `pel-users`, `pel-security`,
`pel-dmz`), equivalent to an access VLAN behind the firewall. The Cisco side (CORE-SW1 with 802.1Q trunk,
VLANs, ACLs and SNMPv3) is built in Cisco Packet Tracer.

## Firewall policy (default deny, least privilege)

| From \ To | Management | Servers | Users | Security | DMZ | Internet |
|---|---|---|---|---|---|---|
| Management | – | allow | allow | allow | allow | allow |
| Servers | SNMP/syslog to devices only | – | deny | deny | deny | allow (updates) |
| Users | **deny** | web, DNS, SSH to srv01 only | – | deny | web only | allow |
| Security | deny | authorised tests (srv01, dmz-web01) | deny | – | authorised tests | allow |
| DMZ | **deny** | deny | deny | deny | – | updates only |

## Repository layout

```
topology/        addressing plan and network diagram
cisco/           CORE-SW1 / edge configs (VLAN, trunk, ACL, SNMPv3) and the Packet Tracer file
firewall/        pfSense configuration, rules and Suricata setup
linux/           server build, SSH hardening, SNMPv3 agent
monitoring/      LibreNMS and Wazuh
cybersecurity/   Nmap, Wireshark, DNS, Suricata and Wazuh analysis
troubleshooting/ workflow and incident reports
lab/             scripts that build the VMs and take the GUI screenshots
tests/           run-all.sh health and policy check, and its last output
screenshots/     pfSense, LibreNMS and Packet Tracer evidence
docs/            assignment index, build log, and the complete guide PDF (PEL-Lab-Complete-Guide.pdf)
```

## How to run the checks

```bash
bash tests/run-all.sh
```

It needs the VMs running and the access helpers in the git-ignored `.lab-local/`. A powered-off VM is
reported as SKIP. To rebuild the Packet Tracer pastes from the configs: `python cisco/packet-tracer/make_pt_configs.py`.

## Limitations (honest list)

* **Wazuh has no indexer or dashboard.** OpenSearch needs more RAM than the 16 GB laptop has left with the
  other VMs running. The manager, agents, rules and active response all work; alerts are read with `jq`.
* **The Cisco part is in Packet Tracer**, not on real IOS. Packet Tracer has no SNMPv3 agent, so SNMPv3 is
  shown on pfSense and Ubuntu instead. FW01 is an ISR 2911 standing in for pfSense, with the same policy as ACLs.
* **monitor01 is a linked clone** of an earlier lab's LibreNMS server, re-addressed and cleaned (old devices
  and logs removed), to save disk space and build time.
* **Servers run Ubuntu 22.04**, kali01 runs with 1 GB RAM (multi-user target, no desktop), and client01 has
  no Wazuh agent, because Users may not reach monitor01 under the policy.
* **NULL and XMAS scans raise no Suricata alert**: pf's scrub drops those packets before they reach a host
  (documented in [suricata-alerts.md](cybersecurity/suricata-alerts.md)).

## Security of this repository

No passwords, private keys, SNMP secrets or licensed images are committed. Lab credentials are generated
at build time into `.lab-local/` (git-ignored) and on each VM in `/root/lab-secrets.env` (mode 600).
All scanning and attack simulation targets only hosts inside this isolated lab.
