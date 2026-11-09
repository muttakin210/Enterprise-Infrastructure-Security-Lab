# IR-001: Unauthorised port discovery (scenario 1)

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:31–22:45 (UTC+6) |
| Severity | Medium: reconnaissance, no compromise |
| Source | 192.168.40.10 (kali01, Security zone) |
| Targets | srv01 192.168.20.20, dmz-web01 192.168.50.10; sweeps of all five zones |
| Detected by | Suricata sid 9000001 (port scan), ET 2024364 (Nmap user agent), Wazuh 86601 |

## Timeline

| Time | Event | Source |
|---|---|---|
| 22:31 | ICMP/TCP host discovery of the five /24 networks | fw01 block log (Users and Management probes dropped) |
| 22:38–22:43 | full 65,535-port TCP SYN scan of srv01 and dmz-web01 | Suricata 9000001: 1,781 alerts on enp0s8, 1,660 on enp0s9 |
| 22:43–22:44 | `-sV -sC` service probes, NSE scripts | ET SCAN Nmap user agent, nginx 400s (Wazuh 31101/31151) |
| 22:45 | scan from the scenario script repeated | single alerts after tuning |

## Investigation

1. Suricata alerts: `jq 'select(.event_type=="alert") | .src_ip' eve.json | sort | uniq -c` shows one
   source, 192.168.40.10.
2. Address book: 192.168.40.10 is kali01 in the **Security zone**. Scanning srv01 and dmz-web01 from there
   is authorised by the policy (the "authorised test targets only" rule).
3. Scope check in the fw01 log: the probes to 192.168.30.0/24 and 192.168.10.0/24 were all **blocked and
   logged**. The scanner never saw those zones (0 hosts up).
4. Exposure: only srv01 22/53/80 and dmz-web01 80 answered, which matches the intended service list.

## Root cause and classification

An authorised assessment from the Security zone. A real attacker in the same position would learn exactly
what the assessment learned: two hosts and four services. Segmentation contained the reconnaissance.

## Actions

- **Detection tuning:** sid 9000001 changed to `threshold type both … seconds 60` (one alert per source
  per minute) because the original version flooded Wazuh with about 1,700 alerts per scan.
- **Least privilege:** TCP 443 is open on fw01 and UFW but has no service. Close it until HTTPS exists
  (finding N-1 in [nmap-assessment.md](../../cybersecurity/nmap-assessment.md)).
- **Process:** announce Security-zone scan windows so the SOC can tell tests from real activity. Outside a
  window, the same alert from a non-Security source is a P1.
