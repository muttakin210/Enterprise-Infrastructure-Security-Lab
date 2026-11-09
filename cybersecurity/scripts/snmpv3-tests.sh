#!/usr/bin/env bash
# snmpv3-tests.sh - assignment 6, run on monitor01 as root (credentials from /root/lab-secrets.env).
# Shows that only SNMPv3 authPriv works, every weaker form is refused, and that the payload is encrypted.
set -u
eval "$(cat /root/lab-secrets.env)"
q() { timeout 12 "$@" 2>&1 | sed 's/^[^=]*= //' | head -1; }
OID=.1.3.6.1.2.1.1.5.0   # sysName
for h in 192.168.20.1 192.168.20.20 192.168.50.10; do
  echo "### target $h"
  echo "v3 authPriv SHA/AES (correct)  : $(q snmpget -v3 -l authPriv -u monitoruser -a SHA -A "$SNMP_AUTH" -x AES -X "$SNMP_PRIV" -t 3 -r 1 $h $OID)"
  echo "v3 authPriv wrong auth password: $(q snmpget -v3 -l authPriv -u monitoruser -a SHA -A WrongPassword123 -x AES -X "$SNMP_PRIV" -t 3 -r 0 $h $OID)"
  echo "v3 authNoPriv (no encryption)  : $(q snmpget -v3 -l authNoPriv -u monitoruser -a SHA -A "$SNMP_AUTH" -t 3 -r 0 $h $OID)"
  echo "v3 noAuthNoPriv                : $(q snmpget -v3 -l noAuthNoPriv -u monitoruser -t 3 -r 0 $h $OID)"
  echo "v3 unknown user                : $(q snmpget -v3 -l authPriv -u admin -a SHA -A "$SNMP_AUTH" -x AES -X "$SNMP_PRIV" -t 3 -r 0 $h $OID)"
  echo "v2c community 'public'         : $(q snmpget -v2c -c public -t 3 -r 0 $h $OID)"
  echo "v1  community 'private'        : $(q snmpget -v1 -c private -t 3 -r 0 $h $OID)"
done
echo "### wire view of one v3 request/response (tcpdump): the PDU is encrypted, only the USM header is clear"
cap=/tmp/snmpv3.pcap
rm -f $cap   # tcpdump drops to its own user and cannot overwrite an existing root-owned file in /tmp
timeout 15 tcpdump -i enp0s8 -n -c 4 -w $cap udp port 161 and host 192.168.20.20 2>/dev/null &
sleep 2
snmpget -v3 -l authPriv -u monitoruser -a SHA -A "$SNMP_AUTH" -x AES -X "$SNMP_PRIV" -t 3 192.168.20.20 $OID >/dev/null 2>&1
wait
tcpdump -n -r $cap -vv 2>/dev/null | head -12
echo "printable strings in the captured packets (sysName 'srv01' must NOT appear):"
strings -n 4 $cap | grep -v -e monitoruser | sort -u | head -5
strings $cap | grep -q srv01 && echo "RESULT: plaintext leaked" || echo "RESULT: no plaintext sysName on the wire"
