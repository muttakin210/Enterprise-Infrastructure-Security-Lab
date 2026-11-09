# IR-006: Suricata restarts every 3 minutes, so no IDS alerts

| Field | Value |
|---|---|
| Date | 2026-11-09, 22:28–22:38 (UTC+6), during the build |
| Severity | High for a SOC: the IDS was blind while showing "active" most of the time |
| Affected | Suricata 8.0.8 on monitor01 |

## Symptom

During the first nmap scans `eve.json` held no alerts, and `stats.capture.kernel_packets` was 0.
`systemctl is-active suricata` printed `active`, because systemd restarted it each time.

## Troubleshooting

| Check | Result |
|---|---|
| `journalctl -u suricata` | `Main process exited, status=1/FAILURE` at 22:28, 22:31, 22:34, then an automatic restart each time |
| `grep Error /var/log/suricata/suricata.log` | `af-packet: enp0s9: failed to set fanout mode: Invalid argument` and `thread "W#01-enp0s8" failed to start in time … Time budget 70s` |
| af-packet section of suricata.yaml | **four** `- interface: enp0s9` entries, three with `cluster-id: 98` |
| `free -m`, `nproc` | 2 GB RAM, 2 vCPU, swap in use |

## Root cause

1. The setup script edited suricata.yaml with a regex that *inserted* the enp0s9 entry on every run.
   After three runs there were duplicate entries sharing a fanout cluster id, which the kernel rejects.
2. The duplicates meant 10 worker threads, and each worker builds its own detection engine context from
   about 53,000 ET Open rules. On a 2-vCPU VM that took longer than Suricata's fixed 70 s thread start
   budget, so the main thread gave up and exited.

## Fix

[`linux/suricata-config.py`](../../linux/suricata-config.py) rewrites the whole block between `af-packet:`
and the `- interface: default` template, so re-runs are idempotent. It sets exactly two interfaces, one
thread each, with cluster ids 98 and 97.

## Verification

`Threads created -> W: 2 FM: 1 FR: 1   Engine started.` The attack simulation then produced alerts on both
interfaces.

## Lessons

- Config-management edits must be idempotent: *replace a block*, never *insert after a match*.
- "Service active" is not "service working". Monitor the IDS itself (packets captured, alerts per hour), not
  just its process.
