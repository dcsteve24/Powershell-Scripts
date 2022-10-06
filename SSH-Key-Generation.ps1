<#
Creates the SSH Keys on every device for PowerChute shutdown capes and enables the passwordless entry for the account.

Must be ran from the same account you wish to create keys for and must pass in the $account argument with the account specified.

Pre-requirements:
- Must have WinRM enabled and configured on Windows devices (currently accomplished as a log in script for Generic User Env)
- Putty Installed and files exist at $putty_path -- specifically looking for plink.exe
- All target devices must be domain joined for this to work (including Linux) -- errors will not stop the script but the errored device will not function as expected.
- Local Security Policy must allow the desired account to "Allow log on locally" and "Allow log on through Remote Desktop Services"
- Must have Read/Write permissions to the $key_path
- Dont have OpenSSH shell pointed to powershell (registry edit)!!! The > redirect for file writing is a alia to Write-Output and adds linebreaks in the key which makes them not work.

Args:
    $account: String. The account to make SSH keys for. 
    $domain: String. The domain used in this environment. 
    $ip_range: String. The IP Range for this environment. 
    $putty_path: String. The path to PuTTy folder. Defaults to C:\Program Files\PuTTy
    $overwrite: Boolean. Overwrite an existing key or not.

Created by: Steven Craig 26Sep2022
#>
Param([parameter(mandatory=$true)][string]$account,
      [parameter(mandatory=$true)][string]$domain,
      [parameter(mandatory=$true)][string]$ip_range,
      [parameter(mandatory=$true)][string]$putty_path="C:\Program Files\PuTTy",
	  [parameter(mandatory=$true)][boolean]$overwrite=$False)

#Vars
$win_ssh_folder="$env:USERPROFILE\.ssh"
$linux_ssh_folder="~/.ssh"

#Functions
Function Accept-PlinkFingerprints {
    <#
        Windows used WinRM. Now that things are working we need to accept the fingerprints with
        SSH to allow commands to proceed with the assumption they wont prompt. This rotates through
        the passed range and does a simple command to accept them.

        Args:
            $account credentials: System.Management.Automation.PSCredential object. The account credentials to remote with 
            $ip: String. The full IP of the host to accept the fingerprint on
            $putty_path: string. The absolute path to the Putty directory. No trailing "\". Defautls to $putty_path global.
    #>
    Param([System.Management.Automation.PSCredential]$account_credentials, 
          [string]$ip,
          [string]$putty_path=$putty_path)    

	$plink_path = $putty_path + "\plink.exe"
    $username = $account_credentials.Username
    $command = 'echo "Accepted the fingerprint..."'
    Write-Host "Accepting the host fingerprints at" $ip
	$pwd = [Net.NetworkCredential]::new('', $account_credentials.Password).Password
	(echo y | & $plink_path -pw $pwd $username@$ip $command) >$null 2>&1
	Clear-Variable pwd
}


Function Accept-SSHFingerprints{
    <#
        Windows used WinRM. Now that things are working we need to accept the fingerprints with
        SSH to allow commands to proceed with the assumption they wont prompt. This rotates through
        the passed range and does a simple command to accept them.

        This one requires the key to be in place already for passwordless entry.

        Args:
            $account credentials: System.Management.Automation.PSCredential object. The account credentials to remote with 
            $ip: String. The full IP of the host to accept the fingerprint on
    #>
    Param([System.Management.Automation.PSCredential]$account_credentials, 
          [string]$ip)    

    $username = $account_credentials.Username
    Write-Host "NOTE: If I hang at this point something didn't work right in key generation and copying!"
    Write-Host "Accepting the host fingerprints under PowerShell and testing passwordless entry for " $ip
    ssh -o "StrictHostKeyChecking no" $username@$ip "exit"
}

Function Copy-SshId {
    <#
        Powershell SSH doesn't have the copy-ssh-id command. This function recreates that functionality
        for use in PowerShell.

        Args:
            $account credentials: System.Management.Automation.PSCredential object. The account credentials to remote with 
            $ip: String. The full IP of the host to accept the fingerprint on
            $winrm_range: array. The IPs for windows.
            $ssh_folder: string. The absolute path to store the made keys in. No trailing "\".
            $putty_path: string. The absolute path to the Putty directory. No trailing "\". Defautls to $putty_path global.
    #>
    Param([System.Management.Automation.PSCredential]$account_credentials, 
          [string]$ip,
          [array]$winrm_range,
          [string]$ssh_folder,
          [string]$putty_path=$putty_path)

    $id_rsa_pub = ($ssh_folder + "\id_rsa.pub")
    $plink_path = $putty_path + "\plink.exe"
    $username = $account_credentials.Username
    $pub_key = Get-Content -Path $id_rsa_pub
    Accept-PlinkFingerprints $account_credentials $ip $putty_path
    if ($winrm_range -contains $ip) {
        $command = ('echo "'+$pub_key+'" > '+$ssh_folder+'\authorized_keys')
    }
    else {
        $command = ('echo "'+$pub_key+'" > '+$ssh_folder+'/authorized_keys')
    }
    Write-Host "Running ssh-copy-id on" $ip "(Copying public key to" $ssh_folder ")"
    $pwd = [Net.NetworkCredential]::new('', $account_credentials.Password).Password
    (& $plink_path -pw $pwd $username@$ip $command) >$null 2>&1
    Clear-Variable pwd
}

