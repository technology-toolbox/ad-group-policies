<#
.SYNOPSIS
Removes the HTML report and all backups for the specified group policy.

.DESCRIPTION
The `Remove-GroupPolicyExport` cmdlet removes the HTML report and all backups
for the specified group policy and domain. If no domain is specified, the domain
for the current environment is used.

.EXAMPLE
.\Remove-GroupPolicyExport.ps1 6ac1786c-016f-11d2-945f-00c04fb984f9

.EXAMPLE
.\Remove-GroupPolicyExport.ps1 31b2f340-016d-11d2-945f-00c04fb984f9 FABRIKAM
#>
[CmdletBinding()]
Param(
    [Parameter(Position=0, Mandatory=$true)]
    [Guid] $GroupPolicyId,
    [Parameter(Position=1, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
}

Process
{
    if ([string]::IsNullOrEmpty($DomainNetBiosName) -eq $true) {
        Write-Verbose ("DomainNetBiosName not specified, " `
            + "defaulting to current domain...")

        $DomainNetBiosName = & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"
    }

    & "$PSScriptRoot\Remove-GroupPolicyReport.ps1" `
        -GroupPolicyId $GroupPolicyId `
        -DomainNetBiosName $DomainNetBiosName

    & "$PSScriptRoot\Remove-GroupPolicyBackup.ps1" `
        -GroupPolicyId $GroupPolicyId `
        -DomainNetBiosName $DomainNetBiosName
}
