#!/usr/bin/env python3
"""Derive Packet Tracer 9.0 configs from cisco/core-sw1.cfg and cisco/fw01-edge.cfg (single source of truth).

Changes (and why):
  * snmp-server lines and the SNMP-MANAGER ACL removed: Packet Tracer has no SNMPv3 agent
    (SNMPv3 is implemented and tested on the VirtualBox lab instead: fw01, srv01, dmz-web01)
  * 'logging trap' removed: not in PT's parser (the IOS default trap level is informational anyway)
  * ' log' removed from ACL deny entries: PT ACLs have no log keyword
  * 'crypto key generate rsa modulus N' -> 'crypto key generate rsa general-keys modulus N' (no prompt in PT)
  * 'write memory' kept, comment lines (!) dropped so a paste does not echo noise
Placeholders (<ENABLE_SECRET> ...) are kept here; the build substitutes Packet-Tracer-only values.
"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent
DROP = [r"^\s*snmp-server .*$", r"^\s*logging trap .*$", r"^!.*$"]


def convert(text: str) -> str:
    out, skip = [], False
    for line in text.splitlines():
        if skip:
            if line.startswith(" "):
                continue
            skip = False
        if line.startswith("ip access-list standard SNMP-MANAGER"):
            skip = True
            continue
        if any(re.match(p, line) for p in DROP) or not line.strip():
            continue
        line = re.sub(r"^(\s*deny\s.*?)\s+log$", r"\1", line)
        line = re.sub(r"crypto key generate rsa modulus (\d+)",
                      r"crypto key generate rsa general-keys modulus \1", line)
        out.append(line)
    return "\n".join(out) + "\n"


def main() -> None:
    (HERE / "configs").mkdir(exist_ok=True)
    for src, name in (("core-sw1.cfg", "CORE-SW1"), ("fw01-edge.cfg", "FW01")):
        dst = HERE / "configs" / f"{name}.txt"
        dst.write_text(convert((SRC / src).read_text()), newline="\n")
        print("wrote", dst.relative_to(SRC.parent))


if __name__ == "__main__":
    main()
