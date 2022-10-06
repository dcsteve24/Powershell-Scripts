<#
Disabled NetBIOS on all interfaces cause Windows has no GPO option for this for some reason...

Created by: Steven Craig 25Aug2022
#>

# vars
$regkey = "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces"
$NetBiosOptions = 2  #Disable
#$NetBiosOptions = 0  #Enable

#Disable
Get-ChildItem $regkey | foreach { Set-ItemProperty -Path "$regkey\$($_.pschildname)" -Name NetbiosOptions -Value $NetBiosOptions -Verbose}
