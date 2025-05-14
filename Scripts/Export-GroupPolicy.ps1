<#
.SYNOPSIS
Exports group policy objects and group policy reports from Active Directory.

.DESCRIPTION
Group policy objects are exported to the "..\GPOs" folder (using the backup format).
Group policy reports are exported to the "..\GP Reports" folder (using HTML format).
This folder structure is identical to the one used in the Microsoft Security
Compliance Toolkit 1.0 (https://www.microsoft.com/en-us/download/details.aspx?id=55319).

.EXAMPLE
.\Export-GroupPolicy.ps1 -Verbose
#>
[CmdletBinding()]
Param([string] $Server)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function ExportGroupPolicyObject(
        [Microsoft.GroupPolicy.Gpo] $gpo =
            $(Throw "Value cannot be null: gpo"),
        [string] $server =
            $(Throw "Value cannot be null: server"))
    {
        # Export group policy object (using backup format)

        Write-Verbose "Exporting group policy object ($($gpo.DisplayName))..."

        [string] $basePath = [System.IO.Path]::Combine($PSScriptRoot, "..\\GPOs")

        if ((Test-Path $basePath) -eq $false) {
            New-Item $basePath -Type Directory | Out-Null
        }

        $basePath = Resolve-Path $basePath

        Backup-GPO -Guid $_.Id -Path $basePath -Server $server | Out-Null
    }

    Function ExportGroupPolicyReport(
        [Microsoft.GroupPolicy.Gpo] $gpo =
            $(Throw "Value cannot be null: gpo"),
        [string] $server =
            $(Throw "Value cannot be null: server"))
    {
        # Export group policy reports

        Write-Verbose "Exporting group policy report ($($gpo.DisplayName))..."

        $basePath = [System.IO.Path]::Combine($PSScriptRoot, "..\\GP Reports")

        if ((Test-Path $basePath) -eq $false) {
            New-Item $basePath -Type Directory | Out-Null
        }

        $basePath = Resolve-Path $basePath

        [string[]] $invalidFileNameChars = ([System.IO.Path]::GetInvalidFileNameChars() |
            Where-Object { 32 -le [int]$_ -and [int]$_ -le 127 })

        [string] $fileNameReplacePattern = "[" + [Regex]::Escape($invalidFileNameChars -join "") + "]"

        $baseName = [Regex]::Replace($gpo.DisplayName, $fileNameReplacePattern, "~")

        [string] $reportPath = [System.IO.Path]::Combine(
            $basePath,
            $baseName + ".html")

        Get-GPOReport -Guid $gpo.Id -ReportType HTML -Path $reportPath -Server $server
    }
}

Process
{
    if ([string]::IsNullOrEmpty($Server) -eq $true) {
        Write-Verbose "Server not specified, defaulting to `"first`" DC..."

        $Server = Get-ADDomainController -Filter * |
            Sort-Object HostName |
            Select-Object -First 1 -ExpandProperty HostName
    }

    $groupPolicies = Get-GPO -Server $server -All |
        Sort-Object CreationTime

    $groupPolicies |
        ForEach-Object {
            ExportGroupPolicyObject $_ $server

            ExportGroupPolicyReport $_ $server
        }
}
