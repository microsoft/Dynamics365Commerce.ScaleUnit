<#
.SYNOPSIS
Uninstalls the Commerce Scale Unit.
#>
$workspaceFolder = $Env:common_workspaceFolder

Write-Host
$InstallerPath = Join-Path $workspaceFolder "Download\CommerceStoreScaleUnitSetup.exe"
if (Test-Path -Path $InstallerPath) {
    Write-Host "Uninstalling the base product."
    & "$InstallerPath" uninstall
    if ($LastExitCode -ne 0) {
        Write-Host
        Write-Warning "The base product uninstallation has failed with exit code $LastExitCode. Please examine the above logs to fix a problem and start again."
        Write-Host
        exit $LastExitCode
    }
}
else {
    Write-Host "The base product installer was not found in "$workspaceFolder\Download\" directory."
}

