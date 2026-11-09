# IR-003: Failed SSH login investigation (scenario 3)

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:45–22:57 (UTC+6) |
| Severity | High (Wazuh level 10): brute force against a server |
| Source | 192.168.40.10 (kali01) |
| Target | srv01 192.168.20.20:22 |
| Detected by | Wazuh 5710, 5718, 5712 (level 10); Suricata sid 9000020 |
| Contained by | Wazuh active response `firewall-drop` (rule 651) for 600 s |
| Evidence | [`scenario3-ssh-attempts.txt`](../../cybersecurity/evidence/scenario3-ssh-attempts.txt), [`a10-wazuh-alerts.txt`](../../cybersecurity/evidence/a10-wazuh-alerts.txt), [`a10-active-response.txt`](../../cybersecurity/evidence/a10-active-response.txt) |

## Timeline

| Time | Event |
|---|---|
| 22:45:16 | Hydra password attack starts; it aborts at once: *"target does not support password authentication"* |
| 22:46:49 | 12 login attempts as admin, root, oracle, test, guest, ubuntu, postgres, ftp, deploy, git, www, backup; all get `Permission denied (publickey)` |
| 22:46:5x | Wazuh: 12 × 5710 (non-existent user), 2 × 5718 (denied user: `root` and `ubuntu` are not in `AllowUsers`) |
| 22:46:54 | Wazuh: **5712**, brute force with non-existent users, level 10 |
| 22:46:56 | srv01 agent runs `firewall-drop`: `iptables -A INPUT/FORWARD -s 192.168.40.10 -j DROP` (rule 651 "Host blocked") |
| 22:46:57 | kali01 → srv01:22 now times out; kali01 → dmz-web01:80 still works |
| 22:56:56 | the timeout expires and the agent removes the DROP rules automatically |

## Investigation

1. `jq 'select(.rule.id=="5712")' alerts.json`: source IP, agent, matched log lines.
2. On srv01: `journalctl -u ssh | grep 192.168.40.10` shows `Invalid user <name> from 192.168.40.10` and
   `Connection closed by invalid user … [preauth]`. **No** `Accepted` line for that IP.
3. Were any valid accounts tried? `labadmin` was in the Hydra list, but password auth is off, so the
   attempt could not even be made.
4. Containment check: `iptables -S | grep 192.168.40.10` on srv01, `/var/ossec/logs/active-responses.log`.

## Root cause

Simulated credential attack from the Security zone. It could not succeed because of the assignment 4
hardening: publickey only, `AllowUsers labadmin`, `MaxAuthTries 3`, no root login.

## Lessons

- The **detection had to follow the hardening**. The active response was first tied only to rule 5763
  (failed passwords), which can no longer happen on srv01. The real attack pattern is invalid users (5712),
  so 5712 was added to `rules_id`.
- The active response blocks only on the attacked host. Blocking at fw01 as well (an alias fed by
  Wazuh) would stop the attacker moving on to the next server.
- `LogLevel VERBOSE` gives Wazuh the key fingerprint for successful logins, which is useful for tracing
  stolen keys.
