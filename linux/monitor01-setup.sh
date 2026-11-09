#!/usr/bin/env bash
# monitor01-setup.sh - turn the ENL clone into monitor01 (Servers zone 192.168.20.10). Run as root, idempotent.
#   LibreNMS (already installed, nginx :8000)  - network monitoring over SNMPv3
#   Suricata (IDS, af-packet on the promiscuous zone NICs) - ET Open rules + local lab rules
#   Wazuh manager 4.14 - agents on srv01/dmz-web01/client01, pfSense logs via syslog
#   rsyslog - receives fw01 logs (UDP 514) into /var/log/remote/
set -eu
export DEBIAN_FRONTEND=noninteractive
here=$(cd "$(dirname "$0")" && pwd)

# ---- 1. identity and services left over from the ENL lab ----
hostnamectl set-hostname monitor01
sed -i 's/^127.0.1.1.*/127.0.1.1 monitor01.corp.lab monitor01/' /etc/hosts
for s in zabbix-server zabbix-agent2 grafana-server netbox netbox-rq redis-server postgresql \
         kea-dhcp4-server named isc-dhcp-relay frr; do
  systemctl disable --now "$s" >/dev/null 2>&1 || true
done

# ---- 2. network: NIC1 = NAT for host management only, NIC2 = Servers zone, NIC3 = DMZ sniff-only ----
rm -f /etc/netplan/*.yaml
cat > /etc/netplan/50-lab.yaml <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:            # VirtualBox NAT: host management (127.0.0.1:2230 / :8030); no default route
      dhcp4: true
      dhcp4-overrides: {use-routes: false, use-dns: false}
    enp0s8:            # Servers zone
      addresses: [192.168.20.10/24]
      routes: [{to: default, via: 192.168.20.1}]
      nameservers: {addresses: [192.168.20.20, 1.1.1.1], search: [corp.lab]}
    enp0s9:            # DMZ, IDS sensor only: no IP address
      dhcp4: false
      link-local: []
EOF
chmod 600 /etc/netplan/50-lab.yaml

# ---- 3. Suricata IDS ----
if ! command -v suricata >/dev/null; then
  add-apt-repository -y ppa:oisf/suricata-stable >/dev/null
  apt-get update -q && apt-get install -y -q suricata jq
fi
install -m 644 "$here/../cybersecurity/suricata/local.rules" /etc/suricata/rules/local.rules
python3 - <<'PY'
import re
p = "/etc/suricata/suricata.yaml"
s = open(p).read()
s = re.sub(r'HOME_NET: "\[[^"]*\]"', 'HOME_NET: "[192.168.0.0/16]"', s, count=1)
# af-packet on both sensor interfaces
s = re.sub(r'af-packet:\n  - interface: \S+', 'af-packet:\n  - interface: enp0s8\n    cluster-id: 98\n    cluster-type: cluster_flow\n    defrag: yes\n  - interface: enp0s9', s, count=1)
if "local.rules" not in s:
    s = s.replace("rule-files:\n  - suricata.rules", "rule-files:\n  - suricata.rules\n  - /etc/suricata/rules/local.rules")
open(p, "w").write(s)
PY
suricata-update -q --no-test >/dev/null 2>&1 || suricata-update >/dev/null
suricata -T -c /etc/suricata/suricata.yaml -q
systemctl enable suricata >/dev/null; systemctl restart suricata

# ---- 4. Wazuh manager (no indexer/dashboard on this 16 GB host: alerts go to alerts.json) ----
if ! dpkg -s wazuh-manager >/dev/null 2>&1; then
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import >/dev/null
  chmod 644 /usr/share/keyrings/wazuh.gpg
  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
  apt-get update -q && apt-get install -y -q wazuh-manager
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list
fi
python3 "$here/wazuh-manager-config.py" /var/ossec/etc/ossec.conf
systemctl enable wazuh-manager >/dev/null; systemctl restart wazuh-manager

# ---- 5. host firewall ----
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
ufw allow from 10.0.2.2 to any port 22 proto tcp comment 'host management via NAT' >/dev/null
ufw allow from 10.0.2.2 to any port 8000 proto tcp comment 'LibreNMS from host via NAT' >/dev/null
ufw allow from 192.168.10.0/24 to any port 22,8000 proto tcp comment 'Management zone' >/dev/null
ufw allow from 192.168.20.1 to any port 22 proto tcp comment 'fw01 jump host' >/dev/null
ufw allow from 192.168.20.1 to any port 514 proto udp comment 'fw01 syslog' >/dev/null
ufw allow from 192.168.10.0/24 to any port 514 proto udp comment 'device syslog' >/dev/null
ufw allow from 192.168.0.0/16 to any port 1514,1515 proto tcp comment 'Wazuh agents' >/dev/null
ufw logging on >/dev/null; ufw --force enable >/dev/null
echo "monitor01 setup done (netplan applies on next boot)"
