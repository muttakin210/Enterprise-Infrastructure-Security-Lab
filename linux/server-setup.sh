#!/usr/bin/env bash
# server-setup.sh ROLE - configure a clone of the Ubuntu base for its lab role (run as root, idempotent).
#   ROLE: srv01 | dmz-web01 | client01
# Phase "packages" runs while NIC1 is still on VirtualBox NAT (apt works); phase "network" writes the
# zone netplan that takes effect after the NIC is moved onto the zone's internal network.
#   sudo ./server-setup.sh srv01 packages
#   sudo ./server-setup.sh srv01 network
# Secrets come from /root/lab-secrets.env (mode 600): SNMP_AUTH, SNMP_PRIV.
set -eu
role=$1; phase=${2:-all}
. /root/lab-secrets.env
case $role in
  srv01)     ip=192.168.20.20; gw=192.168.20.1; dhcp=no ;;
  dmz-web01) ip=192.168.50.10; gw=192.168.50.1; dhcp=no ;;
  client01)  ip=dhcp;          gw=;             dhcp=yes ;;
  *) echo "unknown role $role"; exit 1 ;;
esac
here=$(cd "$(dirname "$0")" && pwd)
export DEBIAN_FRONTEND=noninteractive

packages() {
  hostnamectl set-hostname "$role"
  sed -i "s/^127.0.1.1.*/127.0.1.1 $role.corp.lab $role/" /etc/hosts
  # the base image was built with cloud-init, which would reset the hostname to the base name on boot
  echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-pel-hostname.cfg
  apt-get update -q
  common="openssh-server snmpd snmp curl dnsutils tcpdump ufw auditd jq"
  case $role in
    srv01)     apt-get install -y -q $common nginx bind9 bind9-utils ;;
    dmz-web01) apt-get install -y -q $common nginx ;;
    client01)  apt-get install -y -q $common ;;
  esac
  # Wazuh agent (enrolled later, once the manager on monitor01 is up)
  if ! dpkg -s wazuh-agent >/dev/null 2>&1; then
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import >/dev/null
    chmod 644 /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
    apt-get update -q
    WAZUH_MANAGER=192.168.20.10 WAZUH_AGENT_NAME=$role apt-get install -y -q wazuh-agent
    sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list   # pin the version: no surprise upgrades
  fi
  configure_services
}

configure_services() {
  # ---- SNMPv3 agent: authPriv only, answers the monitoring server only ----
  systemctl stop snmpd
  if ! grep -q monitoruser /var/lib/snmp/snmpd.conf 2>/dev/null; then
    net-snmp-create-v3-user -ro -A "$SNMP_AUTH" -X "$SNMP_PRIV" -a SHA -x AES monitoruser >/dev/null
  fi
  cat > /etc/snmp/snmpd.conf <<EOF
# SNMPv3 only (no v1/v2c communities). UFW limits UDP 161 to monitor01 (192.168.20.10).
agentaddress udp:161
rouser monitoruser priv
sysLocation PEL lab - $role
sysContact labadmin@corp.lab
sysName $role
includeAllDisks 10%
EOF
  systemctl enable --now snmpd

  # ---- role services ----
  case $role in
    srv01)
      install -m 644 "$here/dns/named.conf.options" /etc/bind/named.conf.options
      install -m 644 "$here/dns/named.conf.local" /etc/bind/named.conf.local
      install -d -o root -g bind /etc/bind/zones
      install -m 644 "$here/dns/db.corp.lab" /etc/bind/zones/db.corp.lab
      install -m 644 "$here/dns/db.192.168" /etc/bind/zones/db.192.168
      named-checkconf && named-checkzone corp.lab /etc/bind/zones/db.corp.lab >/dev/null
      systemctl enable --now named; systemctl restart named
      printf '<h1>corp.lab intranet</h1><p>srv01 - Servers zone (192.168.20.20)</p>\n' > /var/www/html/index.html ;;
    dmz-web01)
      printf '<h1>Public test site</h1><p>dmz-web01 - DMZ (192.168.50.10)</p>\n' > /var/www/html/index.html ;;
  esac
  case $role in srv01|dmz-web01) sed -i 's/# server_tokens off;/server_tokens off;/' /etc/nginx/nginx.conf; systemctl enable --now nginx; systemctl reload nginx ;; esac

  # ---- host firewall (UFW): default deny, per-source rules ----
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
  ufw allow from 192.168.20.10 to any port 161 proto udp comment 'SNMPv3 from monitor01' >/dev/null
  ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH from Management' >/dev/null
  ufw allow from 192.168.20.1 to any port 22 proto tcp comment 'SSH via fw01 jump host' >/dev/null
  ufw allow from 192.168.50.1 to any port 22 proto tcp comment 'SSH via fw01 jump host' >/dev/null
  ufw allow from 192.168.30.1 to any port 22 proto tcp comment 'SSH via fw01 jump host' >/dev/null
  ufw allow from 10.0.2.2 to any port 22 proto tcp comment 'build phase: host via VirtualBox NAT' >/dev/null
  case $role in
    srv01)
      ufw allow from 192.168.0.0/16 to any port 53 comment 'DNS for lab zones' >/dev/null
      ufw allow from 192.168.30.0/24 to any port 22 proto tcp comment 'SSH from Users' >/dev/null
      ufw allow from 192.168.40.0/24 to any port 22 proto tcp comment 'SSH from Security (authorised tests)' >/dev/null
      ufw allow 80,443/tcp comment 'intranet web' >/dev/null ;;
    dmz-web01)
      ufw allow 80,443/tcp comment 'public web' >/dev/null ;;
  esac
  ufw logging on >/dev/null
  ufw --force enable >/dev/null
}

network() {
  # the DMZ may not reach internal zones (policy), so dmz-web01 resolves through a public resolver
  dns=192.168.20.20; [ "$role" = dmz-web01 ] && dns=1.1.1.1
  if [ "$dhcp" = yes ]; then
    addr="      dhcp4: true"
  else
    addr="      addresses: [$ip/24]
      routes: [{to: default, via: $gw}]
      nameservers: {addresses: [$dns], search: [corp.lab]}"
  fi
  rm -f /etc/netplan/*.yaml
  cat > /etc/netplan/50-lab.yaml <<EOF
# $role - NIC1 on the VirtualBox internal network of its zone
network:
  version: 2
  ethernets:
    enp0s3:
$addr
EOF
  chmod 600 /etc/netplan/50-lab.yaml
  echo "netplan written for $role ($ip); applies on next boot"
}

case $phase in
  packages) packages ;;
  services) configure_services ;;
  network)  network ;;
  all)      packages; network ;;
esac
