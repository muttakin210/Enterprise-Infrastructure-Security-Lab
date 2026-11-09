# fw01: pfSense CE 2.7.2

The firewall between all five zones and the internet. It routes between the zones, enforces the zone policy,
runs outbound NAT and DHCP for the Users zone, and sends its logs to monitor01.

## Build

| Step | How |
|---|---|
| VM | `lab/vbox/new-fw01.ps1`: 1 GB RAM, 8 GB disk, six e1000 NICs (WAN on VirtualBox NAT, one internal network per zone) |
| Install | pfSense CE 2.7.2 ISO (SHA-256 checked against Netgate's), Auto (UFS), driven over the headless console with `lab/vbox/vmcon.sh` |
| Bootstrap | console: enable sshd (menu 14), install the lab SSH key for root |
| Configure | `pfsense-configure.php` runs on the firewall and writes the whole policy through pfSense's own config API (`write_config`), so it can be re-run and the GUI shows everything |
| SNMPv3 | `pfsense-snmpv3.sh`: net-snmp agent, v3 authPriv only, bound to 192.168.20.1 (pfSense's own bsnmpd only supports v1/v2c) |

## Interfaces

| pfSense | NIC | Zone | Address |
|---|---|---|---|
| WAN | em0 | VirtualBox NAT | DHCP 10.0.2.15/24 |
| LAN (renamed MGMT) | em1 | Management | 192.168.10.1/24 |
| OPT1 SERVERS | em2 | Servers | 192.168.20.1/24 |
| OPT2 USERS | em3 | Users | 192.168.30.1/24, DHCP .100–.199, DNS 192.168.20.20 |
| OPT3 SECURITY | em4 | Security | 192.168.40.1/24 |
| OPT4 DMZ | em5 | DMZ | 192.168.50.1/24 |

## Rules

Stateful, applied where traffic enters the firewall, first match wins, and anything not passed is blocked
(**default deny**). Each zone may only open the sessions it needs (**least privilege**). "Block … PRIVATE_NETS"
rules log, so policy violations appear in the firewall log, monitor01 syslog and Wazuh.

| Interface | Action | Source → Destination | Port | Why |
|---|---|---|---|---|
| WAN | pass | 10.0.2.2 (host) → WAN address | tcp 22, 443 | lab-only out-of-band management through VirtualBox NAT |
| MGMT | pass | MGMT net → any | any | administrators manage every zone |
| SERVERS | pass | monitor01 → MGMT net | udp 161 | SNMPv3 polling of network devices |
| SERVERS | pass | monitor01 → dmz-web01 | udp 161 | SNMPv3 polling of the DMZ server |
| SERVERS | pass | monitor01 → fw01 (SERVERS address) | udp 161 | SNMPv3 polling of the firewall |
| SERVERS | pass | monitor01 → any | icmp | reachability checks |
| SERVERS | pass | monitor01 → MGMT net | tcp 22 | device management |
| SERVERS | **block, log** | SERVERS net → PRIVATE_NETS | any | servers never start sessions into other zones |
| SERVERS | pass | SERVERS net → any | any | updates (internet) |
| USERS | pass | USERS net → srv01 | tcp/udp 53 | DNS |
| USERS | pass | USERS net → srv01 | tcp 22, 80, 443 | SSH and intranet |
| USERS | pass | USERS net → dmz-web01 | tcp 80, 443 | public web |
| USERS | pass | USERS net → USERS gateway | icmp | troubleshooting |
| USERS | **block, log** | USERS net → PRIVATE_NETS | any | no Management or other internal access |
| USERS | pass | USERS net → any | any | internet |
| SECURITY | pass | SECURITY net → srv01, dmz-web01 | any | **authorised** test targets only |
| SECURITY | pass | SECURITY net → SECURITY gateway | icmp | troubleshooting |
| SECURITY | **block, log** | SECURITY net → PRIVATE_NETS | any | nothing else internal is in scope |
| SECURITY | pass | SECURITY net → any | any | tool updates |
| DMZ | pass | dmz-web01 → monitor01 | tcp 1514, 1515 | Wazuh agent events |
| DMZ | **block, log** | DMZ net → MGMT net | any | the DMZ must never reach Management |
| DMZ | **block, log** | DMZ net → PRIVATE_NETS | any | a compromised DMZ host cannot pivot inside |
| DMZ | pass | DMZ net → any | any | updates |

Outbound NAT is automatic: every zone is translated to the WAN address.

## Logging

Remote syslog goes to monitor01 (192.168.20.10:514, sent from the SERVERS address) with firewall default
block/pass logging enabled. rsyslog writes it to `/var/log/remote/`, and Wazuh reads that file.

## Design notes

- **WAN private-network blocking is off.** VirtualBox NAT puts the WAN on 10.0.2.0/24, which is itself RFC1918.
  On a real internet uplink, "Block private networks" and "Block bogons" stay on.
- **Key-only SSH** (`sshdkeyonly`), and sshguard whitelists only the host NAT gateway and the Management zone.
- The **Cisco version** of the same policy (for Packet Tracer, where pfSense cannot run) is in `../cisco/fw01-edge.cfg`.
  There it is written as stateless extended ACLs using `established` for return traffic.
