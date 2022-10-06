<#
Runs through all the Firewall rules and disables each rule.
This excludes the GPO rules -- therefore, if something remains blocked it means
your GPO rules are incorrect and need fixed.

Created by: Steven Craig 26Sep2022
#>

# vars
$Enabled_Rules = Get-NetFirewallRule -Enabled True

Foreach ($rule in $Enabled_Rules) {
    Write-Host "Disabling " + $rule.DisplayName + " FW rule."
    Disable-NetFirewallRule -DisplayName $rule.DisplayName
    Write-Host "Success!"
}
