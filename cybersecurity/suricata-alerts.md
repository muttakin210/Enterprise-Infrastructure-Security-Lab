# Suricata IDS (assignment 9)

**Sensor:** monitor01, Suricata 8.0.8 (OISF PPA), ET Open rules (about 53,000) plus the lab rules in
[`suricata/local.rules`](suricata/local.rules). **Config:** [`../linux/suricata-config.py`](../linux/suricata-config.py)
**Evidence:** [`evidence/a09-suricata-alerts.txt`](evidence/a09-suricata-alerts.txt),
[`evidence/attack-simulation.log`](evidence/attack-simulation.log)

## Sensor placement

monitor01 has two capture NICs. VirtualBox "allow-all" promiscuous mode works like a SPAN port: the sensor
sees every frame on that internal network.

| NIC | Segment | Sees |
|---|---|---|
| enp0s8 | Servers zone (pel-servers), also monitor01's own address | everything to and from srv01 and monitor01, after fw01 |
| enp0s9 | DMZ (pel-dmz), **no IP address** | everything to and from dmz-web01, before fw01 filters it. A stealth sensor with no IP cannot be attacked |

## Lab rules

| SID | Detects | Logic |
|---|---|---|
| 9000001 | TCP port scan | 40 SYNs from one source in 60 s (`threshold type both`: one alert per source per minute) |
| 9000002/3 | NULL and XMAS scans | TCP flags = none / FIN+PSH+URG |
| 9000010 | DNS tunnelling pattern | a query label of 40 or more alphanumeric characters |
| 9000011 | DNS query burst | 100 queries from one source in 10 s |
| 9000020 | SSH brute force | 10 new SSH connections from one source in 60 s |
| 9000030 | DMZ → Management | any packet from 192.168.50.0/24 to 192.168.10.0/24 |
| 9000040 | Web scanner | the HTTP user agent contains Nikto, Nmap Scripting Engine, gobuster or dirbuster |

## Test run (attack-simulation.sh from kali01, then the DMZ test from dmz-web01)

| Activity | Expected | Alerts seen | Result |
|---|---|---|---|
| Full TCP port scans of srv01 and dmz-web01 | 9000001 | 1,781 (enp0s8) + 1,660 (enp0s9), before tuning | detected, too noisy, tuned (see below) |
| curl with Nikto / Nmap NSE / gobuster user agents | 9000040 | 32 per web server, plus 30 per server from **ET SCAN Possible Nmap User-Agent (2024364)** | detected by the lab rule *and* ET Open |
| 5 queries with 50-character random hex labels | 9000010 | 5 | detected (one per query) |
| 150 parallel DNS queries | 9000011 | 1 | detected |
| SSH connection flood (Hydra and invalid-user logins) | 9000020 | 1 | detected |
| dmz-web01 → 192.168.10.1:443, .2:22, .50:3389, ping .2 | 9000030 | 4 | detected on the DMZ sensor *before* fw01 dropped it |
| NULL and XMAS scans of srv01 | 9000002/3 | **0** | not seen: see below |

### Why the NULL and XMAS scans raised no alert

pfSense normalises traffic (`scrub`). Packets with impossible flag combinations are dropped on the
firewall's ingress interface, so they never reach the Servers segment the sensor watches. The firewall
neutralised the probe, and the IDS confirms that nothing illegal got through. To still *see* such probes,
put a sensor in front of the firewall (on the Security zone segment) or read pf's own logs.

### Tuning: alert flood from the port-scan rule

The first version used `threshold: type threshold, count 40, seconds 10`, which raises one alert for every
40 SYNs. A full 65,535-port scan produced about 1,700 alerts per target, and Wazuh turned each into rule
86601. Changing it to `type both, count 40, seconds 60` gives *one* alert per scanning source per minute,
with the same detection and almost no noise (rev 2). The rules were reloaded live with `kill -USR2`, with no
restart.

## Suricata → Wazuh

Wazuh reads `/var/log/suricata/eve.json` (a `localfile` in JSON format), and every Suricata alert becomes
Wazuh rule **86601** ("Suricata: Alert - <signature>"), so IDS events sit next to host logs in the SIEM. See
[wazuh-analysis.md](wazuh-analysis.md).

## Problems found while building the sensor

- **Crash loop every 3 minutes:** the af-packet section was being appended again on each setup run, giving
  four `enp0s9` entries with the same cluster id, so the fanout failed. The ten worker threads also missed
  Suricata's fixed 70-second start budget while loading 53k rules on a 2 GB VM. Fixed with an idempotent
  rewrite and one worker per NIC (see [IR-006](../troubleshooting/incident-reports/IR-006-suricata-crash-loop.md)).
- `suricata -T -q` is *not* "quiet". `-q` selects an NFQUEUE id, so the config test just printed the usage text.
