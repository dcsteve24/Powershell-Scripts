
#===========================================================================================================================
#The admin script is degined to provide a series of menus that give admins control from a single workstation.
#The admin can run this script to create the same account on all the required machines, reset passwords, or even
#unlock accounts all from a single workstation despite being a peer-to-peer network.
#
#This script should work on Windows PowerShell v2.0+
#This was designed for a closed env without certs/domain. If you have that, this can become signifigantly more secure and
#easier to implement.
#
#This one is really hard to generalize so it will require lots of edits for you. I could pobably work to generalize it way
#  more but time == money and this is more for me.
#
#--------------------------------------------------------------------------------------------------------------------------
#
#Requirements (on each machine):
# - Able to run scripts on the machines (proper Set-ExecutionPolicy)
# - Set Newtowk Connection to Private (next commands will error if not)
# - Enable WinRM w/ Powershell Remoting
#   - WinRM quickconfig   #then answer the prompts with your information
#   - Enable-PSRemoting
# - Firewall Port 5985 allowed
# - In Powershell: Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{TrustedHosts=YOUR_IP,YOUR_IP,YOUR_IP}
# - Sript must be ran as Administrator
#
#-----------------------------------------------------------------------------------------------------------------------------
#
#Edit the script for your env:
# 1. Under Function "WHERETORUN" change HOSTNAME to your hostnames (remove or add to menu and checks as needed)
# 2. Under Function "WHERETORUN" change the YOUR_IPs to your IPs (remove or add to the switch statement as needed)
# 3. Under Function "EXISTINGRIGHTSREQUIRED" and "NEWRIGHTSREQUIRED" change YOUR_GROUP_NAME_DESCRIPTION to the group names you need to
#     assign. For example, an Administrator with Burn Rights. (remove or add to menu and checks as needed)
# 4. Edit Switch 1 of Main Code "New User Creation" line $newUser.SetPassword("YOUR_TEMP_PASSWORD") to be a temporary passwords
#     for your systems that is assigned to the new user.
# 5. Edit Switch 1 section "switch ($Rrights) {"; edit all the switches to reflect the correct permissions for your systems based on
#     the groupings you set in the YOUR_GROUP_NAME_DESCRIPTION. For example, if you had a "Admin with Burn rights" selection, you
#     probably need to add an Administrators, Users, and Burn_Users (or whatever you call the group) group. Remove any extra lines
#     as needed.
# 6. Same thing as step 5 for switch statement 4 & 5 "Remove/Add Permissions". Edit YOUR_GROUP_NAME_DESCRIPTION and add/remove as needed.
# 7. Same thing as step 4 for switch statement 6 "Reset Password"; set the "YOUR_TEMP_PASSWORD" to a temp password for your org.

#Created: Steven Craig, 21May18
#Edited: Generalized for Github -- 29Mar19, Steven Craig
#==============================================================================================================================

#----------------------------------------------Functions-------------------------------
Function AskInput
{
    #Asks a message and returns the input

    Param([string]$mesg)

    Clear
    do { $x = Read-Host $mesg }
    while ($x -eq [string]::Empty)

    return $x
} #End Function AskInput

Function AskYorN
{
    #returns true or false based on the question
    Param([string]$mesg)

    Clear
    do { $x = Read-Host $mesg }
    while (!(($x -match "y") -OR ($x -match "yes") -OR ($x -match "n") -OR ($x -match "no")))
    switch ($x) {
        "y" {$r = $True; break}
        "yes" {$r = $True; break}
        "n" {$r = $False; break}
        "no" {$r = $False; break}
        }

    return $r
} #End Function AskYorN

Function CleanUp
{
    Foreach ($x in (Get-PSSession | where { $_.State -eq "Opened" })) { Disconnect-PSSession -Id $x.Id | Out-Null}
    Foreach ($x in (Get-PSSession)) { Remove-PSSession -Id $x.Id | Out-Null }
    Write-Host -ForegroundColor Green "Successfully disconnected from host(s)"
} #End CleanUp Function

