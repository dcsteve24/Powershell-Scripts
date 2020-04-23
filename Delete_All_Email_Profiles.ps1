#Deletes Users Exchange Profile if it hasnt been done before (checks for file it creates when ran)

$checkFile = "C:\Users\Public\OutlookRefreshed.txt"

if (!(Test-Path $CheckFile)) { #if file not present
    New-ItemProperty -Path HKCU:\Software\Microsoft\Office\16.0\Outlook\AutoDiscover -Name ZeroConfigExchange -Value 1 -PropertyType DWORD -Force

    Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\*" -Recurse -Force

    Remove-ItemProperty -Path HKCU:\Software\Microsoft\Office\16.0\Outlook\Setup\ -name First-Run

    New-Item $checkFile
}