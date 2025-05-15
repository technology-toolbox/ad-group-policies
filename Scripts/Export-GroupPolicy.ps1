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
.\Export-GroupPolicy.ps1 31b2f340-016d-11d2-945f-00c04fb984f9

.EXAMPLE
.\Export-GroupPolicy.ps1 'Default Domain Policy'

.EXAMPLE
.\Export-GroupPolicy.ps1 -All
#>
[CmdletBinding(DefaultParameterSetName='ByGUID')]
Param(
    [Parameter(ParameterSetName='ByGUID', Position=0, Mandatory=$true)]
    [guid] $GroupPolicyId,

    [Parameter(ParameterSetName='ByName', Position=0, Mandatory=$true)]
    [string] $Name,

    [Parameter(ParameterSetName='ByGUID', Position=1, Mandatory=$false)]
    [Parameter(ParameterSetName='ByName', Position=1, Mandatory=$false)]
    [Parameter(ParameterSetName='GetAll', Position=1, Mandatory=$false)]
    [string] $Server,

    [Parameter(ParameterSetName='GetAll', Mandatory=$true)]
    [switch] $All
)

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
                -DomainNetBiosName $domainNetBiosName

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
    Write-Debug "GroupPolicyId: $GroupPolicyId"
    Write-Debug "Name: $Name"
    Write-Debug "Server: $Server"
    Write-Debug "All: $All"

    if ([string]::IsNullOrEmpty($Server) -eq $true) {
        Write-Verbose "Server not specified, defaulting to `"first`" DC..."

        $Server = Get-ADDomainController -Filter * |
            Sort-Object HostName |
            Select-Object -First 1 -ExpandProperty HostName
    }

    Write-Verbose "Exporting group policies from server ($Server)..."

    [string] $domainNetBiosName = `
        & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"

    switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            $groupPolicies = Get-GPO -Name $Name -Server $Server
        }
        'ByGUID' {
            $groupPolicies = Get-GPO -Guid $GroupPolicyId -Server $Server
        }
        'GetAll' {
            $groupPolicies = Get-GPO -Server $Server -All |
                Sort-Object CreationTime
          }
        default {
            throw "Unexpected parameter set ($($PSCmdlet.ParameterSetName))."
        }
    }
    
    $groupPolicies |
        ForEach-Object {
            ExportGroupPolicyObject $_ $domainNetBiosName $Server

            ExportGroupPolicyReport $_ $domainNetBiosName $Server
        }

    FormatGpoManifestFile $domainNetBiosName
}
