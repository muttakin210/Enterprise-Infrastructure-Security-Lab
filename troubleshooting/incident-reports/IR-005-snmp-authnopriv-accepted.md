# IR-005: Ubuntu SNMP agents accept unencrypted SNMPv3 (authNoPriv)

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:32 (UTC+6), found by assignment 6 |
| Severity | Medium: policy says authPriv only, so monitoring data could cross the network in clear text |
| Affected | srv01, dmz-web01 (net-snmp 5.9 on Ubuntu 22.04); fw01 not affected |
| Evidence | [`a06-snmpv3-before-fix.txt`](../../cybersecurity/evidence/a06-snmpv3-before-fix.txt) → [`a06-snmpv3.txt`](../../cybersecurity/evidence/a06-snmpv3.txt) |

## Symptom

The SNMPv3 test matrix from monitor01:

| Security level | fw01 | srv01 | dmz-web01 |
|---|---|---|---|
| authPriv (SHA/AES) | answers | answers | answers |
| **authNoPriv** | refused | **answers** | **answers** |
| noAuthNoPriv, v2c, v1, wrong password, unknown user | refused | refused | refused |

## Root cause

`/etc/snmp/snmpd.conf` correctly says `rouser monitoruser priv`. But `net-snmp-create-v3-user -ro`, the
Ubuntu helper used to create the user, also appends `rouser monitoruser` (no level, which means authNoPriv
or higher) to `/usr/share/snmp/snmpd.conf`. snmpd reads both files, and the looser access line wins.

Found with: `grep -Hn ^rouser /etc/snmp/snmpd.conf /usr/share/snmp/snmpd.conf /var/lib/snmp/snmpd.conf`.

## Fix

`linux/server-setup.sh` now deletes the helper's bare `rouser monitoruser` line after creating the user.
Applied on both servers, then `systemctl restart snmpd`.

## Verification

authNoPriv now returns `Error in packet` (an authorizationError) on all three agents. A tcpdump of a real
poll shows flags `F=apr` (authenticated, private) and an encrypted `ScopedPDU`, and `strings` on the pcap
does not contain the sysName.

## Lesson

Test the *negative* cases, not only "does monitoring work". The policy was right in the file everyone looks
at, and wrong in effect.
