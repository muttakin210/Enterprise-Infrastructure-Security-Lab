# Nmap assessment (assignments 1–3)

**Scanner:** kali01, 192.168.40.10, in the Security zone. **Script:** [`scripts/nmap-assessment.sh`](scripts/nmap-assessment.sh)
**Scope:** the five lab /24 networks only. **Raw output:** [`evidence/a01-discovery.txt`](evidence/a01-discovery.txt),
[`evidence/a02-portscan.txt`](evidence/a02-portscan.txt), [`evidence/a03-services.txt`](evidence/a03-services.txt)

The firewall lets the Security zone reach srv01 and dmz-web01 and nothing else inside. This assessment
therefore tests two things: what the attacker can learn about the authorised targets, and whether the zones the
attacker is *not* allowed to reach really stay invisible.

## Assignment 1: host discovery

`nmap -sn -PE -PS22,80,443 -n <zone>/24` (ICMP echo plus TCP SYN probes; ARP on the local segment)

| Zone | Hosts found | What it means |
|---|---|---|
| Security 192.168.40.0/24 | .1 (fw01), .10 (kali01 itself) | its own gateway answers ICMP, which the policy allows |
| Servers 192.168.20.0/24 | **.20 only** (srv01) | monitor01 (.10) and the gateway (.1) are invisible: the Security→Servers rule only opens srv01 |
| DMZ 192.168.50.0/24 | .10 (dmz-web01) | authorised target |
| Users 192.168.30.0/24 | **none** | fully blocked; every probe timed out (206 s) |
| Management 192.168.10.0/24 | **none** | fully blocked, including the firewall's own Management address |

The two "0 hosts up" results are the important ones. A scanner in the Security zone cannot even tell that
the Users and Management zones exist.

## Assignment 2: port scan

`nmap -sS -p- --min-rate 800` (all 65,535 TCP ports) and `nmap -sU --top-ports 25`

| Host | Open | Closed | Filtered |
|---|---|---|---|
| srv01 192.168.20.20 | 22/ssh, 53/domain, 80/http | 443 | 65,531 |
| dmz-web01 192.168.50.10 | 80/http | 443 | 65,533 |

- **"Filtered" (no reply) is the UFW default deny on each host.** "Closed" (a TCP RST) means a port that is
  allowed through but has nothing listening on it.
- **dmz-web01's SSH is not reachable from the Security zone.** Its UFW only accepts SSH from the Management
  zone and the firewall jump host.
- **UDP results are mostly `open|filtered`.** That is normal for a default-drop host: no ICMP
  port-unreachable comes back, so nmap cannot tell "open" from "dropped".

## Assignment 3: service and version enumeration

`nmap -sV -sC`, plus the `ssh-auth-methods`, `ssh2-enum-algos`, `dns-nsid` and `dns-recursion` scripts.

| Service | Result | Assessment |
|---|---|---|
| SSH srv01 | OpenSSH 8.9p1 Ubuntu; auth methods: **publickey only**; KEX curve25519 only; ciphers chacha20/AES-GCM; MACs ETM only; legal banner | hardened (assignment 4). Password guessing is impossible: Hydra stops with "does not support password authentication" |
| DNS srv01 | BIND, `version.bind` = **"not disclosed"** | version hidden, so a scanner cannot match it to CVEs |
| DNS recursion | enabled for the lab networks | intended: srv01 is the internal resolver. Recursion is limited by the `lab_nets` ACL, so it is not an open resolver |
| HTTP srv01, dmz-web01 | nginx, **no version** (`server_tokens off`) | version hidden |

## Findings

| # | Finding | Risk | Action |
|---|---|---|---|
| N-1 | TCP 443 allowed by fw01 and UFW to srv01 and dmz-web01, but no TLS service exists (port "closed") | Low: an unnecessary opening, against least privilege | Remove 443 from `WEB_PORTS` and UFW until HTTPS is deployed, or deploy HTTPS |
| N-2 | The Security zone may reach *any* port on srv01 and dmz-web01 | Accepted: it is the authorised test range | Limit with time-based rules or a separate rule set outside test windows |
| N-3 | The OpenSSH version is visible in the banner | Informational: it cannot be hidden without patching sshd | Keep patched; nothing else is visible |
