# new-ubuntu-base.ps1 - unattended Ubuntu Server 22.04 install used as the base image for srv01,
# dmz-web01 and client01 (linked clones). NIC1 is NAT during the build so apt works; the clone
# scripts move it onto the lab zone afterwards.
#   powershell -File lab\vbox\new-ubuntu-base.ps1 -Iso C:\path\ubuntu-22.04.5-live-server-amd64.iso
param(
  [string]$Iso = "$env:USERPROFILE\Downloads\ubuntu-22.04.5-live-server-amd64.iso",
  [string]$Name = 'pel-base',
  [string]$Folder = 'E:\VMs\PEL',
  [int]$MemoryMB = 2048   # the live installer needs ~2 GB; clones are trimmed afterwards
)
$ErrorActionPreference = 'Stop'
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$root = Resolve-Path "$PSScriptRoot\..\.."
$sec = @{}; Get-Content "$root\.lab-local\secrets.env" | ForEach-Object { $k, $v = $_ -split '=', 2; $sec[$k] = $v }

& $vb createvm --name $Name --ostype Ubuntu22_LTS_64 --basefolder $Folder --register
& $vb modifyvm $Name --memory $MemoryMB --cpus 2 --nic1 nat --audio-enabled off --usb off --graphicscontroller vboxsvga --vram 16
& $vb modifyvm $Name --natpf1 "ssh,tcp,127.0.0.1,2231,,22"
& $vb createmedium disk --filename "$Folder\$Name\$Name.vdi" --size 20480 --format VDI --variant Standard
& $vb storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2
& $vb storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium "$Folder\$Name\$Name.vdi"
& $vb unattended install $Name --iso $Iso --user $sec.LAB_USER --password $sec.LAB_PASS --full-user-name 'Lab Admin' `
    --hostname "$Name.corp.lab" --locale en_US --time-zone Asia/Dhaka `
    --post-install-command 'apt-get install -y openssh-server && systemctl enable ssh'
& $vb startvm $Name --type headless
