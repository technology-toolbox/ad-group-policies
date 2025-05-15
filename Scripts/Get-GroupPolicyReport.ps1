<#
.SYNOPSIS
Gets the previously exported group policy reports for a specific domain.

.DESCRIPTION
The `Get-GroupPolicyReport` cmdlet gets the previously exported group policy
reports for a specific domain. If no domain is specified, the domain for the
current environment is used.

.EXAMPLE
.\Get-GroupPolicyReport.ps1

Domain  ReportName                             GroupPolicyId
------  ----------                             -------------
CONTOSO Default Domain Controllers Policy.html {6ac1786c-016f-11d2-945f-00c04fb984f9}
CONTOSO Default Domain Policy.html             {31b2f340-016d-11d2-945f-00c04fb984f9}

.EXAMPLE
.\Get-GroupPolicyReport.ps1 FABRIKAM

Domain   ReportName                                  GroupPolicyId
------   ----------                                  -------------
FABRIKAM Default Domain Controllers Policy.html      {6ac1786c-016f-11d2-945f-00c04fb984f9}
FABRIKAM Default Domain Policy.html                  {31b2f340-016d-11d2-945f-00c04fb984f9}
#>
[CmdletBinding()]
Param(
    [Parameter(Position=0, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function GetGroupPolicyReports(
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        # Get all group policy reports for the specified domain

        Write-Verbose ("Getting group policy reports for domain" `
            + " ($domainNetBiosName)...")

        [string] $reportFolder = `
            & "$PSScriptRoot\Get-GroupPolicyReportPath.ps1" `
                -DomainNetBiosName $domainNetBiosName

        if ((Test-Path $reportFolder) -eq $false) {
            Write-Warning ("No group policy reports found for domain" `
                + " ($domainNetBiosName).")

            return
        }

        # Configure a default display set
        Update-TypeData `
            -TypeName GroupPolicyReport.Information `
            -DefaultDisplayPropertySet Domain, ReportName, GroupPolicyId -Force

        Get-ChildItem $reportFolder -Filter *.html |
            ForEach-Object {
                [string] $reportName = $_.Name
                [string] $reportPath = $_.FullName

                [string] $htmlLine = Get-Content $reportPath |
                    Where-Object {
                        $_ -match '<tr><td scope="row">Unique ID</td>'
                    } |
                    Select-Object -First 1

                [Guid] $groupPolicyId = [Guid]::Empty

                if ($htmlLine -match '\{[0-9a-fA-F\-]{36}\}') {
                    $groupPolicyId = $matches[0]
                }
                else {
                    throw "Group policy ID not found in report."
                }

                [PSCustomObject] $object = [PSCustomObject][Ordered] @{
                    Domain = $domainNetBiosName
                    ReportName = $reportName
                    GroupPolicyId = $groupPolicyId
                    Path = $reportPath
                }

                $object.PSTypeNames.Insert(0,'GroupPolicyReport.Information')

                $object
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

    GetGroupPolicyReports $DomainNetBiosName
}
