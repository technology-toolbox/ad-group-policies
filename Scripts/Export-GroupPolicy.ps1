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
            & "$PSScriptRoot\Get-GroupPolicyReportPath.ps1" `
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

    Function FormatGpoManifestFile(
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        Write-Verbose "Formatting GPO manifest file..."

        [string] $path = [System.IO.Path]::Combine(
            $PSScriptRoot,
            "..",
            $domainNetBiosName,
            "GPOs\manifest.xml")

        $path = Resolve-Path $path

        $xml = [xml] (Get-Content $path)

        # HACK: XmlDocument.Save *should* simply overwrite the existing file.
        # Unfortunately it actually throws an error:
        #
        # Exception calling "Save" with "1" argument(s): "Access to the path
        # 'C:\...\ad-group-policies\GPOs\manifest.xml' is denied."
        #
        # To avoid this issue, forcefully delete the file (to avoid the "access
        # denied" error) and then save the formatted XML.
        Remove-Item $path -Force

        $xml.Save($path)
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

    [string] $domainNetBiosName = `
        & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"

    $groupPolicies = Get-GPO -Server $server -All |
        Sort-Object CreationTime

    $groupPolicies |
        ForEach-Object {
            ExportGroupPolicyObject $_ $domainNetBiosName $server

            ExportGroupPolicyReport $_ $domainNetBiosName $server
        }

    FormatGpoManifestFile $domainNetBiosName
}
