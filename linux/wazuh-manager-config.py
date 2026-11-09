#!/usr/bin/env python3
"""Add the lab's log sources and active response to the Wazuh manager's ossec.conf (idempotent).

  - Suricata alerts:   /var/log/suricata/eve.json            (json)   -> Wazuh Suricata rules 86600+
  - pfSense syslog:    /var/log/remote/all-devices.log           (syslog) -> pf filterlog decoders
  - Active response:   firewall-drop for 10 min on SSH brute force (rules 5712 invalid users, 5763 failed passwords) on the agent that saw it
usage: wazuh-manager-config.py /var/ossec/etc/ossec.conf
"""
import sys

path = sys.argv[1]
s = open(path).read()
marker = "<!-- PEL lab additions -->"
if marker in s:
    print("ossec.conf already has the lab additions")
    sys.exit(0)

block = f"""
{marker}
<ossec_config>
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/suricata/eve.json</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/remote/all-devices.log</location>
  </localfile>
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>5712,5763</rules_id>
    <timeout>600</timeout>
  </active-response>
</ossec_config>
"""
open(path, "w").write(s.rstrip() + "\n" + block)
print("ossec.conf: added Suricata eve.json, fw01 syslog and SSH brute-force active response")