Function Credentials
{
    #Prompts for credentials with a message

    Param([string] $comp, $aName)

    $x = Get-Credential ($comp+"\"+$aName) -Message "Enter $comp Credentials"

    return $x
} #End Function Credentials

Function ExistingRightsRequired
{
    Clear
    Write-Host "What rights would you like to assign or remove on the user:"
    Write-Host "------------------------------------------------------"
    Write-Host "1: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "2: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "3: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "999: Exit/Cancel"
    Write-Host "------------------------------------------------------"
    Write-Host ""

    do { $x = Read-Host }
    while ($x -notlike "1" -and $x -notlike "2" -and $x -notlike "3" -and $x -notlike "999")

    return $x
} #End Function ExistingRightsRequired

Function NewRightsRequired
{
    Clear
    Write-Host "What rights would you like to assign the user:"
    Write-Host "------------------------------------------------------"
    Write-Host "1: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "2: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "3: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "4: YOUR_GROUP_NAME_DESCRIPTION"
    Write-Host "------------------------------------------------------"
    Write-Host ""

    do { $x = Read-Host }
    while ($x -notlike "1" -and $x -notlike "2" -and $x -notlike "3" -and $x -notlike "4")

    return $x
} #End Function NewRightsRequired

Function Welcome
{
    #The welcome menu to decide what admin functions to acomplish
    Write-Host ""
    Write-Host "Please tell me what actions you wish to take:"
    Write-Host "-----------------------------------------------"
    Write-Host "1: Create User Accounts"
    Write-Host "2: Disable User Accounts"
    Write-Host "3: Enable and Unlock User Accounts"
    Write-Host "4: Add Permissions"
    Write-Host "5: Remove Permisions"
    Write-Host "6: Reset Passwords"
    Write-Host "7: Delete User Accounts"
    Write-Host "999: Exit/Cancel"
    Write-Host "------------------------------------------------------"
    Write-Host ""

    do { $x = Read-Host }
    while ($x -notlike "1" -and $x -notlike "2" -and $x -notlike "3" -and $x -notlike "4" -and $x -notlike "5" -and $x -notlike "6" -and
           $x -notlike "7" -and $x -notlike "999")

    return $x
} #End Function Welcome

Function WhereToRun
{
    #Returns an hostname and IP based on users input of location to run

    Write-Host ""
    Write-Host "Please tell me which computer you wish to run this on:"
    Write-Host "------------------------------------------------------"
    Write-Host "1: HOSTNAME"
    Write-Host "2: HOSTNAME"
    Write-Host "3: HOSTNAME"
    Write-Host "4: HOSTNAME"
    Write-Host "5: HOSTNAME"
    Write-Host "6: HOSTNAME"
    Write-Host "7: HOSTNAME"
    Write-Host "8: HOSTNAME"
    Write-Host "9: HOSTNAME"
    Write-Host "999: Exit/Cancel"
    Write-Host "------------------------------------------------------"
    Write-Host ""

    $x = Read-Host
    while ($x -notlike "1" -and $x -notlike "2" -and $x -notlike "3" -and $x -notlike "4" -and $x -notlike "5" -and $x -notlike "6" -and
           $x -notlike "7" -and $x -notlike "8" -and $x -notlike "9" -and $x -notlike "999") {
           Write-Host "Bad input, entry must be a number from the menu above"
           $x = Read-Host
           } #End While

    Switch ($x) {
        1 { $y = "YOUR_IPs"; break }
        2 { $y = "YOUR_IPs"; break }
        3 { $y = "YOUR_IPs"; break }
        4 { $y = "YOUR_IPs"; break }
        5 { $y = "YOUR_IPs"; break }
        6 { $y = "YOUR_IPs"; break }
        7 { $y = "YOUR_IPs"; break }
        8 { $y = "YOUR_IPs"; break }
        9 { $y = "YOUR_IPs"; break }
        999 {$y = "end"; break}
        } #End Switch

    return $y
} #End Function WhereToRun


#----------------------------------------------Script-----------------------------------
Clear
Write-Host "Welcome to the Administrator Script."
Write-Host "Created by Steven Craig, 01Aug18"

$welcome = Welcome
If ($welcome -ne "999") { $adminName = AskInput "What is your administrator username" }

While ($welcome -ne "999") {
    Switch ($welcome) {
        1 { #-----CREATE A USER------
            $IP = WhereToRun
            $fullName = (AskInput "What is the user's first name (first)") + " " + (AskInput "What is the user's last name (last)")
            $userName = AskInput "What is the desired username for the new user"
            $descrip = AskInput "What is the job title of the user"
            $disable = AskYorN "Do you need the accounts disabled after creation? Accounts must be disabled if passwords cannot be reset today"
            $rights = NewRightsRequired

            #Code
            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds
                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername,$RfullName,$Rdisable,$Rdescrip,$Rrights)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }
                    if ($user -eq $null) {
                        $newUser = $ADSI.Create("User",$RuserName)
                        $newUser.SetPassword("YOUR_TEMP_PASSWORD")
                        $newUser.SetInfo()
                        if ($Rdisable -eq $True) { $newUser.userflags = 2 }
                        $newUser.FullName = $RfullName
                        $newUser.Description = $Rdescrip
	                      $newUser.put("PasswordExpired",1)
                        $newUser.SetInfo()
                        switch ($Rrights) {
                                1 { #Administrator;
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                2 { #Administrator w/ Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user") ;
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                3 { #Generic User
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                4 { #Generic User w/ Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break}
                            }; #End Switch
                        } #End If
                    else { Write-Error "User $Rusername already exists"; return }

                    #tests for creation and gives feedback
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }
                    if ($user -eq $null) { Write-Error "The user was not succesffully created"; return }
                    else { Write-Host -ForegroundColor Green "The user was successfully created" }
                    } -ArgumentList $userName,$fullName,$disable,$descrip,$rights    #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUp
            break } # End Switch 1 (Create User)

        2 { #--------DISABLE THE ACCOUNT---------
            $IP = WhereToRun
            $userName = AskInput "What is the username you wish to disable"

            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds

                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                    if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                    else { $user.userflags = 2; $user.SetInfo(); Write-Host -Foreground Green "The user was successfully disabled"}
                    } -ArgumentList $userName     #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUp
            break } #End Switch 2 (Disable User)

        3 { #---------ENABLE AND UNLOCK THE ACCOUNT----------
            $IP = WhereToRun
            $userName = AskInput "What is the username you wish to enable"

            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds

                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                    if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                    if ($user.IsAccountLocked -eq $False) { Write-Host -ForegroundColor Green "The user was already unlocked... no action taken" }
                    if ($user.IsAccountLocked -eq $True) { $user.IsAccountLocked = $False; Write-Host -ForegroundColor Green "The user was locked out. Account is now unlocked" }
                    $user.userflags = 1
                    $user.SetInfo()
                    Write-Host -Foreground Green "Account is set to enabled."
                    } -ArgumentList $userName     #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUp
            break } #End Switch 3 (Enable User)

        4 {#---------ADD PERMISSIONS-----------
            $IP = WhereToRun
            $userName = AskInput "What is the username you wish to add permissions on"
            $rights = ExistingRightsRequired

            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds

                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername, $Rrights)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                    if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                    else {
                        switch ($Rrights) {
                                1 { #Administrator
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                2 { #Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                3 { #Administrator and Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Add("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }
                                } #End Switch
                            } #End Else
                    } -ArgumentList $userName,$rights     #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUP
            break } #End Switch 4 (Add Permisions)

        5 { #---------REMOVE PERMISSIONS-----------
            $IP = WhereToRun
            $userName = AskInput "What is the username you wish to remove permissions from"
            $rights = ExistingRightsRequired

            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds

                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername, $Rrights)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                    if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                    else {
                        switch ($Rrights) {
                                1 { #Administrator
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Remove("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                2 { #Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Remove("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }

                                3 { #Administrator and Burn Rights
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Remove("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/GROUP_NAME,group"; $group.Remove("WinNT://$env:COMPUTERNAME/$RuserName,user");
                                    break }
                                } #End Switch
                            } #End Else
                    } -ArgumentList $userName,$rights     #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUP
            break } #End Switch 5 (Remove Permissions)

        6 { #---------RESET PASSWORD-----------
            $answer = AskYorN "Do not run a password reset on the user unless they are going to immediatley reset it. If the user present to reset the password?"
            If ($answer) {
                $IP = WhereToRun
                $userName = AskInput "What is the username you wish to reset to a default password"

                While ($IP -ne "end") {
                    $creds = Credentials $IP $adminName
                    $sess = New-PSSession -ComputerName $IP -Credential $creds

                    invoke-command -Session $sess -ScriptBlock {
                        param($Rusername)
                        $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                        $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                        if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                        else { $user.SetPassword("YOUR_TEMP_PASSWORD") ; $user.put("PasswordExpired",1); $user.SetInfo(); Write-Host -Foreground Green "The password was successfully defaulted. Please have the user login to reset it now."}
                        } -ArgumentList $userName     #End scriptblock
                    $IP = WhereToRun
                    } #End While
                CleanUp
                } #End If
            else { Write-Host -Foreground Red "Pleae wait until the user is available to reset their password" }
            break } #End Switch 6 (Password Reset)

        7 { #---------DELETE USER-----------;
            $IP = WhereToRun
            $userName = AskInput "What is the username you wish to delete"

            While ($IP -ne "end") {
                $creds = Credentials $IP $adminName
                $sess = New-PSSession -ComputerName $IP -Credential $creds

                invoke-command -Session $sess -ScriptBlock {
                    param($Rusername)
                    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
                    $user = $ADSI.Children | where { $_.SchemaClassName -eq 'user' -and $_.Name -eq $Rusername }

                    if ($user -eq $null) { Write-Error "User $Rusername does not exist"; return } #End If
                    else { $ADSI.Delete("User",$Rusername); Write-Host -Foreground Green "The user was successfully deleted"}
                    } -ArgumentList $userName     #End scriptblock
                $IP = WhereToRun
                } #End While
            CleanUp
            break } #End Switch 7 (Delete User)
        } #End Switch
        $welcome = Welcome
    } #End While
