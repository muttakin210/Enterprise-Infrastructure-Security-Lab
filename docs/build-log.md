# Build log

What was done, in order, with the problems hit and how they were solved.

## Host

| Item | Value |
|---|---|
| Laptop | Windows 11 Pro, Intel Core i5-1235U (12 threads), 16 GB RAM |
| Free RAM with normal apps open | about 3 GB, so VMs run a few at a time (as the project plan advises) |
| Hypervisor | VirtualBox 7.2.4 |
| Lab storage | `E:\VMs\PEL` (dynamically allocated disks) |

## Steps

| # | Step | Result |
|---|---|---|
| 1 | Repository, zones, firewall policy, addressing plan | ✅ |
| 2 | Base Ubuntu 22.04 VM, unattended install from the local ISO (`lab/vbox/new-ubuntu-base.ps1`) | in progress |
| 3 | kali01 from the official Kali 2025.4 VirtualBox image (`lab/vbox/new-kali.ps1`) | VM registered |
| 4 | monitor01 as a linked clone of the earlier ENL server, which already has LibreNMS (`lab/vbox/new-monitor01.ps1`) | VM registered |
| 5 | Cisco CORE-SW1 and FW01 configs (`cisco/`) | written |
| 6 | pfSense CE 2.7.2 ISO, checksum-verified against Netgate's SHA-256 | downloading |

## Problems and fixes

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | `VBoxManage unattended install` failed: unknown option `--install-additions=false` | Not a valid flag in VirtualBox 7.2 (additions are off unless `--install-additions` is given) | Removed the flag and re-ran the unattended step. |
| 2 | pfSense ISO download at ~30 KB/s (5+ hours) | Netgate's primary server was slow from here and its other mirrors no longer answer; the internet link itself was fine (4–6 MB/s to Ubuntu/Cloudflare) | Used the DSU community mirror with 8 parallel range requests, then verified the file against Netgate's own SHA-256. |
