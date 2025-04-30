<#
.SYNOPSIS
Formats the XML manifest file containing the list of backups for group policy
objects.

.DESCRIPTION
Group policy objects are exported to the "..\{domain name}\GPOs" folder (using
the backup format). The `Backup-GPO` cmdlet writes backup information to
"manifest.xml" using a compact format (without any whitespace between elements).
The `Format-GroupPolicyBackupManifest` cmdlet formats the XML to make it human
readable and to easily compare different versions.

.EXAMPLE
.\Format-GroupPolicyBackupManifest.ps1

.EXAMPLE
.\Format-GroupPolicyBackupManifest.ps1 FABRIKAM
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

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
    if ([string]::IsNullOrEmpty($DomainNetBiosName) -eq $true) {
        Write-Verbose ("DomainNetBiosName not specified, " `
            + "defaulting to current domain...")

        $DomainNetBiosName = & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"
    }

    FormatGpoManifestFile $DomainNetBiosName
}
