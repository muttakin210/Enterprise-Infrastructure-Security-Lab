# new-fw01.ps1 - pfSense CE 2.7.2 firewall with one interface per zone.
#   em0 WAN        NAT (VirtualBox), host management forwards 127.0.0.1:2250->22, :8443->443
#   em1 MGMT       intnet pel-mgmt      192.168.10.1/24
#   em2 SERVERS    intnet pel-servers   192.168.20.1/24
#   em3 USERS      intnet pel-users     192.168.30.1/24 (DHCP .100-.199)
#   em4 SECURITY   intnet pel-security  192.168.40.1/24
#   em5 DMZ        intnet pel-dmz       192.168.50.1/24
param([string]$Iso = 'E:\VMs\PEL\iso\pfSense-CE-2.7.2-RELEASE-amd64.iso', [string]$Folder = 'E:\VMs\PEL')
$ErrorActionPreference = 'Stop'
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
& $vb createvm --name fw01 --ostype FreeBSD_64 --basefolder $Folder --register
& $vb modifyvm fw01 --memory 1024 --cpus 2 --audio-enabled off --usb off --graphicscontroller vboxvga --vram 16 `
    --nic1 nat --nic2 intnet --intnet2 pel-mgmt --nic3 intnet --intnet3 pel-servers `
    --nic4 intnet --intnet4 pel-users --nic5 intnet --intnet5 pel-security --nic6 intnet --intnet6 pel-dmz `
    --nictype1 82540EM --nictype2 82540EM --nictype3 82540EM --nictype4 82540EM --nictype5 82540EM --nictype6 82540EM
& $vb modifyvm fw01 --natpf1 "ssh,tcp,127.0.0.1,2250,,22" --natpf1 "https,tcp,127.0.0.1,8443,,443"
# VirtualBox 7 blocks NAT guests from the host loopback by default; the bootstrap fetches its config from the host
& $vb modifyvm fw01 --nat-localhostreachable1 on
& $vb createmedium disk --filename "$Folder\fw01\fw01.vdi" --size 8192 --format VDI
& $vb storagectl fw01 --name SATA --add sata --controller IntelAhci --portcount 2
& $vb storageattach fw01 --storagectl SATA --port 0 --device 0 --type hdd --medium "$Folder\fw01\fw01.vdi"
& $vb storageattach fw01 --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
& $vb modifyvm fw01 --boot1 disk --boot2 dvd
