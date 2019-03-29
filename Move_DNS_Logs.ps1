#---------------------------------------------------------------------------------------------
#Basic File move script which moves DNS files from C:\Windows\System32\DNS to the deginated
#location by the user.
#
#Notes: If user running the script does not have access to desired location, script will fail
#
#Created: Steven Craig, Harris Sub-contractor 02May18
#Edited:
#--------------------------------------------------------------------------------------------

Function CheckWrite
{
    #Checks given file to see if it was written over 24 hours ago, returns True if over 24 hours, False if not.
    Param([Parameter(Mandatory=$True, Position=0)][string]$file,
          [Parameter(Mandatory=$True, Position=1)][int]$time)

    $lastEdit = (get-item $file).LastWriteTime
    $timeLimit = New-TimeSpan -hours $time

    If (((Get-Date) - $lastEdit) -gt $timeLimit) {return $True}
    Else {return $False}
}

Function MoveFiles
{
    #Main Function - Goes through files and moves ones that return true based on CheckWrite function
    Param([Parameter(Mandatory=$True, Position=0)][string]$oPath,
          [Parameter(Mandatory=$True, Position=1)][string]$dPath,
          [Parameter(Mandatory=$True, Position=2)][int]$time)

    #Loop through files in the directory
    Get-ChildItem $oPath | Foreach-Object {
    If ((CheckWrite $_.FullName $time) -eq $True) {Move-Item -Path $_.FullName -Destination $dPath -Force}
    }
}

#Set Variables
$originatingPath = "C:\Windows\System32\dns\dns2*.log"
$originatingPathArray = Get-Item "C:\Windows\System32\dns\dns2*.log"
$destinationPath = "\\YOUR_IP_OR_HOSTNAME\SHARED_DRIVE\"
$date = (Get-Date).Year
$timeSpan = 24
$destinationPathFull = $destinationPath + "\" + $date + "\" + $env:COMPUTERNAME

#Run Script
If (!(Test-Path $destinationPathFull)){
    mkdir $destinationPathFull
    }

Foreach ($x in $originatingPathArray){
    MoveFiles $originatingPath $destinationPathFull $timeSpan
    }
