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
.\Restore-GroupPolicyReport.ps1 -DomainNetBiosName CONTOSO -Verbose
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$false)]
    [string] $DomainNetBiosName)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function GetFileGitStatus(
        [string] $path =
            $(Throw "Value cannot be null: path"))
    {
        Write-Debug "GetFileGitStatus($path)..."

        [string] $output = $(git status --short -- $path)

        Write-Debug "Git status: $output"

        if ([string]::IsNullOrEmpty($output) -eq $true) {
            return "unmodified"
        }
        elseif ($output.StartsWith("A") -eq $true) {
            return "new file"
        }
        elseif ($output.StartsWith(" M ") -eq $true) {
            return "modified"
        }
        elseif ($output.StartsWith("?? ") -eq $true) {
            return "untracked"
        }
        else {
            throw "Unexpected output from 'git status': $output"
        }
    }

    Function RestoreGroupPolicyReport(
        [string] $reportName =
            $(Throw "Value cannot be null: reportName"),
        [string] $reportPath =
            $(Throw "Value cannot be null: reportPath"))
    {
        # Restore the specified group policy report if -- and only if -- the
        # report differs by the date/time the report was generated

        Write-Verbose ("Examining differences in group policy report" `
            + " ($reportName)...")

        [string] $gitStatus = GetFileGitStatus $reportPath

        if ($gitStatus -eq "modified") {
            Write-Verbose "Group policy report ($reportName) is modified..."

            [string] $reportPath = $_.FullName

            [string[]] $diff = $(git diff --text -- $reportPath)
            Write-Debug "diff:"
            Write-Debug ($diff -join [Environment]::NewLine)

            [string[]] $deletions = $diff | Where-Object { $_ -like '- *' }
            [string[]] $additions = $diff | Where-Object { $_ -like '+ *' }

            Write-Debug "deletions:"
            Write-Debug ($deletions -join [Environment]::NewLine)

            Write-Debug "additions:"
            Write-Debug ($additions -join [Environment]::NewLine)

            if ($deletions.Count -eq 1) {
                if ($additions.Count -eq 1) {
                    Write-Verbose "Group policy report ($reportName) may differ only by date."

                    [string] $matchString = "<td id=`"dtstamp`">Data collected on: "

                    # Check if the length of content deleted/added falls within the expected limit
                    # (i.e. we expect the "<td ...>Data collected on: ..." line of HTML that was modified to be less than or equal to 68 characters)
                    if (($deletions[0].Length -le 68) `
                            -and ($additions[0].Length -le 68)) {
                        if ($deletions[0].Contains($matchString) -eq $true) {
                            Write-Verbose "Deletion refers to report date"

                            if ($additions[0].Contains($matchString) -eq $true) {
                                Write-Verbose "Group policy report ($reportName) differs only by date."

                                git restore -- $reportPath

                                [PSCustomObject][Ordered] @{
                                    ReportName = $reportName
                                    Reason = "Differs only by report date"
                                    Path = $reportPath
                                }
                            }
                        }
                    }
                }
            }                    
        }
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

                RestoreGroupPolicyReport $reportName $reportPath
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
