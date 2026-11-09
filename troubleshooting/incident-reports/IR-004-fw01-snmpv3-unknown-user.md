# IR-004: fw01 stops answering SNMPv3: "Unknown user name"

| Field | Value |
|---|---|
| Date | 2026-11-09, found 22:20 (UTC+6) during the build |
| Severity | Medium: monitoring blind spot on the firewall |
| Affected | net-snmp agent on fw01 (192.168.20.1:161) |

## Symptom

From monitor01, `snmpget -v3 -l authPriv -u monitoruser … 192.168.20.1 sysName.0` returned
`Unknown user name`. srv01, with the same command and the same credentials, worked.

## Troubleshooting (workflow order)

| Step | Check | Result |
|---|---|---|
| L3 | `ping 192.168.20.1` from monitor01 | OK |
| Policy | fw01 rule "monitor01 polls fw01 over SNMPv3" (udp 161 → SERVERS address) | present, and the reply proved the packet reached the agent |
| L4 | `pgrep -lf snmpd` on fw01 | running with `-C -c /usr/local/etc/snmp/snmpd.conf` |
| L7 | the error text | "Unknown user name" is a USM report from the agent: it *answered*, but has no such user |
| L7 | `/var/net-snmp/snmpd.conf` (persistent store) | no `usmUser` line; only engineBoots/oldEngineID |

## Root cause

The v3 user was created with a `createUser` line in net-snmp's *persistent* file. snmpd converts that line
into a localised `usmUser` entry and rewrites the file when it shuts down. During the build the agent was
killed and the VM rebooted, so the converted entry was never written, the `createUser` line was gone, and
after the reboot no user existed.

## Fix

`createUser monitoruser SHA … AES …` now lives in the agent's own config file
`/usr/local/etc/snmp/snmpd.conf` (mode 600, root only), so the user is created on every start regardless
of the persistent store ([`firewall/pfsense-snmpv3.sh`](../../firewall/pfsense-snmpv3.sh)).

## Verification

`snmpget` returns `fw01` and the FreeBSD sysDescr. LibreNMS discovered fw01 as OS **pfsense** with 10 ports.
