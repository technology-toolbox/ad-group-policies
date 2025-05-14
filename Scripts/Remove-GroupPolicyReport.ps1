<#
.SYNOPSIS
Removes the HTML report for the specified group policy.

.DESCRIPTION
The `Remove-GroupPolicyReport` cmdlet removes the HTML report for the specified
group policy and domain. If no domain is specified, the domain for
the current environment is used.

.EXAMPLE
.\Remove-GroupPolicyReport.ps1 6ac1786c-016f-11d2-945f-00c04fb984f9

.EXAMPLE
.\Remove-GroupPolicyReport.ps1 31b2f340-016d-11d2-945f-00c04fb984f9 FABRIKAM
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$true)]
    [Guid] $GroupPolicyId,
    [Parameter(Position=2, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function RemoveGroupPolicyReport(
        [Guid] $groupPolicyId =
            $(Throw "Value cannot be null: groupPolicyId"),
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        Write-Verbose ("Removing group policy ($groupPolicyId) report for" `
            + " domain ($domainNetBiosName)...")

        [PSCustomObject] $report = `
            & "$PSScriptRoot\Get-GroupPolicyReport.ps1" $domainNetBiosName |
            Where-Object { $_.GroupPolicyId -eq $groupPolicyId }

        if ($null -eq $report) {
            throw ("Cannot find group policy report for domain" `
                + " ($domainNetBiosName) and group policy ID ($groupPolicyId).")
        }

        Remove-Item -Path $report.Path
    }
}

Process
{
    if ([string]::IsNullOrEmpty($DomainNetBiosName) -eq $true) {
        Write-Verbose ("DomainNetBiosName not specified, " `
            + "defaulting to current domain...")

        $DomainNetBiosName = & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"
    }

    RemoveGroupPolicyReport $GroupPolicyId $DomainNetBiosName
}
