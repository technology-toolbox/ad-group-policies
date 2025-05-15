<#
.SYNOPSIS
Removes the backups for the specified group policy.

.DESCRIPTION
The `Remove-GroupPolicyBackup` cmdlet removes all backups fro the specified
group policy and domain. If no domain is specified, the domain for the current
environment is used.

.EXAMPLE
.\Remove-GroupPolicyBackup.ps1 6ac1786c-016f-11d2-945f-00c04fb984f9

.EXAMPLE
.\Remove-GroupPolicyBackup.ps1 31b2f340-016d-11d2-945f-00c04fb984f9 FABRIKAM
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

    Function RemoveGroupPolicyBackupFromManifest(
        [Guid] $backupId =
            $(Throw "Value cannot be null: backupId"),
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        Write-Verbose ("Removing group policy backup ($backupId) for" `
            + " domain ($domainNetBiosName)...")

        [string] $backupFolder = & "$PSScriptRoot\Get-GroupPolicyBackupPath.ps1" `
            -DomainNetBiosName $domainNetBiosName

        [string] $manifestPath = [System.IO.Path]::Combine(
            $backupFolder, "manifest.xml")

        [xml] $xml = [xml] (Get-Content $manifestPath)

        $xml.Backups.BackupInst |
            where { [Guid]::ParseExact($_.ID.InnerText, "B") -eq $backupId } |
            foreach {
                $_.ParentNode.RemoveChild($_) | Out-Null
            }

        $xml.Save($manifestPath)
    }

    Function RemoveGroupPolicyBackups(
        [Guid] $groupPolicyId =
            $(Throw "Value cannot be null: groupPolicyId"),
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        Write-Verbose ("Removing group policy ($groupPolicyId) backups for" `
            + " domain ($domainNetBiosName)...")

        [PSCustomObject] $backups = `
            & "$PSScriptRoot\Get-GroupPolicyBackup.ps1" `
                -DomainNetBiosName $domainNetBiosName |
                Where-Object { $_.GroupPolicyId -eq $groupPolicyId }

        if ($null -eq $backups) {
            throw ("Cannot find any group policy backups for domain" `
                + " ($domainNetBiosName) and group policy ID ($groupPolicyId).")
        }

        $backups |
            ForEach-Object {
                RemoveGroupPolicyBackupFromManifest $_.BackupId $domainNetBiosName

                Remove-Item -Path $_.Path -Recurse -Force
            }
    }
}

Process
{
    if ([string]::IsNullOrEmpty($DomainNetBiosName) -eq $true) {
        Write-Verbose ("DomainNetBiosName not specified, " `
            + "defaulting to current domain...")

        $DomainNetBiosName = & "$PSScriptRoot\Get-DefaultDomainNetBiosName.ps1"
    }

    RemoveGroupPolicyBackups $GroupPolicyId $DomainNetBiosName
}
