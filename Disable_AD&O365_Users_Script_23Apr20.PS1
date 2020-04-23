[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module ActiveDirectory
Install-Module ExchangeOnlineManagement -Confirm:$false

#-------------------------------------------------------------------------------------------------------
#This script ties into O365 and local DC to look at corresponding areas for inactivity.
# If the account has a O365 email, the LastLogon exists there and we look there for those accounts
# This ensures users without laptops, which wouldnt hit the domain to hit that LastLogon and without
# would result in disable. Otherwise, the account for things without mailbox, i.e. Service or admin,
# are looked at on the domain.
#
#Disables users after specified time -- edit with the $timespan parameter
#Disables users in specified OUs -- edit with the $Users field
#
#To test the output of the script without disabling the user, add a # before the following:
# Disable-ADAccount -Identity $distName
# Set-ADUser -Identity $distName -Description $disableComment
#
#
#Notes: If user running the script does not have access to required areas, script will fail
#
#
#Created: Steven Craig, ISSO 07Oct18
#Edited: Steven Craig, ISSM 26Feb19 to point logs to new shared drive and edit date format
#        Steven Craig, Sys Adm 23Apr20 Now Looking at Azure AD for inactivity calculations due to non-laptop movement
#--------------------------------------------------------------------------------------------------------

#Functions
Function DatePlease
{
    #Gives the date back in DDMMMYYYY format
    $y = ((Get-Date).year -as [string])
    $d = ((Get-Date).day -as [string])
    $m = ((Get-Date).Month -as [string])

    $rValue = $y + "-" + $m + "-" + $d

    return $rValue
}

try {
    #Set Variables
    $login = "FILL ME IN = user"
    $pwd = "FILL ME IN = password"    
    $timeSpan = 90
    $date = DatePlease
    $shareddrive = "FILL ME IN = log destination"
    $disableComment = "Disabled by script "+$date+"; Inactive for "+$timespan+" days"
    $disabledOU = "FILL ME IN = OU to move users to (LDAP form)"
    $inactive = (Get-Date).AddDays(-($timeSpan))
    $Users1 = Get-ADUser -SearchBase "FILL ME IN = LDAP form OU" -Filter {Enabled -eq $true} -Properties LastLogon | Select-Object SamAccountName, Name, DistinguishedName, LastLogon, Enabled
    $Users2 = Get-ADUser -SearchBase "FILL ME IN = LDAP form OU" -Filter {Enabled -eq $true} -Properties LastLogon | Select-Object SamAccountName, Name, DistinguishedName, LastLogon, Enabled
    $Users3 = Get-ADUser -SearchBase "FILL ME IN = LDAP form OU" -Filter {Enabled -eq $true} -Properties LastLogon | Select-Object SamAccountName, Name, DistinguishedName, LastLogon, Enabled
    $Users4 = Get-ADUser -SearchBase "FILL ME IN = LDAP form OU" -Filter {Enabled -eq $true} -Properties LastLogon | Select-Object SamAccountName, Name, DistinguishedName, LastLogon, Enabled

    $AllUsers = $Users1 + $Users2 + $Users3 + $Users4

    #Connect to Exchange Online (this is where the LastLogon is)
    $pwd = ConvertTo-SecureString $pwd -AsPlainText -Force
    $credentials = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $login,$pwd
    Connect-ExchangeOnline -Credential $credentials -ShowProgress $true

    ForEach ($x in $AllUsers){
       #Use old way for admin accounts or accounts (they dont have a mailbox)
       If ($x.DistinguishedName -like "*Administrators*") {
           $convertedLastLogon = [DateTime]::FromFileTimeUtc($x.LastLogon) 
       }
       
       #Compare to mailbox (0365 time)
       Else {
           $convertedLastLogon = Get-EXOMailboxStatistics $x.sAMAccountName -PropertySets All | Select "LastLogonTime"
           $convertedLastLogon = $convertedLastLogon.LastLogonTime
       }
       
       If ($convertedLastLogon -lt $inactive) {
            $distName = $x.DistinguishedName
            Disable-ADAccount -Identity $distName
            Set-ADUser -Identity $distName -Description $disableComment
       	    $distName | Move-ADObject -TargetPath $disabledOU
            $disabledList += ,$x
        }
    }
    
    #Gives List of users in prompt
    $disabledList | Select-Object @{Name="Username"; Expression={$_.SamAccountName}}, Name, Enabled | Sort-Object Name
    
    #Builds the CSV file
    if ($disabledList.count -eq 0) {
        $disabledList = "No users were disabled"
        $saveLocation = $shareddrive+$date+"_NoneDisabled.csv"
        $disabledList | Export-Csv $saveLocation -NoTypeInformation
        }
    else {
        $saveLocation = $shareddrive+$date+"_DisabledList.csv"
        $disabledList | Select-Object Name, @{Name="LastLoggedIn"; Expression={[DateTime]::FromFileTimeUtc($_.LastLogon).ToString('g')}} | Sort-Object Name | Export-Csv $saveLocation -NoTypeInformation
    }
}

catch {
    #General catch so no error if no entries returned
    Write-Host -ForegroundColor Yellow `
    """The script returned an error. If the error below states 'does not contain a method named 'op_Addition', 
    there aren't any users that meet the criteria given. Other errors listed mean a different issue in the script 
    and will need to be repaired.

    Error Message: $($_.Exception.Message)"""
}

Finally {
    Disconnect-ExchangeOnline -Confirm:$false
}