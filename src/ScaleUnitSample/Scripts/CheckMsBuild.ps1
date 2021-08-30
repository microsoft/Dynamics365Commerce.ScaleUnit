<#
.SYNOPSIS
Checks that msbuild is available.
#>
$msbuildPath = (get-command msbuild.exe -ErrorAction SilentlyContinue).Path
if (-not $msbuildPath)
{
    Write-Host
    Write-Warning "Unable to find 'msbuild.exe'. Please ensure the path to msbuild.exe is listed in the PATH environment variable and try again. To find the location of msbuild.exe execute the command 'where msbuild' in the Command Prompt or Developer Command Prompt for VS xx."
    Write-Host
    exit 1
}