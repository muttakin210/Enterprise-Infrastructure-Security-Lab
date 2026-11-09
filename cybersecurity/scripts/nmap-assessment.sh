#!/usr/bin/env bash
# nmap-assessment.sh - assignments 1-3, run on kali01 (Security zone 192.168.40.10) as root.
# Scope: the five lab /24s only. The Security zone is allowed to reach srv01 and dmz-web01 and nothing
# else internal, so what nmap *cannot* see is part of the result (it proves the firewall policy).
set -u
out=${1:-$HOME/evidence}; mkdir -p "$out"; cd "$out"
ts() { date -u +%FT%TZ; }

echo "## A1 host discovery $(ts)" | tee a01-discovery.txt
for net in 192.168.40.0/24 192.168.20.0/24 192.168.50.0/24 192.168.30.0/24 192.168.10.0/24; do
  echo "### $net (ICMP echo + TCP 22/80/443 SYN + ARP on the local segment)" >> a01-discovery.txt
  nmap -sn -PE -PS22,80,443 -n "$net" -oG - | grep -E '^Host|# Nmap done' >> a01-discovery.txt
done

echo "## A2 full TCP port scan $(ts)" > a02-portscan.txt
nmap -sS -p- -n --min-rate 800 -T4 192.168.20.20 192.168.50.10 -oN - >> a02-portscan.txt
echo "## A2b top UDP ports" >> a02-portscan.txt
nmap -sU --top-ports 25 -n -T4 192.168.20.20 192.168.50.10 -oN - >> a02-portscan.txt

echo "## A3 service and version enumeration $(ts)" > a03-services.txt
nmap -sV -sC -n -p 22,53,80,443 192.168.20.20 192.168.50.10 -oN - >> a03-services.txt
echo "## A3b SSH authentication methods (after hardening: publickey only)" >> a03-services.txt
nmap -n -p22 --script ssh-auth-methods,ssh2-enum-algos 192.168.20.20 -oN - >> a03-services.txt
echo "## A3c DNS: version hidden, recursion limited to lab nets" >> a03-services.txt
nmap -sU -n -p53 --script dns-nsid,dns-recursion 192.168.20.20 -oN - >> a03-services.txt
echo done
