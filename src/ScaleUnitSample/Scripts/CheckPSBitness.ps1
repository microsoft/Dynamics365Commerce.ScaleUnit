<#
.SYNOPSIS
Checks that powershell bitness is 64.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$psBitnessIs64 = [Environment]::Is64BitProcess
if (-not $psBitnessIs64)
{
    $bitnessErrorMessage = "The PowerShell version installed appears to be 32-bit. The scripts require the 64-bit PowerShell in order to correctly launch the installers needed to set up the debugging."
    $bitnessErrorMessage += "`r`n" + "Please download and install the 64-bit PowerShell from"
    $bitnessErrorMessage += "`r`n" + "https://github.com/PowerShell/PowerShell/releases/latest"
    $bitnessErrorMessage += "`r`n" + "The link to the version you need will look like 'PowerShell-<version>-win-x64.msi'."
    $bitnessErrorMessage += "`r`n" + "You will need to restart the VSCode after installing the correct version of the PowerShell."

    Write-Host
    Write-CustomError $bitnessErrorMessage
    Write-Host
    exit 1
}