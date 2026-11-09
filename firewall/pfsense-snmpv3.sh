#!/bin/sh
# pfsense-snmpv3.sh - SNMPv3 (authPriv) agent on fw01. pfSense's built-in bsnmpd only speaks v1/v2c,
# so the FreeBSD net-snmp agent is used with a v3-only config, listening on the Servers-zone address
# only (192.168.20.1), where monitor01 polls it. Started at boot by a pfSense shellcmd.
#   sh pfsense-snmpv3.sh /root/pel.env      (env provides SNMP_AUTH, SNMP_PRIV)
set -e
. "$1"
pkg info -q net-snmp || pkg -4 install -y net-snmp
mkdir -p /usr/local/etc/snmp /var/net-snmp
cat > /usr/local/etc/snmp/snmpd.conf <<'EOF'
# SNMPv3 only: no communities. Listens on the Servers-zone interface only.
agentaddress udp:192.168.20.1:161
rouser monitoruser priv
sysName fw01
sysLocation PEL lab - firewall
sysContact labadmin@corp.lab
EOF
pkill -x snmpd 2>/dev/null || true
sleep 1
# createUser in the persistent file is converted to a localized key on first start
# (after the first start the user is stored as a usmUser line with the name in hex: 6d6f6e69746f7275736572)
grep -q -e monitoruser -e 6d6f6e69746f7275736572 /var/net-snmp/snmpd.conf 2>/dev/null || \
  echo "createUser monitoruser SHA \"$SNMP_AUTH\" AES \"$SNMP_PRIV\"" >> /var/net-snmp/snmpd.conf
/usr/local/sbin/snmpd -C -c /usr/local/etc/snmp/snmpd.conf -p /var/run/net-snmpd.pid
sleep 1
pgrep -x snmpd >/dev/null && echo "net-snmp v3 agent running on 192.168.20.1:161"
