# Wazuh SIEM (assignment 10)

**Manager:** monitor01, Wazuh 4.14 manager. There is no indexer or dashboard: 16 GB of host RAM cannot run
OpenSearch next to the other VMs, so alerts are read from `/var/ossec/logs/alerts/alerts.json` with `jq`.
**Agents:** srv01 (001), dmz-web01 (002). The DMZ agent crosses fw01 on the single opening DMZ→monitor01 TCP 1514/1515.
**Config additions:** [`../linux/wazuh-manager-config.py`](../linux/wazuh-manager-config.py)
**Evidence:** [`evidence/a10-wazuh-alerts.txt`](evidence/a10-wazuh-alerts.txt),
[`evidence/a10-active-response.txt`](evidence/a10-active-response.txt),
[`evidence/scenario3-ssh-attempts.txt`](evidence/scenario3-ssh-attempts.txt)

## Log sources

| Source | How it reaches Wazuh |
|---|---|
| srv01, dmz-web01: auth.log, syslog, nginx, dpkg, journald | Wazuh agent (encrypted, TCP 1514) |
| Suricata alerts | `localfile` `/var/log/suricata/eve.json`, JSON format, on the manager |
| fw01 (pfSense) firewall and system logs | syslog UDP 514 → rsyslog → `/var/log/remote/all-devices.log` → `localfile` (syslog format) |
| monitor01 itself | the manager's own agent (000) |

## Alerts from the test window (grouped by agent and rule, first occurrence shown)

| Count | Agent | Rule | Level | Description |
|---|---|---|---|---|
| 12 | srv01 | 5710 | 5 | sshd: attempt to log in using a non-existent user (src 192.168.40.10) |
| 2 | srv01 | 5718 | 5 | sshd: attempt to log in using a denied user (`root`, `ubuntu`, blocked by `AllowUsers`) |
| 1 | srv01 | **5712** | **10** | sshd: brute force trying to get access to the system, non-existent user |
| 1 | srv01 | **651** | 3 | **Host blocked by firewall-drop active response** (192.168.40.10) |
| 24 + 24 | srv01, dmz-web01 | 31101 | 5 | web server 400 error code (the scanner probing /admin, /.git/config) |
| 1 + 1 | srv01, dmz-web01 | 31151 | 10 | multiple web server 400 errors from the same source IP |
| 39 | srv01 | 12105 | 4 | BIND "unexpected error while resolving domain" (the random tunnelling names) |
| 2,736 | monitor01 | 86601 | 3 | Suricata alert (mostly the port-scan rule before tuning) |
| 1 | monitor01 | 19004 | 7 | SCA: CIS Ubuntu 22.04 benchmark score 49% on monitor01 |

## Correlation: one attacker, three sensors

For a single source (kali01, 192.168.40.10), the timeline in alerts.json reads:

1. **Suricata** (network): a port scan, then web-scanner user agents, then a DNS tunnelling pattern, then an SSH connection burst.
2. **nginx logs** on both web servers: a run of 400s, which Wazuh correlates into rule 31151.
3. **sshd** on srv01: 12 invalid users within seconds (5710), which Wazuh correlates into rule 5712 (level 10).
4. **Active response:** the manager tells srv01's agent to run `firewall-drop`, which adds
   `-A INPUT -s 192.168.40.10 -j DROP` and `-A FORWARD …` on srv01. kali01 immediately gets timeouts on
   srv01:22, while dmz-web01 is still reachable (the block is local to the attacked host). It is removed
   automatically after 600 s.

## Active response configuration

```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>          <!-- run on the agent that produced the alert -->
  <rules_id>5712,5763</rules_id>      <!-- invalid-user brute force, failed-password brute force -->
  <timeout>600</timeout>
</active-response>
```

**Lesson:** the first version triggered only on 5763 (multiple *password* failures). After hardening, srv01
no longer accepts passwords, so a brute force shows up as *invalid-user* events (5710 → 5712) and 5763
never fires. The detection had to follow the hardening, so 5712 was added.

## Other observations

- The SCA (CIS benchmark) module scores monitor01 at 49%. That is expected for a lab monitoring server
  running LibreNMS, MariaDB and PHP. It is a hardening backlog item, not an incident.
- The 2,736 Suricata alerts show why tuning matters: before the threshold change, one nmap scan flooded the
  SIEM. See [suricata-alerts.md](suricata-alerts.md).
