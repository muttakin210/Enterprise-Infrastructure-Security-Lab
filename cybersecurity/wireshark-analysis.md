# Wireshark traffic analysis (assignment 7)

**Capture:** kali01 `eth0` (Security zone), tcpdump with a full snap length.
**Script:** [`scripts/wireshark-capture.sh`](scripts/wireshark-capture.sh)
**Analysis:** tshark, the Wireshark engine on the command line, so every step can be repeated.
Open [`evidence/a07-lab-traffic.pcap`](evidence/a07-lab-traffic.pcap) in Wireshark to follow along in the GUI.
**Output:** [`evidence/a07-wireshark-analysis.txt`](evidence/a07-wireshark-analysis.txt)

The capture covers ordinary lab use: DNS lookups, two web requests, a request to a closed port, an attempt
on a port the firewall blocks, an SSH connection and a ping to the gateway. That is 55 packets.

## Protocol hierarchy (Statistics → Protocol Hierarchy)

| Protocol | Frames | Readable? |
|---|---|---|
| DNS (UDP 53) | 6 | yes, names and answers are clear text |
| HTTP (TCP 80) | 4 | yes, method, URI, user agent and server header |
| SSH (TCP 22) | 11 | only the version banners; the rest is encrypted after key exchange |
| ICMP | 4 | yes |
| other TCP (handshakes, RST, retransmissions) | 30 | headers only |

## Findings, filter by filter

| Wireshark display filter | What it shows | Meaning |
|---|---|---|
| `dns` | `srv01.corp.lab → 192.168.20.20`, `www.corp.lab → 192.168.50.10` (rcode 0), `nonexistent.corp.lab` (rcode **3 = NXDOMAIN**) | the internal resolver works; NXDOMAIN is visible on the wire, which is useful for spotting tunnelling (IR-002) |
| `http.request` / `http.response` | `GET /` with `curl/8.17.0` to both servers; `200`, `Server: nginx` with **no version** | clear-text web traffic: anything sent over HTTP could be read by anyone on the path, hence the HTTPS finding N-1 |
| `tcp.flags.reset==1` | srv01:443 → kali01 RST | 443 is allowed through, but **nothing is listening** (a "closed" port) |
| `tcp.flags.syn==1 && tcp.flags.ack==0` to 192.168.20.10:8000 | 2 SYNs, **no reply at all** | fw01 dropped them silently ("filtered"); a drop gives no RST, so a scanner learns nothing |
| `ssh` | `SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.18` (server), `OpenSSH_10.2p1 Debian` (client) | the banners are the only clear text; the login name and the "Permission denied" are inside the encrypted channel |
| `icmp` | echo request and reply with 192.168.40.1 | the Security zone may ping its own gateway only |

## The Conversations view and the firewall

`Statistics → Conversations → IPv4`:

| Peer | Packets A→B / B→A | Explanation |
|---|---|---|
| 192.168.20.20 srv01 | 21 / 18 | two-way: an allowed test target |
| 192.168.50.10 dmz-web01 | 6 / 4 | two-way: HTTP allowed |
| 192.168.40.1 fw01 | 2 / 2 | ping to its own gateway |
| 192.168.20.10 monitor01 | **2 / 0** | one-way: blocked by fw01 (Security → PRIVATE_NETS) |

A one-way conversation is how to spot firewall drops in any capture.

## Earlier capture: what an *active block* looks like

The first capture ran while Wazuh's active response was blocking kali01 on srv01 (see IR-003). Every
packet to 192.168.20.20 was one-way (27 packets out, 0 back), and DNS questions were retransmitted three
times without an answer. The capture can tell a firewall drop apart from a service that is down: with a
drop there is no RST and no ICMP, only silence.

## Analyst checklist used

1. Statistics → Protocol Hierarchy: what is in the capture.
2. Statistics → Conversations: who talks to whom, and which flows are one-way.
3. Filters `dns`, `http`, `tcp.flags.reset==1`, `tcp.analysis.retransmission`: names, clear-text data, refusals, losses.
4. Follow → TCP Stream on HTTP: what is readable; on SSH: confirm only the banner is.
