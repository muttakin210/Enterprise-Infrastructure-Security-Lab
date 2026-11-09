#!/usr/bin/env bash
# connectivity-matrix.sh SRC - assignments 5 (firewall testing) and 11 (segmentation), scenario 4.
# Run on one lab host; it tries every target/port below with a 2 s TCP connect (nc -z) or ICMP echo and
# prints  src,dst,service,expected,result,verdict  where "expected" is what the fw01 policy says.
# The same script runs on every zone host; together the outputs form the zone-to-zone matrix.
set -u
src=$1
# target name, ip, service, port ("icmp" for ping)
targets="
fw01-servers-gw 192.168.20.1 ping icmp
fw01-mgmt-gw    192.168.10.1 https 443
monitor01       192.168.20.10 ssh 22
monitor01       192.168.20.10 librenms 8000
monitor01       192.168.20.10 wazuh-agent 1514
srv01           192.168.20.20 ssh 22
srv01           192.168.20.20 dns 53
srv01           192.168.20.20 http 80
dmz-web01       192.168.50.10 ssh 22
dmz-web01       192.168.50.10 http 80
kali01          192.168.40.10 ssh 22
internet        1.1.1.1 https 443
"
# Expected verdicts: fw01 rule set (firewall/README.md) AND the target's own UFW policy (defence in depth).
# Everything not listed for a source is expected to be blocked.
allowed() {  # src -> "dst:service" list
  case "$1" in
    monitor01) echo "fw01-servers-gw:ping srv01:dns srv01:http internet:https" ;;
    srv01)     echo "monitor01:wazuh-agent internet:https" ;;
    dmz-web01) echo "monitor01:wazuh-agent internet:https" ;;
    kali01)    echo "srv01:ssh srv01:dns srv01:http dmz-web01:http internet:https" ;;
    client01)  echo "srv01:ssh srv01:dns srv01:http dmz-web01:http internet:https" ;;
  esac
}
expect() { case " $(allowed "$1") " in *" $2:$3 "*) echo allow ;; *) echo deny ;; esac; }
echo "src,dst,service,expected,result,verdict"
while read -r name ip svc port; do
  [ -z "$name" ] && continue
  [ "$src" = "$name" ] && continue            # do not test a host against itself
  if [ "$port" = icmp ]; then
    ping -c1 -W2 "$ip" >/dev/null 2>&1 && r=allow || r=deny
  else
    nc -z -w2 "$ip" "$port" >/dev/null 2>&1 && r=allow || r=deny
  fi
  e=$(expect "$src" "$name" "$svc")
  [ "$e" = "$r" ] && v=PASS || v=FAIL
  echo "$src,$name($ip),$svc/$port,$e,$r,$v"
done <<< "$targets"
