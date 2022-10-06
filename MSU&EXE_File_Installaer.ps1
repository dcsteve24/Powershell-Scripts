<#
Runs through all files located at the specified path and installs them

Designed to be inserted into a startup/logon script placed by GPO so these
always update and install.

Created by: Steven Craig 31Jul2022
#>

# vars
$root_filepath = "\\XX.XXX\NETLOGON\GPO Files\Script Installs\" #Populate me with root folder

# Software rules regarding installation locations
# Using same dictionary format, add the following (use @() for defaults in Hosts and Parameters):
    # FolderName = folder name to look for (the name under the path above). Cannot be empty.
        # Uses wildcard matching. Must be single string.
    # Hosts = devices to install on separated by commas. Uses wildcards so doesnt have
        # to be exact match if more than one desired (e.g. RDPC will match all 5).
        # Defaults to install on everything if empty. Must be array even if one
        # entry (wrap in @())

#============ADJUST THIS AS NEEDED=================
$install_rules = @{
    "RSAT" = @{
        "FolderName" = "RSAT"
        "Hosts" = @("XXXX") 
    }
    "SSMS" = @{
        "FolderName" = "SSMS"
        "Hosts" = @("XXXXX", "XXXX")
    }
    "DotNet" = @{
        "FolderName" = "DotNet Framework"
        "Hosts" = @("XXXX")
    }
    "CudaDrivers" = @{
        "FolderName" = "Cuda_Drivers"
        "Hosts" = @("XXXXX")
    }
}

#functions
Function Driver {
    <#
        Driver function to pull in files to handle and loops through them,
        passing them to the processor to handle.
    #>
    $files = Get-Contents
    foreach ($file in $files) {
        Write-Verbose "Processing $file..."
        Process-File $file
    }
}

Function Process-File {
    <#
        Checks to see if the passed software should be installed
        on the current device. If so passes to the install function.

        Parameters:
            String: full path to install file
    #>
    Param([string]$filepath)
    foreach ($rule in $install_rules.Keys) {
        $foldername = $install_rules.$rule.FolderName
        $hosts = $install_rules.$rule.Hosts
        # First match folder - rule[0] should be folder name
        if ($foldername -eq $null) { throw "Code Error: The foldername cannot be empty" }
        if ($filepath -like ("*" + $foldername + "*")) {
            # Found match, see if we should install it
            if (Check-Host $hosts) {
                # Installing it, first lets fix parameters to a single line
                Write-Verbose "Determined we should install the file on this host..."
                Install-File $filepath
                return
            }
        }
    }
    Write-Verbose "No match for the file $filepath, Did not install this file..."    
}

Function Get-Contents {
    <#
        Grabs exact file paths of all .exe or .msu files contained in
        the file path.

        Returns array of full paths of files.
    #>
    $files = @(Get-ChildItem $root_filepath -File -Recurse | %{$_.FullName} )
    if ($files.Length -lt 1) { Throw "No files detected" }
    return $files
}

Function Check-Host {
    <#
        Checks the hosts to see if the install should occur on this host.

        Args:
            - array of strings containing host values

        Returns:
            - Bool - True if it should install here, False if not.
    #>
    Param([array]$hosts)
    if ($hosts.Length -eq 0) { return $true }
    $hostname = $env:COMPUTERNAME
    foreach ($install_host in $hosts) {
        if ($hostname -like ("*" + $install_host + "*")) { return $true }
    }
    return $false
}


Function Install-File {
    <#
        Installs the passed file and determines what to use for arguments
        based on install type. Users may need to restart before the application
        displays. Can also take a few minutes before the application is usable

        Param: 
            - string full path to exe
    #>
    Param ([string]$filepath)
    # Note: Wasted so much time trying to make parameters a variable. Couldn't figure it out. It is literally
    # treating the variable 100% different than the hard code no matter what i did. Also single quotes (')
    # matters for the arguments -- double quotes will not work...
    if ($filepath.EndsWith(".exe")) {
        if ($filepath -like "*cuda*"){
            Write-Verbose "Installing with the following command: '& $filepath -s'"
            & $filepath @('-s') 
        }
        else {
            Write-Verbose "Installing with the following command: '& $filepath /install /quiet /norestart'" 
            & $filepath @('/install', '/quiet', '/notrestart')
        }
    }
    elseif ($filepath.EndsWith(".msu")) {
        Write-Verbose "Installing with the following command: 'wusa.exe $filepath /install /quiet /norestart'"
        & wusa.exe @($filepath, '/quiet', '/norestart')
    }
    else {
        $file_type = $filepath.Split(".")[-1]
        Throw "Code Error: Code doesn't know how to run the $file_type file type" 
    }
}

#main
Driver
