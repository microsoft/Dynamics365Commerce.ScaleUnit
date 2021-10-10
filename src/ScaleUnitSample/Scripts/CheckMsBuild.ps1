<#
.SYNOPSIS
Checks that msbuild is available.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$msbuildPath = (get-command msbuild.exe -ErrorAction SilentlyContinue).Path
if (-not $msbuildPath)
{
    Write-Host
    Write-CustomError "Unable to find 'msbuild.exe'. Please ensure the path to msbuild.exe is listed in the PATH environment variable and try again. To find the location of msbuild.exe execute the command 'where msbuild' in the Command Prompt or Developer Command Prompt for VS xx."
    Write-Host
    exit 1
}

$foundVersions = (Get-Command msbuild.exe -All -ErrorAction SilentlyContinue | Select-Object -Property Source, Version | Format-Table -HideTableHeaders | Out-String).Trim()

$msbuildVersionString = (& msbuild.exe /version) | Select -Last 1
$msbuildVersion = [Version]::new($msbuildVersionString)
if ($msbuildVersion.Major -lt 15) 
{
    $VersionMessage = (Get-Content (Join-Path "Scripts" "MsBuildMessage.txt")).Replace("<MsbuildVersionString>", $msbuildVersionString).Replace("<FoundVersions>", $foundVersions) | Out-String

    Write-Host
    Write-CustomError $VersionMessage
    Write-Host
    exit 1   
}
else
{
    Write-Host "Current version of Msbuild is '$msbuildVersionString'."
}