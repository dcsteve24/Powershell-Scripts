Param([Parameter(Position=0)][string]$timeSpan, [Parameter(Position=1)][string]$saveLocation)

Import-Module ActiveDirectory

#---------------------------------------------------------------------------------------------
#Disables users after specified time and on default domain and OU for current user. If a different
#OU or domain is desired and assuming user has permissions, add a -SearchBase "OU=XXXXX, dc=xxxx" to
#the $Users variable, inbetween Get-ADUser and -Filter. See below for exacts on OU and dc structure
#
#The SearchBase argument takes an LDAP string; every folder structure in OU needs a new OU=, every 
#period in the DC needs a new dc=. Example: A Domain Users OU nested under Users OU in the domain
#area52.afnoapps.us.af.mil would look like -SetBase "OU=Domain Users,OU=Users,dc=area52,dc=afnoapps,
#dc=us,dc=af,dc=mil"
#
#Multiple OUs or DCs can also be specified by copying the $Users variable and changing the SearchBase
#to whatever needed. Make each $Users line unique, i.e. $Users1="XXXX", and $Users2="XXXXX". Then
#combine the results with a new line that adds all users together. $AllUsers = $Users1+$Users2.
#Finally, change the "#Run Script" section from the $Users variable to $AllUsers (one in first line
#under "#Run Script", another in the foreach loop.
#
#Notes: If user running the script does not have access to required areas, the script will fail. If
#user does not run the script as an administrator, the LastLogon dates will be null because they
#can't be accessed, therefore nobody will be disabled and a blank file will be created. This script
#must be ran on PowerShell v2 or greater and must be able to load the ActiveDirectory Module (usually
#best to run on the DC)
#
#Created: Steven Craig, Harris Sub-contractor 17May18
#Edited: 25Jun18 Property used was not updated to correct dates in Windows side. Found a different
#	property to use that required conversion and edited script to work.
#--------------------------------------------------------------------------------------------
#Functions
Function DatePlease
{
    #Gives the date back in DDMMMYYYY format
    $y = ((Get-Date).year -as [string])
    $d = ((Get-Date).day -as [string])
    $mInt = ((Get-Date).Month -as [string])

    Switch ($mInt){
        1 {$mStr = "JAN"; break}
        2 {$mStr = "FEB"; break}
        3 {$mStr = "MAR"; break}
        4 {$mStr = "APR"; break}
        5 {$mStr = "MAY"; break}
        6 {$mStr = "JUN"; break}
        7 {$mStr = "JUL"; break}
        8 {$mStr = "AUG"; break}
        9 {$mStr = "SEP"; break}
        10 {$mStr = "OCT"; break}
        11 {$mStr = "NOV"; break}
        12 {$mStr = "DEC"; break}
        }

    $rValue = $d + $mStr + $y
    return $rValue
}

#Set Variables
$timeSpan = 35
$date = DatePlease
$saveLocation = (AskData $saveLocation 2)+"\DisabledUsers"+$date
$inactive = (Get-Date).AddDays(-($timeSpan))
$Users = Get-ADUser -Filter * -Properties LastLogon | Select-Object SamAccountName, Name, LastLogon, DistinguishedName, Enabled

#Disable the user and build a disabled list
ForEach ($X in $Users){
    $lastLogon = [DateTime]::FromFiletimeUTC($_.LastLogon)
    If ($lastLogon -lt $inactive -and $X.Enabled -eq $true -and $X.SamAccountName -notlike "*svc*") {
        $DistName = $X.DistinguishedName
        Disable-ADAccount -Identity $DistName
        Set-ADUser -Identity $DistName -Description "Disabled by script; Inactive for 35 days"
        $disabledList += ,$X
        }
    }
$disabledList | Select-Object @{Name="Username"; Expression={$_.SamAccountName}}, Name, Enabled | Sort-Object Name

#Build the CSV file
$disabledList | Select-Object Name, @{Name="LastLoggedIn"; Expression={[DateTime]::FromFiletimeUTC($_.LastLogon).ToString('g')}} | Sort-Object Name | Export-Csv $saveLocation
