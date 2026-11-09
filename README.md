# Enterprise Infrastructure & Cybersecurity Lab

A segmented enterprise network that is built, monitored, attacked (with authorisation, inside the lab only)
and defended, on one 16 GB Windows 11 laptop. It covers the work of a Network Engineer, Linux System
Administrator, Network Security Engineer and Junior Security Analyst.

> Status: **in progress.** Each section links to its evidence once that part is built and verified.

## Architecture

```
                      Internet (VirtualBox NAT)
                               |
                     fw01  pfSense CE 2.7  (routing, firewall, NAT, Suricata)
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
lab/             scripts that build the VMs and run the assignments
screenshots/     evidence
docs/            build log, limitations
```

## Security of this repository

No passwords, private keys, SNMP secrets or licensed images are committed. Lab credentials are generated
at build time into `.lab-local/` (git-ignored) and on each VM in `/root/lab-secrets.env` (mode 600).
All scanning and attack simulation targets only hosts inside this isolated lab.
