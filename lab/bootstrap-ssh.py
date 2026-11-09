#!/usr/bin/env python3
"""One-time bootstrap of a freshly installed Ubuntu VM over its NAT port forward:
install the lab SSH public key for labadmin and write /root/lab-secrets.env (mode 600).
After this, every other step uses key-based SSH only.

usage: bootstrap-ssh.py PORT
reads .lab-local/secrets.env (LAB_USER, LAB_PASS, SNMP_AUTH, SNMP_PRIV) and .lab-local/pel_ed25519.pub
"""
import pathlib, shlex, sys
import paramiko

root = pathlib.Path(__file__).resolve().parent.parent
sec = dict(l.split("=", 1) for l in (root / ".lab-local/secrets.env").read_text().split("\n") if "=" in l)
pub = (root / ".lab-local/pel_ed25519.pub").read_text().strip()
port = int(sys.argv[1])

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("127.0.0.1", port=port, username=sec["LAB_USER"], password=sec["LAB_PASS"],
          look_for_keys=False, allow_agent=False, timeout=15)

def run(cmd, sudo=False):
    if sudo:
        cmd = "sudo -S -p '' bash -c " + shlex.quote(cmd)
    stdin, stdout, stderr = c.exec_command(cmd)
    if sudo:
        stdin.write(sec["LAB_PASS"] + "\n"); stdin.flush()
    rc = stdout.channel.recv_exit_status()
    return rc, stdout.read().decode(), stderr.read().decode()

run(f"install -d -m 700 ~/.ssh && grep -qxF {shlex.quote(pub)} ~/.ssh/authorized_keys 2>/dev/null || echo {shlex.quote(pub)} >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys")
env = "".join(f"{k}={shlex.quote(sec[k])}\n" for k in ("SNMP_AUTH", "SNMP_PRIV"))
rc, out, err = run(f"umask 077; printf %s {shlex.quote(env)} > /root/lab-secrets.env; "
                   f"echo '{sec['LAB_USER']} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-labadmin; chmod 440 /etc/sudoers.d/90-labadmin; "
                   "visudo -cf /etc/sudoers.d/90-labadmin >/dev/null && echo ok", sudo=True)
print("bootstrap:", out.strip() or err.strip())
c.close()
