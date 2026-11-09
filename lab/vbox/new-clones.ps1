# new-clones.ps1 - linked clones of pel-base for the zone hosts.
#   build phase: NIC1 = NAT with an SSH forward so packages can be installed
#   -Finalize:   NIC1 moves onto the zone's internal network (no NAT, no host access except via fw01)
param([switch]$Finalize)
$ErrorActionPreference = 'Stop'
$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$hosts = @(
  @{ Name = 'srv01';     Mem = 1024; Port = 2232; Net = 'pel-servers' },
  @{ Name = 'dmz-web01'; Mem = 768;  Port = 2233; Net = 'pel-dmz' },
  @{ Name = 'client01';  Mem = 768;  Port = 2234; Net = 'pel-users' }
)
if (-not $Finalize) {
  if (-not ((& $vb snapshot pel-base list --machinereadable 2>$null) -match 'SnapshotName.*="installed"')) {
    & $vb snapshot pel-base take installed --description 'Ubuntu 22.04 base, bootstrapped (lab key, sudo)'
  }
  foreach ($h in $hosts) {
    & $vb clonevm pel-base --snapshot installed --options link --name $h.Name --basefolder 'E:\VMs\PEL' --register
    & $vb modifyvm $h.Name --memory $h.Mem --cpus 1 --nic1 nat
    & $vb modifyvm $h.Name --natpf1 delete ssh
    & $vb modifyvm $h.Name --natpf1 "ssh,tcp,127.0.0.1,$($h.Port),,22"
  }
} else {
  foreach ($h in $hosts) {
    & $vb modifyvm $h.Name --natpf1 delete ssh 2>$null
    & $vb modifyvm $h.Name --nic1 intnet --intnet1 $h.Net
  }
}
