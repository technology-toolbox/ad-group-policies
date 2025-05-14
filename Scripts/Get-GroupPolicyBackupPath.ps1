<#
.SYNOPSIS
Gets the full path to the "GPOs" backup folder for a specific domain.

.DESCRIPTION
The `Get-GroupPolicyBackupPath` cmdlet gets the full path to the "GPOs" backup
folder for a specific domain. If no domain is specified, the domain for the
current environment is used.

.EXAMPLE
.\Get-GroupPolicyBackupPath.ps1

C:\BackedUp\GitHub\technology-toolbox\ad-group-policies\CONTOSO\GPOs

.EXAMPLE
.\Get-GroupPolicyBackupPath.ps1 FABRIKAM

C:\BackedUp\GitHub\technology-toolbox\ad-group-policies\FABRIKAM\GPOs
#>
[CmdletBinding()]
Param(
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

    Write-Verbose ("Getting group policy backup path for domain" `
        + " ($domainNetBiosName)...")

    [string] $basePath = [System.IO.Path]::Combine(
        $PSScriptRoot,
        "..",
        $domainNetBiosName,
        "GPOs")

    $basePath = Resolve-Path $basePath

    $basePath
}
