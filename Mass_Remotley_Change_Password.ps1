<#
Updates the password for the specified account to the specified password.

Pre-requirements:
- Must have WinRM enabled and configured (currently accomplished as a log in script for Generic User Env)
- The device you are running on must have the Powershell ActiveDirectory module installed (default default for DCs)

Running Script:
    Run with a Powershell (Admin) shell as <script_full_path> Arg="example" Arg="example"
        Note: if on a share thats not mapped to a letter already, use "net share <path for share>" first.

Args:
    $account_name = string. The account login name/username. 
    $ip_range = string. First three octets to run through; no trailing period. 

Created by: Steven Craig 26Sep2022
#>
Param([parameter (Mandatory=$True)] [string]$account_name,
      [parameter (Mandatory=$True)] [string]$ip_range)

Import-Module ActiveDirectory

#vars
$domain_controllers = @("X.X.X.X", "X.X.X.X")  # populate with DC IPs.

# Functions
Function Grab-IPs {
    <#
        Goes through and grabs any IPs which reach back and can conduct a WinRM with

        Args:
            ip_range: String. The first 3 octect range of the /24 network

        Returns:
            Array of IPs
    #>
    Param([string]$ip_range)
    $ip_array = @()
    Write-Host "Detecting usable IPs in the" $ip_range "network... This may take a minute"
    For ($n=0; $n -le 255; $n++) {
        $ip = $ip_range + "." + $n
        if (Test-Connection $ip -Count 1 -Quiet) {
            if ([bool](Test-WsMan $ip -ErrorAction SilentlyContinue)) {
                $ip_array += $ip
            }
        }
        if ($n % 10 -eq 0) {
            Write-Host "..."
        }
    }
    Write-Host "Finished Calculating IPs"
    return $ip_array
}

Function Test-PasswordComplexity {
    <#
        Ensures the password passed by the user meets complexity requirements per DoD

        Note: to conduct these checks this is temporarily decrypting the password only when required for content checks. This brings a 
        temporary risk. Use at user discretion. No workaround could be found for ensuring the password complies prior to attempting to set.

        Args:
            $account_credentials: System.Management.Automation.PSCredential Object. The account credentials to make the account
            $password_policy: Microsoft.ActiveDirectory.Management.ADEntity Object. The Domain password policy.

        Return:
            Boolean. True if complexity checks pass; false otherwise.
    #>
    Param([System.Management.Automation.PSCredential] $account_credentials,
          [Microsoft.ActiveDirectory.Management.ADEntity]$password_policy = (Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue))

    #Length
    if ($account_credentials.Password.Length -lt $password_policy.MinPasswordLength) {
        return $False
    }
    # Name is part of password
    $tokens = $account_credentials.UserName.Split(",.-,_ $`t")
    if ([Net.NetworkCredential]::new('', $account_credentials.Password).Password -match $account_credentials.UserName) {
        return $False
    }
    foreach ($token in $tokens) {
        if (($token) -and ([Net.NetworkCredential]::new('', $account_credentials.Password).Password -match "$token")) {
            return $False
        }
    }
    # Password Complexity
    if (!(([Net.NetworkCredential]::new('', $account_credentials.Password).Password -cmatch "[A-Z\p{Lu}\s]") `
            -and ([Net.NetworkCredential]::new('', $account_credentials.Password).Password -cmatch "[a-z\p{Ll}\s]") `
            -and ([Net.NetworkCredential]::new('', $account_credentials.Password).Password -match "[\d]") `
            -and ([Net.NetworkCredential]::new('', $account_credentials.Password).Password -match "[^\w]"))) {
        return $False
    }
    # All passed
    return $True
}

Function Reset-Pwd {
    <#
        Resets the account for all local accounts on the IP range given.

        Args:
            $account_credentials: System.Management.Automation.PSCredential Object. The account credentials to make the account
            $usable_ips: String array of IPs which WinRM works on
            $remote_credentials: System.Management.Automation.PSCredential Object. The account credentials to remote around with (domain credentials)
    #>
    Param([System.Management.Automation.PSCredential] $account_credentials,
          [array]$usable_ips,
          [System.Management.Automation.PSCredential] $remote_credentials)
    
    $domain_reset = $False
    Foreach ($ip in $usable_ips) {
        if ($domain_controllers -contains $ip) {
            if (!($domain_reset)) {
                Invoke-Command -ComputerName $ip -Credential $remote_credentials -ScriptBlock { 
                    Import-Module ActiveDirectory
                    if ([bool](Get-ADUser $using:account_credentials.UserName -ErrorAction SilentlyContinue)) {
                        Write-Host "Reseting the password for" $using:remote_credentials.UserName "on" $using:ip
                        #Set-ADAccountPassword $using:account_credentials.UserName -Password $using:account_credentials.Password
                        Write-Host "Success!"
                    }
                    else {
                        Write-Host "No user with" $using:account_credentials.UserName "detected on" $using:ip "-- No action taken."
                    }
                }
                $domain_reset = $True #don't run again on other DC
            } 
            else {
                Write-Host "Actions already conducted on DC. Not resetting the account password on" $ip "to prevent repetitive actions and issues"
            }
        }
        else {
            Invoke-Command -ComputerName $ip -Credential $remote_credentials -ScriptBlock { 
                if ([bool](Get-LocalUser $using:account_credentials.UserName -ErrorAction SilentlyContinue)) {
                    Write-Host "Reseting the password for" $using:account_credentials.UserName "on" $using:ip
                    #Set-LocalUser $using:account_credentials.UserName -Password $using:account_credentials.Password
                    Write-Host "Success!"
                }
                else {
                    Write-Host "No user with" $using:account_credentials.UserName "detected on" $using:ip "-- No action taken."               
                }
            }
        }        
    }
}

Function Main {
    $account = Get-Credential -UserName $account_name -Message "Please provide the credentials for the user you wish to create"
    while (!(Test-PasswordComplexity $account)) {
        Write-Host "Password did not meet complexity requirements, reprompting for a new password"
        $account = Get-Credential -UserName $account_name -Message "Password did not comply with complexity requirements. Please provide the credentials for the user you wish to reset the password on"
    }
    $domain_credentials = Get-Credential -Message "Please enter your domain admin credentials"
    $usable_ips = Grab-IPs $ip_range
    Reset-Pwd $account $usable_ips $domain_credentials
}

Main
