# new-kali.ps1 - kali01 in the Security zone from the official Kali 2025.4 VirtualBox image.
#   NIC1  intnet pel-security  192.168.40.10/24 gw 192.168.40.1 (all testing traffic goes through the firewall)
#   NIC2  NAT, SSH from the host only (127.0.0.1:2240), no default route
param(
  [string]$SourceVdi = 'D:\ALL COURSE metarils\network secutiry\kali-linux-2025.4-virtualbox-amd64\kali-linux-2025.4-virtualbox-amd64\kali-linux-2025.4-virtualbox-amd64.vdi',
  [string]$Folder = 'E:\VMs\PEL'
)
$ErrorActionPreference = 'Stop'
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$disk = "$Folder\kali01\kali01.vdi"
if (-not (Test-Path $disk)) { New-Item -ItemType Directory -Force "$Folder\kali01" | Out-Null; & $vb clonemedium disk $SourceVdi $disk --format VDI }
& $vb createvm --name kali01 --ostype Debian_64 --basefolder $Folder --register
& $vb modifyvm kali01 --memory 2048 --cpus 2 --graphicscontroller vmsvga --vram 64 --audio-enabled off --usb off `
    --nic1 intnet --intnet1 pel-security --nic-promisc1 deny --nic2 nat
& $vb modifyvm kali01 --natpf2 "ssh,tcp,127.0.0.1,2240,,22"
& $vb storagectl kali01 --name SATA --add sata --controller IntelAhci --portcount 1
& $vb storageattach kali01 --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
