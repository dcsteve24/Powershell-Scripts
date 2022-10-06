<#
Runs BGInfo on Startup and imports the BH settings. Designed as a startup script and should be tied to GPO.

Created by: Steven Craig 31Jul2022
#>

#vars
$root_fileshare = "XXXXXXXX" #populate me with root folder
$bginfo_location = $root_fileshare + "\BGInfo"

# Functions
Function Get-Contents {
    <#
        Gets the current BGInfo file from the share and the current configuration import.

        Returns:
            - BGInfo executable absolute path
            - BGInfo configuration file absoute path
    #>
    $files = @(Get-ChildItem $bginfo_location -File | %{$_.FullName})
    $conf_files = @()
    $exe_files = @()
    Foreach ($file in $files) {
        if ($file.EndsWith(".bgi")){ $conf_files += $file }
        elseif ($file.EndsWith(".exe")){ $exe_files += $file }
    }
    if ($conf_files.Length -gt 1) {
        $conf_files = @($conf_files | Sort-Object -Descending -Property LastWriteTime | Select -First 1)
    }
    if ($exe_files.Length -gt 1) {
        $exe_files = @($exe_files | Sort-Object -Descending -Property LastWriteTime | Select -First 1)
    }
    return $conf_files, $exe_files
}

Function Run-BGInfo {
    <#
        Runs BGInfo and imports the BH setup
    #>
    $conf_file, $exe_file = Get-Contents
    & $exe_file @($conf_file, '/timer:0', '/accepteula')
}

# Main
Run-BGInfo
