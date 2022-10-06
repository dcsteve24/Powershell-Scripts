<#
Creates the approved local account. Must be ran manuallt.

Pre-requirements:
- Must have WinRM enabled and configured (currently accomplished as a log in script for Generic User Env)

Running Script:
    Run with a Powershell (Admin) shell as <script_full_path> Arg="example" Arg="example"
        Note: if on a share thats not mapped to a letter already, use "net share <path for share>" first.

Args:
    account_name = string. The account login name/username. 
    $full_name = string. The full name/disaplay name of the account. 
    $description = string. The description displayed for the account. 
    $ip_range = string. First three octets to run through; no trailing period. 
    $administrator = boolean. Determines if the created account is an administrator or not. 

Created by: Steven Craig 26Sep2022
#>
Param(
    [parameter (Mandatory=$True)] [string]$account_name,
    [parameter (Mandatory=$True)] [string]$full_name,
    [parameter (Mandatory=$True)] [string]$description,
    [parameter (Mandatory=$True)] [string]$ip_range,
    [parameter (Mandatory=$True)] [boolean]$administrator = $True
)

# vars
#Excludes these from creating accounts on -- DC's local accounts become domain level.
$exclude_list = @("XX.XX.XX.XX", "XX.XX.XX.XX") # Fill me in with DC IPs

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

Function Create_Account {
    <#
        Creates the account on each detected WinRM enabled device in the IP range given

        Args:
            $account_credentials: System.Management.Automation.PSCredential Object. The account credentials to make the account
            $usable_ips: String array of IPs which WinRM works on
            $full_name: String. The full name/display name of the account created
            
            $administrator: Boolean. Determines if account is administrator or not. Defaults to False
            $description: String. The description of the account. Defaults to null
    #>
    Param([System.Management.Automation.PSCredential] $account_credentials,
          [array]$usable_ips,
          [string]$full_name,
          [System.Management.Automation.PSCredential] $remote_credentials,
          [boolean]$administrator=$False,
          [string]$description=$null)
    
    Foreach ($ip in $usable_ips) {
        if (!($exclude_list.Contains($ip))) {
            Invoke-Command -ComputerName $ip -Credential $remote_credentials -ScriptBlock { 
                Write-Host "Creating the account on " $using:ip
                New-LocalUser $using:account_credentials.UserName -Password $using:account_credentials.Password -FullName $using:full_name -Description $using:description
                if ($using:administrator) {
                    Add-LocalGroupMember -Group "Administrators" -Member $using:account_credentials.UserName
                    Set-LocalUser -Name $using:account_credentials.UserName -PasswordNeverExpires:$true
                }
            } 
            Write-Host "Success!"        
        }
        else {
            Write-Host $ip "is in the exclude list, skipping it"
        }
    }
}

Function Main {
    $account = Get-Credential -UserName $account_name -Message "Please provide the credentials for the user you wish to create"
    $domain_credentials = Get-Credential -Message "Please enter your domain admin credentials"
    $usable_ips = Grab-IPs $ip_range
    Create_Account $account $usable_ips $full_name $domain_credentials $administrator $description
}

Main
