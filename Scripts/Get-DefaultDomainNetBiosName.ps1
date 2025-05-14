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
    Get-ADDomain |
        Select-Object -ExpandProperty NetBIOSName
}
