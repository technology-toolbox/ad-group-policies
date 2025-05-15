<#
.SYNOPSIS
Gets the full path to the "GP Reports" folder for a specific domain.

.DESCRIPTION
The `Get-GroupPolicyReportPath` cmdlet gets the full path to the "GP Reports"
folder for a specific domain. If no domain is specified, the domain for the
current environment is used.

.EXAMPLE
.\Get-GroupPolicyReportPath.ps1

C:\BackedUp\GitHub\technology-toolbox\ad-group-policies\CONTOSO\GP Reports

.EXAMPLE
.\Get-GroupPolicyReportPath.ps1 FABRIKAM

C:\BackedUp\GitHub\technology-toolbox\ad-group-policies\FABRIKAM\GP Reports
#>
[CmdletBinding()]
Param(
    [Parameter(Position=0, Mandatory=$false)]
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

    Write-Verbose ("Getting group policy reports path for domain" `
        + " ($domainNetBiosName)...")

    [string] $basePath = [System.IO.Path]::Combine(
        $PSScriptRoot,
        "..",
        $domainNetBiosName,
        "GP Reports")

    $basePath = Resolve-Path $basePath

    $basePath
}
