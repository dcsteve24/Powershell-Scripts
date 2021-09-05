Param([Parameter(Position=0)][int]$year, [Parameter(Position=1)][int]$month, [Parameter(Position=2)][int]$day, [Parameter(Position=3)][string]$source, [Parameter(Position=4)][string]$destination)

#------------------------------------------------------------------------------------------
#Runs a differential backup based on the working directory that the script and date supplied.
# Moves files that meet the criteria to destination
#
#260 char is a limit for a file path. If you have a long destination path,
# you may hit that limit.
#
#This script is designed to be a differential backup script. It loads the file attributes
# of what meets the specified criteria into memory to parse through and grab attributes
# for directories, size, and names. If you attempt to do a full backup or large backup
# of a large source with this script, YOU WILL OVERLOAD YOUR MACHINE unless you have
# a signifigant amount of RAM. As an example: This was tested with a 9TB source which
# resulted in about 2 million files and 900GB of data being copied; this effort took up
# 8 GB of RAM in memory. Assess your system accordingly.
#
#I plan to work on a version that doesnt load into memory as time allows.
#
#This script has been tested on a 9TB scan. It took roughly 15 hours to scan, before
# moving files. It has been created to work on all versions of PowerShell.
#-----------------------------------------------------------------------------------------

#Functions
Function AskData
{
    #Asks for information required if not given as argument, and cleans the entries up so script takes it
    Param([Parameter(Position=0)]$data,
          [Parameter(Position=1)][int]$switchInt)

    if (IsNull $data) {
            do {
                switch ($switchInt){
                    0 {$data = [int](Read-Host -Prompt "`n`rDifferential backup -- set year (number)")} #year
                    1 {$data = [int](Read-Host -Prompt "`n`rDifferential backup -- set month (number)")} #month
                    2 {$data = [int](Read-Host -Prompt "`n`rDifferential backup -- set day (number)")} #day
                    3 {$data = Read-Host -Prompt "`n`rDifferential backup -- set source path"} #source
                    4 {$data = Read-Host -Prompt "`n`rDifferential backup -- set destination path"} #destination
                    }
                }
            while (IsNull $data)
        }

    if ($data -eq [string]) {$data = $data.Trim("'"); $data = $data.Trim('"')}  #cleans up the variable
    return $data
}

Function GetTime
{
    #Returns the time
    $time = (Get-Date -Format g).ToString()
    Return $time
}

Function IsNull
{
    #Checks everythign for null. A different approach to [Int] variables may be needed if 0 is needed. Returns true if null.
    Param([Parameter(Position=0)]$data)

    if ($data -eq 0) {return $true} #ints
    if ($data -eq $null) {return $true} #Objects
    if ($data -is [String] -and $data -eq [String]::Empty) {return $true} #Strings
    #if ($data -is [DBNull] -or $data -is [System.Management.Automation.Language.NullString]) {return $true} #Doesn't work on version PS v1.0
    else {return $false}
}

#---------------------START SCRIPT-----------------
#Welcome
Write-Host -ForegroundColor Yellow "Welcome! This script will prompt you for any missing parameters. Alternativley, you can run this script with:
`n`r <path to script> <year> <month> <day> <source in quotes> <destination in quotes>
`n`r for example: .\DateRange_Backup_Script.ps1 2018 08 24 'Z:\Data' 'C:\Backup'
`n`r The above example would grab files edited after 08August18 from Z:\Data and move them to C:\Backup"
Start-Sleep 5
Write-Host -ForegroundColor Yellow "`n`r
`n`rThis can be further automated by using the Get-Date command to pull current timeframes.
`n`r For example: .\DateRange_Backup_Script.ps1 (Get-Date).year ((Get-Date).AddMonth(-2)).Month (Get-Date).Day 'Z:\Data' 'C:\Backup'
`n`r The above example would grab files edited anytime after 2 months from the current date.
`n`r
`n`rIf you wish to automate this script, you will need to schedule it to a task or GPO with the parameters.
`n`r Created by Steven Craig 28Aug18"
Start-Sleep 5
Write-Host -ForegroundColor Cyan "`n`rNOTICE: File paths have a 260 char limit and if you have a long destination path, you may hit that limit and items won't copy."

#-----------Variables-------------
#Set year and check input
$year = AskData $year 0
while (!($year.ToString().Length -eq 4)){
    Write-Host -ForegroundColor Yellow "Please input a 4 digit year"
    $year = $null
    $year = AskData $year 0}