Function Generate-LinuxSshKeys {
    <#
        **For windows**
        Generates the private and public SSH keys for passwordless use with the passed account
        Keys are generated in a invoke-command session to allow different credential use.

        Doing this ensures the creation of the required folders for the authorized key to be placed.

        Note: this does not overwrite an existing key by default

        Args:
            $account_credentials: System.Management.Automation.PSCredential Object. The account credentials to use and create keys unders
            $ip: string. The full ip address of host to run on
            $ssh_folder: string. The absolute path to store the made keys in. No trailing "\". Defaults to $ssh_folder global.
            $putty_path: string. The absolute path to the Putty directory. No trailing "\". Defautls to $putty_path global.
            $overwrite: boolean. Overwrites and existing key or not. Defautls to false
    #>
    Param([System.Management.Automation.PSCredential]$account_credentials, 
          [string]$ip,
          [string]$ssh_folder=$linux_ssh_folder,
          [string]$putty_path=$putty_path,
          [boolean]$overwrite=$False)
    $id_rsa = ($ssh_folder + "/id_rsa")
    $plink_path = $putty_path + "\plink.exe"
    $username = $account_credentials.Username
    #Makes key at /home/<account>/.ssh/
    $command = ''
    if ($overwrite) {
        $command += ("rm -f" + $id_rsa + "; ")
    }
    #echo y | &C:\Program Files\PuTTy\plink.exe -pw <password> <username>@<ip> <command>
    $command += "echo '' | ssh-keygen -t rsa -b 4096 -q -N '' ; ssh-add $id_rsa 2>/dev/null"
    Write-Host "Running the following command on $ip (Note: I might be noisy depending on if you've remoted into the host or not):" $command
    $pwd = [Net.NetworkCredential]::new('', $account_credentials.Password).Password
    (echo y | & $plink_path -pw $pwd $username@$ip $command) >$null 2>&1
    Clear-Variable pwd
}

Function Generate-SelfSshKey {
	<#
		WinRM wasn't working well on RDPC running this script. So instead going to run local.
		
		Args:
			$overwrite: Boolean If true overwrites the existing key
			$account: The account we are expecting to be signed in as to make a key
            $ssh_folder: The path to the SSH folder. Defaults to global win_ssh_folder.
	#>
	Param([Boolean]$overwrite=$overwrite,
		  [String]$account=$account,
          [string]$ssh_folder=$win_ssh_folder)
	
    $id_rsa = ($ssh_folder + "\id_rsa")
	Write-Host "Making localhost key first..."
	if ($env:UserName.ToLower() -ne $account.ToLower()) {
		Write-Host "Please rerun this from" $account "-- You are signed in as" $env:UserName
		exit
	}
	if ($overwrite) {
		ssh-add -d >$null 2>&1
	}
	"" ; "" | ssh-keygen -t rsa -b 4096 -q -N '""'
	ssh-add $id_rsa >$null 2>&1
}

