#!/usr/bin/env bash
# wireshark-capture.sh - assignment 7, run on kali01 as root.
# Captures a short window of mixed lab traffic on the Security zone NIC, then analyses it with tshark
# (the Wireshark CLI) the same way it is done in the GUI: protocol hierarchy, conversations, DNS, HTTP,
# TCP handshakes/resets, and which protocols are readable in clear text.
set -u
out=${1:-/home/kali/evidence}; pcap=$out/a07-lab-traffic.pcap
rm -f "$pcap"
tcpdump -i eth0 -n -s 0 -w "$pcap" 'not port 22 or host 192.168.20.20' 2>/dev/null & tp=$!
sleep 2
dig +short @192.168.20.20 srv01.corp.lab >/dev/null
dig +short @192.168.20.20 www.corp.lab >/dev/null
dig +short @192.168.20.20 nonexistent.corp.lab >/dev/null
curl -s -o /dev/null http://192.168.20.20/
curl -s -o /dev/null http://192.168.50.10/
curl -s -o /dev/null -m 3 http://192.168.20.20:443/ || true      # closed port -> TCP RST
nc -z -w2 192.168.20.10 8000 || true                                # blocked by fw01 -> no reply at all
ssh -n -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 nobody@192.168.20.20 true 2>/dev/null || true
ping -c2 -W1 192.168.40.1 >/dev/null
sleep 2; kill $tp; wait $tp 2>/dev/null; chown kali:kali "$pcap"
T() { tshark -r "$pcap" -n "$@" 2>/dev/null; }
echo "## capture file: $(basename "$pcap"), $(T | wc -l) packets"
echo "### protocol hierarchy";      T -q -z io,phs | sed -n '/===/,/===/p' | grep -v "^=" | head -20
echo "### IPv4 conversations";      T -q -z conv,ip | sed -n '/<->/p' | head -10
echo "### DNS queries and answers"; T -Y dns -T fields -e frame.number -e ip.src -e dns.qry.name -e dns.flags.rcode -e dns.a | head -10
echo "### HTTP requests (clear text: method, host, user agent, server header)"
T -Y http.request -T fields -e ip.dst -e http.request.method -e http.request.uri -e http.user_agent
T -Y http.response -T fields -e ip.src -e http.response.code -e http.server
echo "### TCP resets (closed ports) and unanswered SYNs (filtered by the firewall)"
T -Y "tcp.flags.reset==1" -T fields -e ip.src -e tcp.srcport -e ip.dst | sort -u
T -Y "tcp.flags.syn==1 && tcp.flags.ack==0" -T fields -e ip.dst -e tcp.dstport | sort | uniq -c
echo "### SSH: only the version banner is readable, everything after key exchange is encrypted"
T -Y ssh.protocol -T fields -e ip.src -e ssh.protocol | sort -u
