# new-monitor01.ps1 - monitor01 (Servers zone, 192.168.20.10): LibreNMS + Suricata + Wazuh manager.
# Linked clone of the ENL lab server (Ubuntu 22.04 with LibreNMS already installed and validated),
# so the slow-to-download LibreNMS stack is reused; unrelated ENL services are disabled inside the VM
# by linux/monitor01-setup.sh.
#   NIC1  NAT  - management from the host only (127.0.0.1:2230 ssh, :8030 LibreNMS), no default route
#   NIC2  intnet pel-servers, promiscuous allow-all so Suricata sees all traffic in the Servers zone
#   NIC3  intnet pel-dmz, promiscuous, no IP: IDS sensor for the DMZ
$ErrorActionPreference = 'Stop'
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$src = 'ENL-Ubuntu-Server'
$snap = 'base-for-pel'
if (-not ((& $vb snapshot $src list --machinereadable 2>$null) -match "SnapshotName.*=`"$snap`"")) {
  & $vb snapshot $src take $snap --description 'Base for the PEL monitor01 linked clone'
}
& $vb clonevm $src --snapshot $snap --options link --name monitor01 --basefolder 'E:\VMs\PEL' --register
& $vb modifyvm monitor01 --memory 2048 --cpus 2 --nic1 nat --nic2 intnet --intnet2 pel-servers --nic-promisc2 allow-all --nic3 intnet --intnet3 pel-dmz --nic-promisc3 allow-all
foreach ($r in (& $vb showvminfo monitor01 --machinereadable | Select-String '^Forwarding\(\d+\)="([^,]+),')) {
  & $vb modifyvm monitor01 --natpf1 delete $r.Matches[0].Groups[1].Value
}
& $vb modifyvm monitor01 --natpf1 "ssh,tcp,127.0.0.1,2230,,22" --natpf1 "librenms,tcp,127.0.0.1,8030,,8000"
