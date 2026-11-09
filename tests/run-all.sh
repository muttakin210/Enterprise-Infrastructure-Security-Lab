#!/usr/bin/env bash
# run-all.sh - health and policy checks for the whole lab, run from the Windows host (Git Bash) in the repo root.
#   bash tests/run-all.sh            # prints PASS / FAIL / SKIP per check and a summary
# Needs the access helpers in the git-ignored .lab-local/ (fw.sh, mon.sh, in.sh). A VM that is powered off
# is reported as SKIP, not FAIL. Secrets are never printed: SNMP checks source /root/lab-secrets.env on monitor01.
set -u
cd "$(dirname "$0")/.."
L=.lab-local
pass=0; fail=0; skip=0
ok()   { echo "PASS  $1"; pass=$((pass+1)); }
bad()  { echo "FAIL  $1${2:+  ($2)}"; fail=$((fail+1)); }
na()   { echo "SKIP  $1${2:+  ($2)}"; skip=$((skip+1)); }
chk()  { # name expected-substring command...
  local name=$1 want=$2; shift 2
  local out; out=$("$@" 2>&1)
  case "$out" in *"$want"*) ok "$name" ;; *) bad "$name" "$(echo "$out" | tail -1 | cut -c1-90)" ;; esac
}
up()   { timeout 25 "$@" true >/dev/null 2>&1; }

echo "== fw01 (pfSense)"
if up bash $L/fw.sh; then
  chk "fw01: filter rules loaded (>20)"           yes  bash $L/fw.sh 'test $(pfctl -sr 2>/dev/null | wc -l) -gt 20 && echo yes'
  chk "fw01: DHCP server for Users running"       yes  bash $L/fw.sh 'pgrep -q dhcpd && echo yes'
  chk "fw01: SNMP agent running"                  yes  bash $L/fw.sh 'pgrep -q snmpd && echo yes'
  chk "fw01: remote syslog to monitor01"          192.168.20.10 bash $L/fw.sh 'grep -h "@192.168.20.10" /var/etc/syslog.d/*.conf /etc/syslog.conf 2>/dev/null | head -1'
else na "fw01" "not reachable"; fi

echo "== monitor01 (LibreNMS, Suricata, Wazuh manager)"
if up bash $L/mon.sh; then
  for s in suricata wazuh-manager rsyslog snmpd nginx; do
    chk "monitor01: $s active" active bash $L/mon.sh "systemctl is-active $s"
  done
  chk "monitor01: Suricata local rules loaded"    9000001 bash $L/mon.sh 'sudo grep -h "sid:9000001" /etc/suricata/rules/local.rules'
  chk "monitor01: Suricata logged events in last 24 h" yes bash $L/mon.sh 'sudo find /var/log/suricata/eve.json -mmin -1440 | grep -q . && echo yes'
  chk "monitor01: Wazuh agents srv01+dmz-web01 registered" 2 bash $L/mon.sh 'sudo /var/ossec/bin/agent_control -l | grep -cE "srv01|dmz-web01"'
  chk "LibreNMS web answers (host :8030)"         200  curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8030/login
  for h in 192.168.20.1 192.168.20.20 192.168.50.10; do
    chk "SNMPv3 authPriv to $h works"             STRING bash $L/mon.sh "sudo bash -c '. /root/lab-secrets.env; snmpget -v3 -l authPriv -u monitoruser -a SHA -A \"\$SNMP_AUTH\" -x AES -X \"\$SNMP_PRIV\" -t 3 -r 1 $h .1.3.6.1.2.1.1.5.0'"
    chk "SNMPv2c 'public' refused by $h"          Timeout bash $L/mon.sh "snmpget -v2c -c public -t 2 -r 0 $h .1.3.6.1.2.1.1.5.0"
  done
else na "monitor01" "not reachable"; fi

for h in srv01 dmz-web01; do
  echo "== $h"
  if up bash $L/in.sh $h; then
    chk "$h: nginx active"                        active bash $L/in.sh $h 'systemctl is-active nginx'
    chk "$h: wazuh-agent active"                  active bash $L/in.sh $h 'systemctl is-active wazuh-agent'
    chk "$h: UFW enabled"                         active bash $L/in.sh $h 'sudo ufw status | head -1'
    chk "$h: SSH password login disabled"         "passwordauthentication no" bash $L/in.sh $h 'sudo sshd -T | grep -i ^passwordauthentication'
    chk "$h: SSH root login disabled"             "permitrootlogin no" bash $L/in.sh $h 'sudo sshd -T | grep -i ^permitrootlogin'
    [ $h = srv01 ] && chk "srv01: DNS answers www.corp.lab" 192.168.50.10 bash $L/in.sh srv01 'dig +short @127.0.0.1 www.corp.lab'
    # zone policy from this host: every line of the matrix must be PASS
    m=$(bash $L/in.sh $h "bash -s $h" < cybersecurity/scripts/connectivity-matrix.sh 2>/dev/null | tail -n +2)
    n=$(echo "$m" | grep -c ,PASS); f=$(echo "$m" | grep -c ,FAIL)
    if [ "$n" -gt 0 ] && [ "$f" -eq 0 ]; then ok "$h: connectivity matrix $n/$n as policy says"
    else bad "$h: connectivity matrix" "$f failing: $(echo "$m" | grep ,FAIL | head -2 | tr '\n' ' ')"; fi
  else na "$h" "powered off or unreachable"; fi
done

for h in kali01 client01; do
  echo "== $h"
  if up bash $L/in.sh $h; then
    m=$(bash $L/in.sh $h "bash -s $h" < cybersecurity/scripts/connectivity-matrix.sh 2>/dev/null | tail -n +2)
    n=$(echo "$m" | grep -c ,PASS); f=$(echo "$m" | grep -c ,FAIL)
    if [ "$n" -gt 0 ] && [ "$f" -eq 0 ]; then ok "$h: connectivity matrix $n/$n as policy says"
    else bad "$h: connectivity matrix" "$f failing"; fi
  else na "$h" "powered off (started only for the attack and client tests)"; fi
done

echo "== repository"
leak=0
if [ -f $L/secrets.env ]; then
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    git grep -qF -- "$v" -- . ':!.lab-local' 2>/dev/null && leak=1
  done < <(sed -n 's/^[A-Z_]*=//p' $L/secrets.env $L/pel.env $L/pt-secrets.env 2>/dev/null | sed "s/^['\"]//;s/['\"]\$//" | grep -v '^labadmin$' | sort -u)
  [ $leak = 0 ] && ok "no lab secret value in tracked files" || bad "a lab secret value is in a tracked file"
else na "secret scan" "no .lab-local/secrets.env"; fi
pk="PRIVATE"" KEY"   # split so this script does not match its own pattern
git grep -qE "BEGIN [A-Z ]*$pk" && bad "private key in tracked files" || ok "no private key in tracked files"

echo
echo "RESULT: $pass passed, $fail failed, $skip skipped"
[ $fail -eq 0 ]
