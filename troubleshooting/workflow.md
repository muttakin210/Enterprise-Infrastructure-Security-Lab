# Troubleshooting workflow

The same steps are used for every problem in this lab: start at the bottom of the stack and move up, check
one layer at a time, and write down what each check proved. Every incident report in
[`incident-reports/`](incident-reports/) follows this order.

```
 1. Define      what exactly fails, from where to where, since when, what changed
 2. Layer 1-2   link up? right VirtualBox network / VLAN? (ip -br link, VBoxManage showvminfo, show vlan brief)
 3. Layer 3     right IP/mask/gateway? route? (ip -br a, ip route, ping gateway -> ping target)
 4. Policy      is it allowed?  fw01 rules + firewall log, then the target's UFW (ufw status, /var/log/ufw.log)
 5. Layer 4     does the port answer? (nc -zv, nmap -p, ss -tlnp on the target)
 6. Layer 7     does the service work? (dig, curl -I, snmpget, ssh -v) and what do its logs say
 7. Evidence    capture both sides when unclear (tcpdump on the client NIC and on monitor01's sensor NIC)
 8. Fix         one change at a time; re-test from step 1's exact failing case
 9. Record      incident report: timeline, root cause, fix, prevention
```

## Where to look in this lab

| Question | Command / place |
|---|---|
| Did the firewall block it? | fw01 `filterlog` lines in `/var/log/remote/all-devices.log` on monitor01 (`grep <src-ip>`); pfSense GUI → Status → System Logs → Firewall |
| Did the host firewall block it? | `sudo ufw status numbered`, `/var/log/ufw.log` on the target |
| Is the service listening? | `sudo ss -tulpn` on the target |
| Did the IDS see it? | `jq 'select(.event_type=="alert")' /var/log/suricata/eve.json` on monitor01 |
| What did the SIEM conclude? | `/var/ossec/logs/alerts/alerts.json` on monitor01, `agent_control -l` for agent state |
| Was the source auto-blocked? | `sudo iptables -S \| grep DROP` and `/var/ossec/logs/active-responses.log` on the agent |
| Is SNMP working? | `snmpget -v3 -l authPriv ...` from monitor01; LibreNMS → device → "last polled" |
| DNS? | `dig @192.168.20.20 name`; BIND query log: `journalctl -u named \| grep query:` on srv01 |

## Common symptoms and first suspects

| Symptom | Likely layer | First check |
|---|---|---|
| `ping` fails everywhere | 1–3 | NIC on the wrong internal network, or wrong netplan file |
| `ping` works, TCP connect times out | policy | fw01 block log, then UFW: a timeout means a silent drop |
| TCP "connection refused" | 4 | the port is allowed but no service is listening (an RST came back) |
| Works from one zone, not another | policy | the zone rule order on fw01: the first match wins, and the "block PRIVATE_NETS" rule sits before "pass any" |
| Worked, then stopped for ~10 minutes | SIEM | Wazuh active response `firewall-drop` blocked the source after a brute-force alert |
| SNMP "Unknown user name" | 7 | the v3 user is not loaded on the agent (net-snmp persistent store), see IR-004 |
| SNMP timeout | policy/7 | UFW 161 is only open to monitor01, v1/v2c are disabled by design, or the agent listens on a different address |
