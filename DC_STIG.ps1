<# 
This is a account STIG script to automatically set account requirements per STIG recommended settings.
Fully Dynamic and not tied to a environment.

This only accounts for the following STIG requirements (you still need to manually check the others):

Active Directory Domain STIG:
    - V-243470
    - V-243477
    - V-243478

Windows Server 2019 STIG
    - V-205707

Additionally it does some maintnenance and assurance tasks to help prevent issues.
- Ensures All Domain Admins are also directly Enterprise Admins to allow Splunk LDAP to pull them
- Creates DNS PTR records for all A Records since this doesnt automatically happen

Created by: Steven Craig 12Jul2022
v1.0.1. - 30Jul2022 //SAC
v1.0.2. - 01Aug2022 //SAC
#>

# == Variables ==
$dns_zone = $env:USERDNSDOMAIN
$dns_server = $env:COMPUTERNAME
$reverse_zone = "" #Fill me in e.g. 17.172.in-addr.arpa
$devnet_ip_test = "" #Fill me in. Just a IP to ping for when not to set the Protected Users (blocks access from VPN)
$disabled_ou = "" #Fill me in. Where to put disabled accounts -- LDAP structure e.g. OU=blah,DC=blah

# == Functions ==
Function Print-Delimiter { Write-Output "`n====================================================`n" }

# Active Directory Domain STIGs
Function Set-DoNotDelegateFlag {
    <#
        V-243470 - Delegation of privileged accounts must be prohibited 
    #>
    Print-Delimiter
    Write-Output "V-243470 - Delegation of privileged accounts must be prohibited`n"
    $domain_admins = @(Get-ADGroupMember "Domain Admins" | Where-Object {$_.objectClass -eq "user"})
    $administrators = @(Get-ADGroupMember "Administrators" | Where-Object {$_.objectClass -eq "user"})
    $enterprise_admins = @(Get-ADGroupMember "Enterprise Admins" | Where-Object {$_.objectClass -eq "user"})
    $combined_list = @($domain_admins + $administrators + $enterprise_admins | Select-Object -Unique)
    if ($combined_list.length -eq 0) { Write-Output "No Admin users found"; return }
    foreach ($user in $combined_list) { 
        $user_name = $user.SamAccountName
        Write-Output "Marking $user_name with the 'Do Not Delegate' flag"
        Set-ADUser $user_name -AccountNotDelegated $true 
    }
}

Function Set-ProtectedUsersMembers {
    <#
        V-243477 - User accounts with domain level administrative privileges must be
        members of the Protected Users group in domains with a functional level of
        Windows 2012 R2 or higher

        Note: This intentionaly leaves emergency accounts alone
        Note: This has been found to break RDP if the source device is not domain joined. You get a "user
            account restriction" error. If you need this, simply remove the user from Protected Users group
    #>
    Print-Delimiter
    Write-Output "V-243477 - User accounts with domain level administrative privileges must be members of"
    Write-Output "the Protected Users group in domains with a functional level of Windows 2012 R2 or higher`n"
    $domain_admins = @(Get-ADGroupMember "Domain Admins" | Where-Object {$_.objectClass -eq "user"})
    $administrators = @(Get-ADGroupMember "Administrators" | Where-Object {$_.objectClass -eq "user"})
    $enterprise_admins = @(Get-ADGroupMember "Enterprise Admins" | Where-Object {$_.objectClass -eq "user"})
    $schema_admins = @(Get-ADGroupMember "Schema Admins" | Where-Object {$_.objectClass -eq "user"})    
    $account_operators = @(Get-ADGroupMember "Account Operators" | Where-Object {$_.objectClass -eq "user"})
    $backup_operators = @(Get-ADGroupMember "Backup Operators" | Where-Object {$_.objectClass -eq "user"})      
    $combined_list = @($domain_admins + $administrators + $enterprise_admins + $schema_admins + $account_operators + $backup_operators)
    $combined_list = @($combined_list | Select-Object -Unique | Where-Object {$_.SamAccountName -notlike "*emergency*"})
    if ($combined_list.length -eq 0) { Write-Output "No Admin users found"; return }
    if (Test-Connection $devnet_ip_test -Quiet) {
        Write-Output "DevNet detected. Not adding users to Protected Users to prevent issues with VPN access"
    }
    else {
        foreach ($user in $combined_list) { 
            $user_name = $user.SamAccountName
            # Don't run on DevNet -- breaks ability to access
            Write-Output "Adding $user_name to Protected Users"
            Add-ADGroupMember -Identity "Protected Users" -Members $user_name
        }
    }
}

