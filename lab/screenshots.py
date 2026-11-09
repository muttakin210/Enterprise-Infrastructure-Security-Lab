"""screenshots.py - capture the pfSense and LibreNMS web GUIs for screenshots/ (headless Chromium).

Logins come from the git-ignored .lab-local/secrets.env and are never printed. Pages that could show
secrets (user manager, SNMP settings) are deliberately not captured.
    python lab/screenshots.py
"""
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
env = {}
for line in (root / ".lab-local" / "secrets.env").read_text().splitlines():
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip("'\"")
out = root / "screenshots"
out.mkdir(exist_ok=True)

PF = "https://127.0.0.1:8443"
NMS = "http://127.0.0.1:8030"


def shot(page, url, name, wait=1500, full=True):
    page.goto(url, wait_until="networkidle", timeout=60000)
    page.wait_for_timeout(wait)
    page.screenshot(path=str(out / name), full_page=full)
    print("saved", name)


with sync_playwright() as p:
    b = p.chromium.launch()
    ctx = b.new_context(ignore_https_errors=True, viewport={"width": 1440, "height": 900})
    page = ctx.new_page()

    # ---- pfSense ----
    page.goto(PF, wait_until="networkidle", timeout=60000)
    page.fill("#usernamefld", "admin")
    page.fill("#passwordfld", env["PFSENSE_ADMIN_PASS"])
    page.click("button[name=login], input[name=login]")
    page.wait_for_load_state("networkidle")
    shot(page, PF + "/index.php", "pfsense-01-dashboard.png", 4000)
    shot(page, PF + "/status_interfaces.php", "pfsense-02-interfaces.png")
    for i, (iface, label) in enumerate([("lan", "mgmt"), ("opt1", "servers"), ("opt2", "users"),
                                         ("opt3", "security"), ("opt4", "dmz"), ("wan", "wan")], start=3):
        shot(page, f"{PF}/firewall_rules.php?if={iface}", f"pfsense-{i:02d}-rules-{label}.png")
    shot(page, PF + "/firewall_aliases.php", "pfsense-09-aliases.png")
    shot(page, PF + "/firewall_nat_out.php", "pfsense-10-outbound-nat.png")
    shot(page, PF + "/status_dhcp_leases.php", "pfsense-11-dhcp-leases.png")
    shot(page, PF + "/status_logs_filter.php", "pfsense-12-firewall-log.png", 2500, full=False)
    shot(page, PF + "/status_logs_settings.php", "pfsense-13-remote-syslog.png")

    # ---- LibreNMS ----
    page.goto(NMS + "/login", wait_until="networkidle", timeout=60000)
    page.fill("input[name=username]", "pel-admin")
    page.fill("input[name=password]", env["LIBRENMS_ADMIN_PASS"])
    page.click("button[type=submit]")
    page.wait_for_load_state("networkidle")
    shot(page, NMS + "/devices", "librenms-01-devices.png", 3000)
    for dev, name in [(6, "fw01"), (7, "srv01"), (8, "dmz-web01")]:
        shot(page, f"{NMS}/device/{dev}", f"librenms-02-{name}.png", 3000)
    shot(page, NMS + "/device/6/ports", "librenms-03-fw01-ports.png", 3000)
    b.close()
