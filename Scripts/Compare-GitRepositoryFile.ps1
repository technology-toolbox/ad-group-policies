<#
.SYNOPSIS
Compares a file in the working tree with the Git index (staging area for the next
commit).

.DESCRIPTION
The `Compare-GitRepositoryFile` cmdlet is essentially a "thin wrapper" for
`git diff` that lists changes to a file relative to the index (staging area for
the next commit). In other words, it can be used to easily compare a file with
the most recent version committed to a Git repository. The output can be used
to evaluate any changes -- for example, to see if a generated HTML report
differs only by a date/time value (indicating when the report was generated).

.OUTPUTS
PSCustomObject. `Compare-GitRepositoryFile` returns an object with the following
properties:

- FileName
- DiffSummary
- Changes - an array of strings containing inserted (+) and deleted (-) lines

.EXAMPLE
./Compare-GitRepositoryFile.ps1 '..\CONTOSO\GP Reports\Default Domain Controllers Policy.html'

FileName                               DiffSummary
--------                               -----------
Default Domain Controllers Policy.html (no changes)

.EXAMPLE
./Compare-GitRepositoryFile.ps1 '..\CONTOSO\GP Reports\Default Domain Policy.html'

FileName                   DiffSummary
--------                   -----------
Default Domain Policy.html 1 insertion(+), 1 deletion(-)

.EXAMPLE
./Compare-GitRepositoryFile.ps1 '..\CONTOSO\GP Reports\Default Domain Policy.html' | select -ExpandProperty Changes

-    <td id="dtstamp">Data collected on: 4/30/2025 1:38:45 PM</td>
+    <td id="dtstamp">Data collected on: 4/30/2025 3:26:45 PM</td>
#>
[CmdletBinding()]
Param(
    [Parameter(Position=1, Mandatory=$true)]
    [string] $Path)

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Function CompareGitRepositoryFile(
        [string] $path =
            $(Throw "Value cannot be null: path"))
    {
        # Configure default display set for output type
        Update-TypeData `
            -TypeName GitRepositoryFile.Comparison `
            -DefaultDisplayPropertySet FileName, DiffSummary -Force

        [string] $fullPath = Resolve-Path $path
    
        Write-Verbose ("Examining differences in Git repository file" `
            + " ($fullPath)...")
        
        [string] $fileName = [System.IO.Path]::GetFileName($fullPath)
        Write-Debug "fileName: $fileName"

        [string] $diffSummary = $(git diff --shortstat --text -- $fullPath)
        Write-Debug "diffSummary: $diffSummary"

        if ([string]::IsNullOrEmpty($diffSummary) -eq $true) {
            $diffSummary = "(no changes)"
        }

        if ($diffSummary.StartsWith(" 1 file changed, ") -eq $true) {
            $diffSummary = $diffSummary.Substring(" 1 file changed, ".Length)
        }

        [string[]] $fileChanges = $null

        if ($diffSummary -ne "(no changes)") {
            Write-Verbose "File ($fileName) is modified..."

            [string[]] $diff = $(git diff --text -- $path)
            Write-Debug "diff:"
            Write-Debug ($diff -join [Environment]::NewLine)

            <# Example "diff" (patch) from Git:

diff --git a/CONTOSO/GP Reports/Default Domain Policy.html b/CONTOSO/GP Reports/Default Domain Policy.html
index 15c02dd..69104cb 100644
--- a/CONTOSO/GP Reports/Default Domain Policy.html
+++ b/CONTOSO/GP Reports/Default Domain Policy.html
@@ -1385,7 +1385,7 @@ function showComponentProcessingDetails(srcElement) {
 </div><table class="title" >
 <tr><td colspan="2" class="gponame">Default Domain Policy</td></tr>
 <tr>
-    <td id="dtstamp">Data collected on: 4/30/2025 1:38:45 PM</td>
+    <td id="dtstamp">Data collected on: 4/30/2025 3:26:45 PM</td>
     <td><div id="objshowhide" tabindex="0" onclick="objshowhide_onClick();return false;"></div></td>
 </tr>
 </table>
 #>
            [string[]] $fileChanges = $diff |
                Select-Object -Skip 4 | # skip the first 4 lines of the "patch" (to avoid lines beginning with "---" and "+++")
                Where-Object { $_ -match '^[+-].*$' }

            Write-Debug "fileChanges:"
            Write-Debug ($fileChanges -join [Environment]::NewLine)
        }

        [PSCustomObject] $output = [PSCustomObject][Ordered] @{
            FileName = $fileName
            DiffSummary = $diffSummary
            Changes = $fileChanges
        }

        $output.PSTypeNames.Insert(0, 'GitRepositoryFile.Comparison')

        $output
    }
}

Process
{
    CompareGitRepositoryFile $Path
}
