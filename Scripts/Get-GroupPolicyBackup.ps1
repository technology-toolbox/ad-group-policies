<#
.SYNOPSIS
Gets the group policy backups for a specific domain.

.DESCRIPTION
The `Get-GroupPolicyBackup` cmdlet gets the group policy backups for a specific
domain from the corresponding "manifest.xml" file. If no domain is specified,
the domain for the current environment is used.

.EXAMPLE
.\Get-GroupPolicyBackup.ps1

Domain  DisplayName                       BackupTime
------  -----------                       ----------
CONTOSO Default Domain Policy             4/28/2025 2:00:23 PM
CONTOSO Default Domain Controllers Policy 4/28/2025 2:00:23 PM

.EXAMPLE
.\Get-GroupPolicyBackup.ps1 FABRIKAM

Domain   DisplayName                            BackupTime
------   -----------                            ----------
FABRIKAM Default Domain Policy                  4/28/2025 12:22:50 PM
FABRIKAM Default Domain Controllers Policy      4/28/2025 12:22:50 PM
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function GetGroupPolicyBackup(
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        Write-Verbose ("Getting group policy backup for domain" `
            + " ($domainNetBiosName)...")

        # Configure default display set
        Update-TypeData `
            -TypeName GroupPolicyBackup.Information `
            -DefaultDisplayPropertySet Domain, DisplayName, BackupTime -Force

        [string] $backupFolder = & "$PSScriptRoot\Get-GroupPolicyBackupPath.ps1" `
            -DomainNetBiosName $domainNetBiosName

        [string] $manifestPath = [System.IO.Path]::Combine(
            $backupFolder, "manifest.xml")

        [string] $dateTimeFormat = "s"  # SortableDateTimePattern = "yyyy-MM-ddTHH:mm:ss"

        [xml] $xml = [xml] (Get-Content $manifestPath)
        foreach ($backup in $xml.Backups.BackupInst) {

            [PSCustomObject] $output = [PSCustomObject][Ordered] @{
                Domain = $domainNetBiosName
                DisplayName = $backup.GPODisplayName.InnerText
                GroupPolicyId = [Guid]::ParseExact($backup.GPOGuid.InnerText, "B")
                DomainController = $backup.GPODomainController.InnerText
                BackupTime = [DateTime]::ParseExact(
                    $backup.BackupTime.InnerText, $dateTimeFormat, $null)
                BackupId = [Guid]::ParseExact($backup.ID.InnerText, "B")
                Comment = $backup.Comment.InnerText
                Path = [System.IO.Path]::Combine($backupFolder, $backup.ID.InnerText)
            }

            $output.PSTypeNames.Insert(0,'GroupPolicyBackup.Information')

            $output
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

    GetGroupPolicyBackup $DomainNetBiosName
}
