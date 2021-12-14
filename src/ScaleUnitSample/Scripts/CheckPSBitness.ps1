<#
.SYNOPSIS
Checks that powershell bitness is 64.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$psBitnessIs64 = [Environment]::Is64BitProcess
if (-not $psBitnessIs64)
{
    $NewLine = [Environment]::NewLine
    $bitnessErrorMessage = "The PowerShell version installed appears to be 32-bit. The scripts require the 64-bit PowerShell in order to correctly launch the installers needed to set up the debugging."
    $bitnessErrorMessage += $NewLine + "Please download and install the 64-bit PowerShell from"
    $bitnessErrorMessage += $NewLine + "https://github.com/PowerShell/PowerShell/releases/latest"
    $bitnessErrorMessage += $NewLine + "The link to the version you need will look like 'PowerShell-<version>-win-x64.msi'."
    $bitnessErrorMessage += $NewLine + "You will need to restart the VS Code after installing the correct version of the PowerShell."

    Write-Host
    Write-CustomError $bitnessErrorMessage
    Write-Host
    exit 1
}