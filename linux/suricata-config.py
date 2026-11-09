#!/usr/bin/env python3
"""suricata-config.py - lab settings for /etc/suricata/suricata.yaml on monitor01. Idempotent.

- HOME_NET = all lab zones (192.168.0.0/16)
- af-packet on both sensor NICs (enp0s8 Servers zone, enp0s9 DMZ), one thread each, distinct fanout ids
- the lab's own rules file is loaded after the ET Open rules
- exactly one capture thread per NIC: each worker builds its own detection context, and with the
  ~50k ET Open rules on a 2 GB VM more workers miss Suricata's fixed thread start budget
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/etc/suricata/suricata.yaml"
s = open(path).read()

s = re.sub(r'HOME_NET: "\[[^"]*\]"', 'HOME_NET: "[192.168.0.0/16]"', s, count=1)

# everything between "af-packet:" and the "- interface: default" template entry is ours
a = s.index("af-packet:\n")
b = s.index("  - interface: default", a)
block = "".join(
    f"  - interface: {nic}\n"
    f"    threads: 1\n"
    f"    cluster-id: {cid}\n"
    f"    cluster-type: cluster_flow\n"
    f"    defrag: yes\n"
    for nic, cid in (("enp0s8", 98), ("enp0s9", 97))
)
s = s[:a] + "af-packet:\n" + block + s[b:]

if "/etc/suricata/rules/local.rules" not in s:
    s = s.replace("rule-files:\n  - suricata.rules",
                  "rule-files:\n  - suricata.rules\n  - /etc/suricata/rules/local.rules")

open(path, "w").write(s)
print("suricata.yaml: HOME_NET, af-packet enp0s8+enp0s9, local.rules")