Function Set-NoComputerDelegation {
    <#
        V-243478 - Domain-joined systems (excluding domain controllers) must not be configured for unconstrained delagation
    #>
    Print-Delimiter
    Write-Output "V-243478 - Domain-joined systems (excluding domain controllers) must not be configured for unconstrained delagation`n"
    $bad_computers = @(Get-ADComputer -Filter {(TrustedForDelegation -eq $True) -and (PrimaryGroupID -eq 515)}) #515 = Domain Computers
    if ($bad_computers.length -eq 0) { Write-Output "No computers configured incorrectly"; return }
    foreach ($computer in $bad_computers) { 
        $computer_name = $computer.Name
        Write-Output "Unmarking $computer_name to not allow delegation"
        Set-ADComputer $computer_name -TrustedForDelegation $false 
    }
}

# Windows Server 2019 STIG
Function Disable-InactiveAccounts {
    <#
        V-205707 - Outdated or Unused accounts must be removed or disabled.

        Note: This excludes the Group Acounts OU and Service Accounts OU.
    #>
    Print-Delimiter
    Write-Output "V-205707 - Outdated or Unused accounts must be removed or disabled.`n"
    $inactive_accounts = @(Search-ADAccount -AccountInactive -UsersOnly -TimeSpan 35.00:00:00)
    $inactive_accounts = @($inactive_accounts | Where-Object {($_.Enabled -eq $true) -and ($_.DistinguishedName -inotlike "*Service*") -and ($_.DistinguishedName -inotlike "*Group*")})
    if ($inactive_accounts.length -eq 0) { Write-Output "No inactive users detected"; return }
    foreach ($user in $inactive_accounts) {
        $user_name = $user.SamAccountName
        $date = Get-Date
        $comment = "Disabled by Script on $date"
        $last_logon = $user.LastLogonDate
        if ($last_logon -eq $null) { Write-Output "$user_name was created but has not been used yet. If you keep seeing this message manually disable the user" }
        else {       
            Write-Output "Disabling $user_name for inactivity for 35+ days; they last logged on at $last_logon"
            Set-ADUser $user_name -Enabled $False -Description $comment
            Get-ADUser $user_name Move-ADObject $user_name 
        }
    }
}


# Local Tasks
Function Set-AdminsMemberOfEnterpriseAdmins {
    <#
        Current version of Splunk will not sync the account through LDAP if the Administrator is not
        directly part of the Enterprise Admins. Unsure if this is STIG tied or a bug. This ensures all
        admins are part of the group
    #>
    Print-Delimiter
    Write-Output "Users must be direct members of Enterprise Admins or Splunk will not sync their account`n"
    $domain_admins = @(Get-ADGroupMember "Domain Admins" | Where-Object {$_.objectClass -eq "user"})
    if ($domain_admins.length -eq 0) { Write-Output "No Admin users found"; return }
    foreach ($user in $domain_admins) { 
        $user_name = $user.SamAccountName
        Write-Output "Adding $user_name to Enterprise Admins"
        Add-ADGroupMember -Identity "Enterprise Admins" -Members $user.SamAccountName 
    }
}

Function Create-PtrRecords {
    <#
        Deletes all current PTR records and then creates new PTR records from existing A records.
    #>
    Print-Delimiter
    Write-Output "PTR records should be made when an A record is created; this ensures PTR records exist for all current A records`n"
    $a_records = Get-DnsServerResourceRecord -ZoneName $dns_zone -RRType A -ComputerName $dns_server
    $ptr_records = Get-DnsServerResourceRecord -ZoneName $reverse_zone -RRType Ptr -ComputerName $dns_server
    Write-Output "Deleting current PTR records, please wait..."
    foreach ($record in $ptr_records) {
        try {
            $ptr_name = $record.HostName
            Remove-DnsServerResourceRecord -ZoneName $reverse_zone -Name $ptr_name -RRType Ptr -force
        }
        # Catch DC errors so it doesnt write to screen
        catch {}
    }
    foreach ($record in $a_records) {
        $ptr_domain_name = $record.HostName + '.' + $dns_zone
        $ip_oct4 = $record.RecordData.IPv4Address.ToString() -replace '^(\d+)\.(\d+)\.(\d+).(\d+)$','$3.$4'
        $reverse_zone_name = ($record.RecordData.IPv4Address.ToString() -replace '^(\d+)\.(\d+)\.(\d+).(\d+)$','$2.$1') + '.in-addr.arpa'
        try {
            Write-Output "Attempting to create a PTR Record for $ptr_domain_name"
            Add-DnsServerResourceRecordPtr -Name $ip_oct4 -ZoneName $reverse_zone_name -ComputerName $dns_server -PtrDomainName $ptr_domain_name
            Write-Output "Success"
        }
        catch { Write-Output "Record already exists" }
    }
}

# == Main ==
# Active Directory Domain STIGs
Set-DoNotDelegateFlag
Set-ProtectedUsersMembers
Set-NoComputerDelegation

# Windows Server 2019 STIG
Disable-InactiveAccounts

# Local Tasks
Set-AdminsMemberOfEnterpriseAdmins
Create-PtrRecords
