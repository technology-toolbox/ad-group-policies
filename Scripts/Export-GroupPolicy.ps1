<#
.SYNOPSIS
Exports group policy objects and group policy reports from Active Directory.

.DESCRIPTION
Group policy objects are exported to the "..\{domain name}\GPOs" folder (using
the backup format). Group policy reports are exported to the
"..\{domain name}\GP Reports" folder (using HTML format). This folder structure
is based on the one used in the Microsoft Security Compliance Toolkit 1.0
(https://www.microsoft.com/en-us/download/details.aspx?id=55319).

.EXAMPLE
.\Export-GroupPolicy.ps1

Domain  DisplayName
------  -----------
CONTOSO Default Domain Policy
CONTOSO Default Domain Controllers Policy
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
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"),
        [string] $server =
            $(Throw "Value cannot be null: server"))
    {
        # Export group policy object (using backup format)

        Write-Verbose "Exporting group policy object ($($gpo.DisplayName))..."

        [string] $basePath = [System.IO.Path]::Combine(
            $PSScriptRoot,
            "..",
            $domainNetBiosName,
            "GPOs")

        if ((Test-Path $basePath) -eq $false) {
            New-Item $basePath -Type Directory | Out-Null
        }

        $basePath = Resolve-Path $basePath

        Backup-GPO -Guid $_.Id -Path $basePath -Server $server | Out-Null
    }

    Function ExportGroupPolicyReport(
        [Microsoft.GroupPolicy.Gpo] $gpo =
            $(Throw "Value cannot be null: gpo"),
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"),
        [string] $server =
            $(Throw "Value cannot be null: server"))
    {
        # Export group policy reports

        Write-Verbose "Exporting group policy report ($($gpo.DisplayName))..."

        [string] $reportFolder = `
            & "$PSScriptRoot\Get-GroupPolicyReportsPath.ps1" `
                $domainNetBiosName

        if ((Test-Path $reportFolder) -eq $false) {
            New-Item $reportFolder -Type Directory | Out-Null
        }

        [string[]] $invalidFileNameChars = ([System.IO.Path]::GetInvalidFileNameChars() |
            Where-Object { 32 -le [int]$_ -and [int]$_ -le 127 })

        [string] $fileNameReplacePattern = "[" + [Regex]::Escape($invalidFileNameChars -join "") + "]"

        $baseName = [Regex]::Replace($gpo.DisplayName, $fileNameReplacePattern, "~")

        [string] $reportPath = [System.IO.Path]::Combine(
            $reportFolder,
            $baseName + ".html")

        Get-GPOReport -Guid $gpo.Id -ReportType HTML -Path $reportPath -Server $server
    }
}

Process
{
    # Configure default display set for output type
    Update-TypeData `
        -TypeName GroupPolicy.Export `
        -DefaultDisplayPropertySet Domain, DisplayName -Force

    if ([string]::IsNullOrEmpty($Server) -eq $true) {
        Write-Verbose "Server not specified, defaulting to `"first`" DC..."

        $Server = Get-ADDomainController -Filter * |
            Sort-Object HostName |
            Select-Object -First 1 -ExpandProperty HostName
    }

    [string] $domainNetBiosName = Get-ADDomain |
        Select-Object -ExpandProperty NetBIOSName

    $groupPolicies = Get-GPO -Server $server -All |
        Sort-Object CreationTime -Descending

    $groupPolicies |
        ForEach-Object {
            ExportGroupPolicyObject $_ $domainNetBiosName $server

            ExportGroupPolicyReport $_ $domainNetBiosName $server

            [PSCustomObject] $output = [PSCustomObject][Ordered] @{
                Domain = $domainNetBiosName
                DisplayName = $_.DisplayName
                Id = $_.Id
            }

            $output.PSTypeNames.Insert(0,'GroupPolicy.Export')

            $output
        }

        & "$PSScriptRoot\Format-GroupPolicyBackupManifest.ps1" `
            $domainNetBiosName
}