#Set month and check input
$y = $false #Below is required to make sure Powershell v1.0 checks input. Can be reduced for later versions by setting array and using -Contains
$monthArray = 1,2,3,4,5,6,7,8,9,10,11,12 #Used to ensure proper input for Powershell V1.0; month entry can be altered to read better on later versions if desired
while (! $y) {
    If (IsNull $month) {
        Write-Host -ForegroundColor Yellow "`n`rPlease input 1-12"
        $month = AskData $month 1}
    foreach ($x in $monthArray) {
        if ($month -like $x) {
            $y = $true}}
    If (! $y) {
        $month = $null}}
#Set days and check input
$z = $false #Below is required to make sure Powershell v1.0 checks input for acceptable entries. Can be severly reduced for later versions.
$dayArray = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31 #Used to ensure proper input for Powershell V1.0
while (! $z) {
    If (IsNull $day) {
        Write-Host -ForegroundColor Yellow "`n`rPlease input 1-31"
        $day = AskData $day 2}
    foreach ($x in $dayArray) {
        if ($day -like $x) {
            $z = $true}}
    If (! $z) {
        $day = $null}}
#Sets source and checks if exists
$source = AskData $source 3
while (!(Test-Path $source)) {
    Write-Host "`n`rSource path provided is not found"
    $source = $null
    $source = AskData $source 3}
#Sets destination and checks if exists
$destination = AskData $destination 4
while (!(Test-Path $destination)) {
    Write-Host "`n`rDestination path provided is not found"
    $destination = $null
    $destination = AskData $destination 4}
$date = Get-Date -Year $year -Month $month -Day $day #Sets the date used for differential backup
$errorLogPath = $PWD.ToString() + "\BackupErrorLog.txt" #Sets the path for an error log
$writeLogPath = $PWD.ToString() + "\BackupLog.txt" #Sets the path for tracking actions
$count = 1 #Used to number errors
$lineSeperator = "---------------------------------" #used to seperate error logs
#Add the ending "\" if missing, to the source and destination paths so everything matches
if (($source[($source.Length)-1]) -notlike "\") { $source = $source + "\" }
if (($destination[($destination.Length)-1]) -notlike "\") { $destination = $destination + "\" }


#Grab File Attributes into Array -- Legnth varies on source. It's going to scan everything so a 1TB source will take a signifigant amount of time (i.e. 12 hours).
Write-Host -ForegroundColor Green "`n`n`n`rScanning the source location. Depending on the size, this could take some time."
$files = Get-ChildItem -Recurse $source | Where-Object { (! $_.PSIsContainer) -and ($_.LastWriteTime -gt $date) }

#Write how big the size is so an estimated wait is aquired.
$totalSize = ($files | Measure-Object -Sum Length).Sum / 1MB
$totalCount = $files | Measure-Object | ForEach-Object{$_.Count}
$output = (GetTime) + " - Starting the copy: The script is copying $totalCount files. The total size is $totalSize MBs."
Write-Host "`n`n"
Write-Host -ForegroundColor Green $output
$output >> $writeLogPath

#Use file attributes to make destination folders and copy items into them
foreach ($x in $files) {
    $filelocation = $x.DirectoryName + "\" + $x.Name
    $directory = $x.DirectoryName
    For ($i = 0; $i -lt $source.Length; $i++) { #Tried just Trimming the $source sometimes pulls off to much. Stepping through each char ensures it keeps correct structure.
          $char = ($source.ToString())[$i]
          $directory = $directory.TrimStart($char)
          }
    if ($directory -like "\") {
        $directory = "" }
    $destDirectory = $destination + $directory
    $destPath = $destDirectory + "\" + $x.Name
    Try {
        if (!(Test-Path $destDirectory)) {
            $killOutput = New-Item -ItemType directory $destDirectory -Force
            $output = (GetTime) + " - MADE DIRECTORY: $destDirectory"
            $output >> $writeLogPath
            }
        $killOutput = Copy-Item $filelocation $destPath -Force
        $output = (GetTime) + " - COPYING FILE: $filelocation to $destPath"
        $output >> $writeLogPath
        }
    Catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        $output = "Error:$count Time:" + (GetTime) + "`n`rFailed on: $FailedItem `n`rMessage: $ErrorMessage"
        $output >> $errorLogPath
        $lineSeperator >> $errorLogPath
        Break
        }
    }
Write-Host -ForegroundColor Green ((GetTime) + " - FINISHED")
$output = (GetTime) + "- FINISHED"
$output >> $writeLogPath