Function Generate-WindowsSshKeys {
    <#
        **For windows**
        Generates the private and public SSH keys for passwordless use with the passed account
        Keys are generated in a invoke-command session to allow different credential use.

        Doing this ensures the creation of the required folders for the authorized key to be placed.

        Note: this does not overwrite an existing key by default

        Args:
            $account_credentials: System.Management.Automation.PSCredential Object. The account credentials to use and create keys unders
            $ip: String. The IP to remote into.
            $ssh_folder: string. The absolute path to store the made keys in. No trailing "\". Defaults to $ssh_folder global.
            $putty_path: string. The absolute path to the Putty directory. No trailing "\". Defaults to $putty_path global.
            $overwrite: boolean. Overwrites and existing key or not. Defautls to false
    #>
    Param([System.Management.Automation.PSCredential]$account_credentials, 
          [string]$ip,
          [string]$ssh_folder=$win_ssh_folder,
          [string]$putty_path=$putty_path,
          [boolean]$overwrite=$False)
    $id_rsa = ($ssh_folder + "\id_rsa")
    #Makes key at C:\Users\<account>\.ssh\
    if ($overwrite) {
        Invoke-Command -ComputerName $ip -Credential $account_credentials -ScriptBlock {
            Write-Host "Removing Existing id_rsa Keys..."
            Remove-Item ($using:ssh_folder + "\*")
            ssh-add -d >$null 2>&1 #why are ssh commands so freaking noisy!!!!
            Write-Host "Making new keys..."
            "" ; "" | ssh-keygen -t rsa -b 4096 -q -N '""'
			ssh-add $using:id_rsa >$null 2>&1
        }
    }
    else {
        Invoke-Command -ComputerName $ip -Credential $account_credentials -ScriptBlock {
            Write-Host "Making new keys... (won't overwrite if preexisting)"
            "" ; "" | ssh-keygen -t rsa -b 4096 -q -N '""'
			ssh-add $using:id_rsa >$null 2>&1
        }
    }
}

Function Grab-IPs {
    <#
        Goes through and grabs any IPs which reach back and can conduct a WinRM with

        Args:
            ip_range: String. The first 3 octect range of the /24 network. Defaults to the global ip_range.

        Returns:
            Array of WinRM IPs
            Array of SSH IPs
    #>
    Param([string]$ip_range=$ip_range)
    
    $winrm_array = @()
    $ssh_array = @()
    Write-Host "`nDetecting usable IPs in the" $ip_range "network... This may take a minute"
    For ($n=50; $n -le 80; $n++) {
        $ip = $ip_range + "." + $n
		$my_ip = (Get-NetIPAddress | Where {$_.IPAddress -match $ip_range }).IPAddress
		if ($ip -eq $my_ip) {
			Write-Host "Found myself, skipping me..."
		}			
        elseif (Test-Connection $ip -Count 1 -Quiet) {
            if ([bool](Test-WsMan $ip -ErrorAction SilentlyContinue)) {
                Write-Host "WinRM IP Detected at $ip"
                $winrm_array += $ip
            }
            elseif ((Test-NetConnection $ip -Port 22 -WarningAction:SilentlyContinue).TcpTestSucceeded) {
                Write-Host "SSH IP detected at $ip"
                $ssh_array += $ip
            }
            else {
                Write-Host "IP detected but no remote connection capability detected for $ip"
            }
        }
        if ($n % 10 -eq 0) {
            Write-Host "..."
        }
    }
    Write-Host "Finished Calculating IPs"
    return $winrm_array, $ssh_array
}

Function Remote-SshKeys {
    <#
        Runs commands on remote systems through WinRM and SSH

        Args:
            $winrm_range: array. The IPs we can WinRM to.
            $ssh_range: array. The IPs we can ssh to.
            $account_credentials: System.Management.Automation.PSCredential. The account to remote around with.
			$overwrite: Boolean. Whether to overwrite keys or not.
    #>
    Param([array]$winrm_range,
          [array]$ssh_range,
          [System.Management.Automation.PSCredential]$account_credentials,
		  [Boolean]$overwrite=$overwrite)
    Write-Host "Creating SSH Key Pairs..."
    Write-Host "Working through the Win-RM IPs first..."    
    foreach ($ip in $winrm_range) {
       Generate-WindowsSshKeys $account_credentials $ip -Overwrite $overwrite
       Copy-SshId $account_credentials $ip $winrm_range $win_ssh_folder
    }
    Write-Host "Finished WinRM IPs... Working SSH IPs now..."
    foreach ($ip in $ssh_range) {
       Generate-LinuxSshKeys $account_credentials $ip -Overwrite $overwrite
       Copy-SshId $account_credentials $ip $winrm_range $linux_ssh_folder
    }
    Write-Host "Finished generating key pairs..."
    Write-Host "Accepting Host Key Fingerprints for PowerShell and testing functionality..."
    $ips = $ssh_range + $winrm_range
    foreach ($ip in $ips) {
        Accept-SSHFingerprints $account_credentials $ip
    }
}

Function Main {
    $account_credentials = Get-Credential -UserName $account -Message "Please provide the credentials for the account you want to make keys for"
    Write-Host "Starting script functions -- I take about 10-20 minutes to fully run"
	Generate-SelfSshKey $overwrite
    $winrm_ips, $ssh_ips = Grab-IPs
    Remote-SshKeys $winrm_ips $ssh_ips $account_credentials $overwrite
}

Main
