<#
.SYNOPSIS
Gets the default NetBIOS domain name based on the current environment.

.DESCRIPTION
The `Get-DefaultDomainNetBiosName` cmdlet gets the NetBIOS domain name to use as
the default when working with Active Directory group policies.

.EXAMPLE
.\Get-DefaultDomainNetBiosName.ps1

CONTOSO
#>
[CmdletBinding()]
Param()

Begin
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
}

Process
{
    if (Get-Command Get-ADDomain -ErrorAction SilentlyContinue)
    {
        Get-ADDomain |
            Select-Object -ExpandProperty NetBIOSName
    }
    else {
        # If the Active Directory cmdlets are not available, default to the
        # domain for the current user
        $env:USERDOMAIN
    }
}
