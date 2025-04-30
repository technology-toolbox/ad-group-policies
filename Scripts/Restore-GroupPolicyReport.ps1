<#
.SYNOPSIS
Restores modified group policy reports in the working tree where the only change
is the date/time a report was generated.

.DESCRIPTION
The `Restore-GroupPolicyReport` cmdlet restores modified group policy reports in
the working tree if -- and only if -- a report only differs from the version
stored in the local Git repository by the date/time the report was generated.
If no domain is specified, the domain for the current environment is used.

.EXAMPLE
.\Restore-GroupPolicyReport.ps1

Domain  ReportName                             DiffSummary                   DiffersByDateOnly
------  ----------                             -----------                   -----------------
CONTOSO Default Domain Controllers Policy.html (no changes)                              False
CONTOSO Default Domain Policy.html             1 insertion(+), 1 deletion(-)              True

.EXAMPLE
.\Restore-GroupPolicyReport.ps1 FABRIKAM

Domain   ReportName                             DiffSummary                    DiffersByDateOnly
------   ----------                             -----------                    -----------------
FABRIKAM Default Domain Controllers Policy.html 2 insertions(+), 1 deletion(-)             False
FABRIKAM Default Domain Policy.html             1 insertion(+), 1 deletion(-)               True
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function RestoreGroupPolicyReport(
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"),
        [string] $reportName =
            $(Throw "Value cannot be null: reportName"),
        [string] $reportPath =
            $(Throw "Value cannot be null: reportPath"))
    {
        # Restore the specified group policy report if -- and only if -- the
        # report differs by the date/time the report was generated

        # Configure default display set for output type
        Update-TypeData `
            -TypeName GroupPolicyReport.Restore `
            -DefaultDisplayPropertySet Domain, ReportName, DiffSummary, DiffersByDateOnly -Force
    
        Write-Verbose ("Examining differences in group policy report" `
            + " ($reportName)...")

        [string] $reportPath = $_.FullName

        [PSCustomObject] $comparison = `
            & "$PSScriptRoot\Compare-GitRepositoryFile.ps1" $reportPath

        [bool] $reportDiffersByDateOnly = $false

        if ($comparison.DiffSummary -eq "1 insertion(+), 1 deletion(-)") {
            Write-Verbose "Group policy report ($reportName) is modified..."
            Write-Verbose "Group policy report ($reportName) may differ only by date."

            [string[]] $changes = $comparison.Changes

            [string] $matchString = "<td id=`"dtstamp`">Data collected on: "

            # Check if the length of content deleted/added falls within the expected limit
            # (i.e. we expect the "<td ...>Data collected on: ..." line of HTML that was modified to be less than or equal to 68 characters)
            if (($changes[0].Length -le 68) `
                    -and ($changes[1].Length -le 68)) {
                if ($changes[0].Contains($matchString) -eq $true) {
                    Write-Verbose "Deletion refers to report date"

                    if ($changes[1].Contains($matchString) -eq $true) {
                        Write-Verbose "Group policy report ($reportName) differs only by date."

                        $reportDiffersByDateOnly = $true

                        git restore -- $reportPath
                    }
                }
            }
        }

        [PSCustomObject] $output = [PSCustomObject][Ordered] @{
            Domain = $domainNetBiosName
            ReportName = $reportName
            DiffSummary = $comparison.DiffSummary
            DiffersByDateOnly = $reportDiffersByDateOnly
            Path = $reportPath
        }

        $output.PSTypeNames.Insert(0,'GroupPolicyReport.Restore')

        $output
    }

    Function RestoreGroupPolicyReports(
        [string] $domainNetBiosName =
            $(Throw "Value cannot be null: domainNetBiosName"))
    {
        # Restore all group policy reports for the specified domain

        Write-Verbose ("Restoring group policy reports for domain" `
            + " ($domainNetBiosName)...")

        [string] $reportFolder = `
            & "$PSScriptRoot\Get-GroupPolicyReportsPath.ps1" `
                $domainNetBiosName

        if ((Test-Path $reportFolder) -eq $false) {
            Write-Warning ("No group policy reports found for domain" `
                + " ($domainNetBiosName).")

            return
        }

        Get-ChildItem $reportFolder -Filter *.html |
            ForEach-Object {
                [string] $reportName = $_.Name
                [string] $reportPath = $_.FullName

                RestoreGroupPolicyReport $domainNetBiosName $reportName $reportPath
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

    RestoreGroupPolicyReports $DomainNetBiosName
}
