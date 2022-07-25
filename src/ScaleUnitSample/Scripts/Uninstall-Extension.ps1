<#
.SYNOPSIS
Uninstalls the Commerce Scale Unit Sample Extension.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$workspaceFolder = $Env:common_workspaceFolder
$NewLine = [Environment]::NewLine

Write-Host
$InstallerPath = Join-Path $workspaceFolder "Installer\bin\Debug\net472\ScaleUnit.Sample.Installer.exe"
if (Test-Path -Path $InstallerPath) {
    Write-Host "Uninstalling the extension."
    & "$InstallerPath" uninstall
    if ($LastExitCode -ne 0) {
        $message = "The extension uninstallation has failed with exit code $LastExitCode."
        $selfHostProcessName = "Microsoft.Dynamics.Retail.RetailServerSelfHost.AspNetCore"
        $selfHostProcess = Get-Process "$selfHostProcessName" -ErrorAction SilentlyContinue
        if (-not $selfHostProcess)
        {
            $message += " Please examine the above logs to fix a problem and then try uninstalling again."
        }
        else
        {
            # The self-host process is running, this may indicate that the debug session is still active
            # or the self-host process is running in the background.
            $message += $NewLine + "The process '$selfHostProcessName' is running now."
            $message += $NewLine + "If the debugger is attached to Scale Unit make sure to stop debugging session and then try uninstalling again."
        }
        Write-Host
        Write-CustomError $message
        Write-Host
        exit $LastExitCode
    }
}
else {
    Write-Host "The extension installer was not found in "$workspaceFolder\Installer\bin\Debug\net472\" directory."
}
