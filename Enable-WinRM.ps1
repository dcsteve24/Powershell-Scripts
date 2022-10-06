<#
Enables PowerShell Remote capabilities (WinRM) for Use

Created by: Steven Craig 26Sep2022
#>

Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts 172.17.0.* -Force
Restart-Service WinRM
