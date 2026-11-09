# IR-002: Suspicious DNS activity (scenario 2)

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:45 (UTC+6) |
| Severity | High until disproved: the pattern matches DNS tunnelling / data exfiltration |
| Source | 192.168.40.10 (kali01) |
| Resolver | srv01 (BIND, 192.168.20.20) |
| Detected by | Suricata sid 9000010 (long label) and 9000011 (burst); Wazuh 12105 (BIND resolution errors) |
| Evidence | [`a08-dns-investigation.txt`](../../cybersecurity/evidence/a08-dns-investigation.txt) |

## What was seen

- 5 queries such as `358ea82c7dad8857c0204ea3f4f52f5ad9b08c4a21f9fc6aa0.exfil-test.corp.lab`. Each first
  label is 50 random hex characters, which looks like encoded data, not a hostname.
- All of them returned **NXDOMAIN**. An attacker running tunnelling does not need an answer: the data
  leaves in the *question*, when the resolver forwards it toward the attacker's authoritative server.
- A burst of 150 queries in about 3 seconds (35 queries/s at the peak) from the same host.
- 163 queries from kali01 in total, against a normal baseline of a few per minute.

## Investigation steps

1. Suricata alert: `jq 'select(.alert.signature_id==9000010) | .dns' eve.json` gives the query names.
2. BIND query log on srv01: `journalctl -u named | grep query: | grep 192.168.40.10`, to confirm the
   source, count and timing.
3. Entropy check: the labels are hex with no dictionary words and a fixed length, which suggests encoding.
4. Destination domain: `exfil-test.corp.lab` sits inside our own zone, so BIND answers NXDOMAIN
   authoritatively and **nothing was forwarded** to the internet. Had it been an external domain, the
   queries would have gone out through the `forwarders` (1.1.1.1 / 9.9.9.9).
5. Source context: kali01 in the Security zone during the scheduled test window, so it is the planned simulation.

## Conclusion

A simulated exfiltration attempt, detected at the network layer (Suricata) and the server layer (BIND log,
Wazuh). No data could leave, because the test domain was internal.

## Recommendations

- Only the internal resolver may send DNS to the internet. fw01 should block outbound UDP/TCP 53 from every
  zone except srv01, so a host cannot bypass the monitored resolver. Today Users and Security have
  "pass any" to the internet, which includes direct DNS.
- Add a response-policy zone (RPZ) or a DNS firewall for known tunnelling domains.
- Alert on query-length *and* volume per client per domain, not per packet.
