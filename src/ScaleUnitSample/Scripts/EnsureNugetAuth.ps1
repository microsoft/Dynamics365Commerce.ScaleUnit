<#
.SYNOPSIS
Ensure that nuget authentication is working.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$pluginsRoot = Join-Path (Join-Path $env:USERPROFILE ".nuget") "plugins"
$pluginDirectory = Join-Path pluginsRoot "CredentialProvider.Microsoft"

# Some nuget feeds may require authentication. The authentication is conducted via the nuget plugin
# that must be installed either automatically or manually.
# Certain environments may not allow downloading this plugin's binaries.
# Although it is not a problem when the public git repository is used (no authentication is needed there),
# the internal development or testing efforts may meet a certain problem at this point.
# One possible workaround is to invoke the "nuget restore" command that will automatically show
# the authentication dialog and wait for its completion.

# Check if the 'artifacts-credprovider' plugin is installed. 
if (-not (Test-Path -Path $pluginDirectory))
{
    if (Get-Command "nuget.exe" -ErrorAction SilentlyContinue) 
    {
        # This will show the authentication dialog for the feeds requiring the authentication.
        & nuget restore
    }
    else
    {
        Write-Warning "Both the 'artifacts-credprovider' plugin and the 'nuget.exe' command line utility were not found on the system. This may lead to the problems during the restoring of nuget packages from the 'https://msazure.pkgs.visualstudio.com/D365/_packaging/Dynamics365Commerce-Consumption' feed."
    }
}
else
{
    Write-Host "The 'artifacts-credprovider' plugin is already installed in '$pluginDirectory'."
}
