<#
.SYNOPSIS
Installs the Commerce Scale Unit and extension.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$workspaceFolder = $Env:common_workspaceFolder
$NewLine = [Environment]::NewLine

$baseProductInstallRoot = "${Env:Programfiles}\Microsoft Dynamics 365\10.0\Commerce Scale Unit"
$extensionInstallPath = Join-Path $baseProductInstallRoot "Extensions\ScaleUnit.Sample.Installer"

if (-not (Test-Path -Path "$workspaceFolder\Download\CommerceStoreScaleUnitSetup.exe")) {
    Write-CustomError "The base product installer 'CommerceStoreScaleUnitSetup.exe' was not found in `"$workspaceFolder\Download\`" directory. Download the 'Commerce Scale Unit (SEALED)' installer from Lifecycle Service (LCS) > Shared 'asset library > Retail Self-service package (https://lcs.dynamics.com/V2/SharedAssetLibrary ) and copy it to the `"$workspaceFolder\Download\`" directory."
    Write-Host
    exit 1
}

if ($Env:baseProduct_UseSelfHost -eq "true")
{
    $selfHostBanner = Get-Content (Join-Path "Scripts" "Banner.txt") -Raw
    Write-Host $selfHostBanner | Out-String
    # Give the user a chance to see the banner (500ms should be enough).
    [System.Threading.Thread]::Sleep(500)
}

Write-Host

# Determine the machine name. It will be used to query the installed Retail Server.
$MachineName = [System.Net.Dns]::GetHostEntry("").HostName

# Check if the Retail Server certificate was provided
$CertPrefix = "store:///My/LocalMachine?FindByThumbprint="
$RetailServerCertificateProvided = $false
if ($Env:baseProduct_RetailServerCertFullPath -and $Env:baseProduct_RetailServerCertFullPath -ne $CertPrefix) {
    $RetailServerCertificateProvided = $true
    Write-Host "Retail Server certificate was provided: '$Env:baseProduct_RetailServerCertFullPath'"
}
else {
    Write-Host "Retail Server certificate was not provided"
}

Write-Host
$port = $Env:baseProduct_Port
$baseProductRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Dynamics\Commerce\10.0\Commerce Scale Unit\Configuration'
if (-not (Test-Path -Path $baseProductRegistryPath)) {
    # The config file path may be passed as absolute or relative
    $Config = $Env:baseProduct_Config
    if ($Config) {
        # This cannot be merged into single "if" expression as it tries to test an empty path.
        if (-not (Test-Path -Path $Config)) {
            # If the config path is not an absolute path (not exists), try to search the filename in /Download folder
            $RelativeConfigPath = Join-Path "$workspaceFolder" (Join-Path "Download" "$Config")
            if (Test-Path -Path $RelativeConfigPath) {
                Write-Host "The config file was found in /Download folder. Using the file `"$RelativeConfigPath`"."
                $Config = $RelativeConfigPath
            }
        }
    }

    if (-not $RetailServerCertificateProvided)
    {
        # If the RS certificate was not configured for the Self-Host flavor, just provide the self-signed one
        if ($Env:baseProduct_UseSelfHost -eq "true")
        {
                Write-Host "Ensuring the certificate for Self-Hosted Retail Server"
                $RetailServerCertThumbprint = & "$workspaceFolder\Scripts\EnsureCertificate.ps1"
                $Env:baseProduct_RetailServerCertFullPath = $CertPrefix + $RetailServerCertThumbprint
        }
    }

    Write-Host "Installing the base product."
    $installerCommand = "$workspaceFolder\Download\CommerceStoreScaleUnitSetup.exe"
    $installerArgs = ,"install" # This is an array
    # Add each option as a two-element array of name and value. No need to quote the values here.
    if ($Env:baseProduct_Port) { $installerArgs += $("--Port", $Env:baseProduct_Port) }
    if ($Env:baseProduct_AsyncClientCertFullPath -and $Env:baseProduct_AsyncClientCertFullPath -ne $CertPrefix) { $installerArgs += $("--AsyncClientCertFullPath", $Env:baseProduct_AsyncClientCertFullPath) }
    if ($Env:baseProduct_SslCertFullPath -and $Env:baseProduct_SslCertFullPath -ne $CertPrefix) { $installerArgs += $("--SslCertFullPath", $Env:baseProduct_SslCertFullPath) }
    if ($Env:baseProduct_RetailServerCertFullPath) { $installerArgs += $("--RetailServerCertFullPath", $Env:baseProduct_RetailServerCertFullPath) }
    if ($Env:baseProduct_AsyncClientAadClientId) { $installerArgs += $("--AsyncClientAadClientId", $Env:baseProduct_AsyncClientAadClientId) }
    if ($Env:baseProduct_RetailServerAadClientId) { $installerArgs += $("--RetailServerAadClientId", $Env:baseProduct_RetailServerAadClientId) }
    if ($Env:baseProduct_CposAadClientId) { $installerArgs += $("--CposAadClientId", $Env:baseProduct_CposAadClientId) }
    if ($Env:baseProduct_RetailServerAadResourceId) { $installerArgs += $("--RetailServerAadResourceId", $Env:baseProduct_RetailServerAadResourceId) }
    if ($Env:baseProduct_TransactionServiceAzureAuthority) { $installerArgs += $("--TransactionServiceAzureAuthority", $Env:baseProduct_TransactionServiceAzureAuthority) }
    if ($Env:baseProduct_TransactionServiceAzureResource) { $installerArgs += $("--TransactionServiceAzureResource", $Env:baseProduct_TransactionServiceAzureResource) }
    if ($Env:baseProduct_StoresystemAosUrl) { $installerArgs += $("--StoresystemAosUrl", $Env:baseProduct_StoresystemAosUrl) }
    if ($Env:baseProduct_StoresystemChannelDatabaseId) { $installerArgs += $("--StoresystemChannelDatabaseId", $Env:baseProduct_StoresystemChannelDatabaseId) }
    if ($Env:baseProduct_EnvironmentId) { $installerArgs += $("--EnvironmentId", $Env:baseProduct_EnvironmentId) }
    if ($Env:baseProduct_AsyncClientAppInsightsInstrumentationKey) { $installerArgs += $("--AsyncClientAppInsightsInstrumentationKey", $Env:baseProduct_AsyncClientAppInsightsInstrumentationKey) }
    if ($Env:baseProduct_ClientAppInsightsInstrumentationKey) { $installerArgs += $("--ClientAppInsightsInstrumentationKey", $Env:baseProduct_ClientAppInsightsInstrumentationKey) }
    if ($Env:baseProduct_CloudPosAppInsightsInstrumentationKey) { $installerArgs += $("--CloudPosAppInsightsInstrumentationKey", $Env:baseProduct_CloudPosAppInsightsInstrumentationKey) }
    if ($Env:baseProduct_HardwareStationAppInsightsInstrumentationKey) { $installerArgs += $("--HardwareStationAppInsightsInstrumentationKey", $Env:baseProduct_HardwareStationAppInsightsInstrumentationKey) }
    if ($Env:baseProduct_WindowsPhoneAppInsightsInstrumentationKey) { $installerArgs += $("--WindowsPhoneAppInsightsInstrumentationKey", $Env:baseProduct_WindowsPhoneAppInsightsInstrumentationKey) }
    if ($Env:baseProduct_AadTokenIssuerPrefix) { $installerArgs += $("--AadTokenIssuerPrefix", $Env:baseProduct_AadTokenIssuerPrefix) }
    if ($Env:baseProduct_TenantId) { $installerArgs += $("--TenantId", $Env:baseProduct_TenantId) }
    # Don't use this flag in production scenarios without realizing all security risks
    # https://docs.microsoft.com/en-us/sql/relational-databases/native-client/features/using-encryption-without-validation?view=sql-server-ver15
    $installerArgs += $("--TrustSqlServerCertificate")
    $installerArgs += $("-v", "Trace")
    if ($Env:baseProduct_SqlServerName) { $installerArgs += $("--SqlServerName", $Env:baseProduct_SqlServerName) }
    if ($Config) { $installerArgs += $("--Config", $Config) }
    if ($Env:baseProduct_UseSelfHost -eq "true")
    {
        $installerArgs += $("--UseSelfHost")
        $installerArgs += $("--SkipSelfHostProcessStart")
    }

    # If the Port parameter was not supplied, choose the first available tcp port and pass it to the base product installer,
    # this will work for both IIS and Self-Host flavor.
    if (-not $Env:baseProduct_Port)
    {
        # Winsock performs an automatic search for a free TCP port if we pass 0 port number to a socket "bind" function,
        # in .NET we use the TcpListener to invoke this functionality.
        # Useful links:
        # https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-bind#remarks
        # https://referencesource.microsoft.com/#system/net/System/Net/Sockets/Socket.cs,950
        # https://referencesource.microsoft.com/#system/net/System/Net/Sockets/TCPListener.cs,185

        $loopback = [System.Net.IPAddress]::Loopback
        $listener = New-Object -TypeName System.Net.Sockets.TcpListener $loopback,0
        $listener.Start()
        $port = "$($listener.LocalEndpoint.Port)"
        $listener.Stop()

        Write-Host "The port was not supplied, automatically assigning the port number $port"

        $installerArgs += $("--Port", $port)
    }

    Write-Host
    Write-Host "The base product installation command is:"
    Write-Host "$installerCommand $installerArgs"

    & $installerCommand $installerArgs

    if ($LastExitCode -ne 0) {
        Write-Host
        Write-CustomError "The base product installation has failed with exit code $LastExitCode. Please examine the logs to fix a problem and start again. If the logs are not available in the output, locate them under %PROGRAMDATA%\Microsoft Dynamics 365\10.0\logs."
        Write-Host
        exit $LastExitCode
    }

    Write-Host
    Write-Host "Retrieve the channel demo data package."

    $ChannelDataPackageName = "Microsoft.Dynamics.Commerce.Database.ChannelDemoData"
    $ChannelDataPath = Join-Path (Join-Path "$workspaceFolder" "Download") "ChannelData"
    $LatestPackage = ""
    $CommandExitCode = 0

    & "$workspaceFolder\Scripts\RestoreChannelDataDotnet.ps1" $ChannelDataPackageName $ChannelDataPath ([ref]$LatestPackage) ([ref]$CommandExitCode)
    if ($CommandExitCode -ne 0) {
        # If the restore via "dotnet restore" has failed,
        # trying the fallback approach: obtain the Channel Data via the nuget.exe
        $LatestPackageDotnet = $LatestPackage

        $LatestPackageNuget = ""
 
        & "$workspaceFolder\Scripts\RestoreChannelDataNuget.ps1" $ChannelDataPackageName $ChannelDataPath ([ref]$LatestPackageNuget)
        if (-not $LatestPackageNuget) {
            # nuget.exe has failed also, no package found
            Write-Warning "Retrieving the package via 'nuget.exe' command has failed."
        }
        else
        {
            $usePackageRetrievedByDotnet = $false
            if ($LatestPackageDotnet)
            {
                Write-Host "Packages are retrieved by both the 'dotnet' and 'nuget.exe' commands. Versions are '$($LatestPackageDotnet.Version)' and '$($LatestPackageNuget.Version)' correspondingly."
                # Compare the versions obtained by both commands to return the latest.
                if ($LatestPackageDotnet.Version -gt $LatestPackageNuget.Version)
                {
                    $usePackageRetrievedByDotnet = $true
                }
            }

            if ($usePackageRetrievedByDotnet)
            {
                $LatestPackage = $LatestPackageDotnet
                Write-Host "Using the package version '$($LatestPackageDotnet.Version)' retrieved by the 'dotnet' command."
            }
            else
            {
                $LatestPackage = $LatestPackageNuget
                Write-Host "Using the package version '$($LatestPackageNuget.Version)' retrieved by the 'nuget.exe' command."
            }
        }
    }

    if (-not $LatestPackage)
    {
        Write-Host
        Write-CustomError "Unable to download channel demo data package. Please examine the above logs to fix a problem and start again."
        Write-Host
        exit 1
    }
    else
    {
        Write-Host "The '$ChannelDataPackageName' package was found in folder '$($LatestPackage.FullName)'."
    }

    $LatestPackagePath = $LatestPackage.FullName
    $DataPath = Join-Path $LatestPackagePath "contentFiles"

    if ($Env:baseProduct_UseSelfHost -eq "true") {
        Write-Host
        Write-Host "Deploy the channel data for the self-hosted base product."
        $installerArgs = , "applyChannelData"
        $installerArgs += $("--DataPath", $DataPath)
        Write-Host "The channel data deployment command is:"
        Write-Host "$installerCommand $installerArgs"

        & $installerCommand $installerArgs

        if ($LastExitCode -ne 0) {
            Write-Host
            Write-CustomError "The channel data deployment has failed with exit code $LastExitCode. Please examine the above logs to fix a problem and start again."
            Write-Host
            exit $LastExitCode
        }
    }
}
else {
    Write-Host "The base product is already installed and has the registry key at '$baseProductRegistryPath'."

    # Check if the installed flavor matches the current project settings
    $flavorKey = "UseSelfHost"
    $flavorRegistryValue = $null
    if ((Get-Item $baseProductRegistryPath).Property -contains $flavorKey) {
        $flavorRegistryValue = (Get-ItemProperty -Path $baseProductRegistryPath -Name "$flavorKey")."$flavorKey"
    }
    else {
        Write-Warning "The base product flavor configuration key '$flavorKey' is missing at '$baseProductRegistryPath'."
    }

    # The flavor value may be "true", "false", or null (for the outdated product versions).
    $installedFlavorIsSelfHost = $flavorRegistryValue -eq "true"

    # The project settings value may be anything, but only the "true" is recognized as a command to install the SelfHost flavor.
    $targetFlavorIsSelfHost = $Env:baseProduct_UseSelfHost -eq "true"

    if (-not ($installedFlavorIsSelfHost -eq $targetFlavorIsSelfHost)) {
        $FlavorErrorMessage = "The current installation flavor (UseSelfHost is '$flavorRegistryValue') does not match the one set in the project (baseProduct_UseSelfHost is '$Env:baseProduct_UseSelfHost')."
        $FlavorErrorMessage += $NewLine + "Prior retrying, please uninstall the extension and the base product by using the VS Code task 'uninstall' (Terminal/Run Task/uninstall)."

        Write-Host
        Write-CustomError $FlavorErrorMessage
        Write-Host
        exit 1
    }

    # An additional check for the automatically created Retail Server certificate.
    # Only performed for Self-Host flavor if the certificate was not provided by a user.
    if (-not $RetailServerCertificateProvided -and $Env:baseProduct_UseSelfHost -eq "true") {
        $ExistingCertThumbprint = & "$workspaceFolder\Scripts\EnsureCertificate.ps1" -CheckOnly
        if ($null -eq $ExistingCertThumbprint) {
            Write-Host
            Write-CustomError "Sample certificate 'Dynamics 365 Self-Hosted Sample Retail Server' has not been found which could take place if the certificate was manually removed or never created. Run the task 'uninstall' to reset the state of the deployment so the certificate is automatically created next time."
            Write-Host
            exit 1
        }
        else {
            Write-Host "Sample certificate 'Dynamics 365 Self-Hosted Sample Retail Server' has been found with a thumbprint '$ExistingCertThumbprint'."
        }
    }

    # Read the port assigned to the RetailServer site during the last successful installation
    $portKey = "Port"
    $portRegistryValue = $null
    if ((Get-Item $baseProductRegistryPath).Property -contains $portKey) {
        $portRegistryValue = (Get-ItemProperty -Path $baseProductRegistryPath -Name "$portKey")."$portKey"
        $port = $portRegistryValue
    }
    else {
        Write-Warning "The base product port configuration key '$portKey' is missing at '$baseProductRegistryPath'. This may indicate that the base product needs to be reinstalled by issuing VS Code task 'install' (Menu 'Run Task...' -> install)."
    }
}

Write-Host
Write-Host "Installing the extension."
& "$workspaceFolder\Installer\bin\Debug\net472\ScaleUnit.Sample.Installer.exe" install

if ($LastExitCode -ne 0) {
    Write-Host
    Write-CustomError "The extension installation has failed with exit code $LastExitCode. Please examine the above logs to fix a problem and start again."
    Write-Host
    exit $LastExitCode
}

Write-Host
Write-Host "Copy the binary and symbol files into extensions folder."
Copy-Item -Path (Join-Path "$workspaceFolder" "\CommerceRuntime\bin\Debug\net6.0\*.pdb") -Destination  (Join-Path "$extensionInstallPath" "\")

if ($Env:baseProduct_UseSelfHost -ne "true") {
    # IIS deployment requires the additional actions to start debugging

    $RetailServerRoot = "https://$($MachineName):$port/RetailServer"

    # Open a default browser with a healthcheck page
    $RetailServerHealthCheckUri = "$RetailServerRoot/healthcheck?testname=ping"
    Write-Host "Open the IIS site at '$RetailServerHealthCheckUri' to start the process to attach debugger to."
    Start-Process -FilePath $RetailServerHealthCheckUri
}
# SIG # Begin signature block
# MIIoQwYJKoZIhvcNAQcCoIIoNDCCKDACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9tAmEJjHR/2HU
# fG4hkomgrr3+SdC7U3bV/5m6fcWapqCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGiMwghofAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP6NdU08NRoNoLhjViwvqXhQ
# n0PusfKGN0+TCkY43y+DMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAyfRPmJuXkTwjRnF446KcKEINGghMETSjpvXD+HVTXWAS7HNulf+lm8c7
# 4ky6G05S+2DHmU3gNC+XHDfvAoc3qg/PcgKZDOUXcn2ieGUC6m2IgeZAHEYsyg+6
# NiYfY/54RTkilZDs5dy1KpnZk5OM98+CY1QUj8vkrD0iZpAGsg/1rpoUeqLsPYYh
# 0azG8vGZ+Ecvl0OqbLOgW51pp2t7Z/AXRuvGQ2J+NMT8kgX/Jx87jPfcUEfbnKmW
# WYIftSz6lqzPMz3DVLj6H6y+i8V2TmgpJaVVWwvjCUQiUXI9SG4IDTrETCW96rSZ
# CX7mE35RbrOTkH4TSKeZKS0PvLg5YqGCF60wghepBgorBgEEAYI3AwMBMYIXmTCC
# F5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsq
# hkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBPw/VwP5NbG/yE9jjPlztEPA+hF9bhYKuOOiA3OKpkkQIGZsaQr0Qn
# GBMyMDI0MDkxODEwMTIyOC4wNzlaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVT
# Tjo2NTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAAB9ZkJlLzxxlCMAAEAAAH1MA0G
# CSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI0
# MDcyNTE4MzEwMVoXDTI1MTAyMjE4MzEwMVowgdMxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9w
# ZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjY1MUEt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAzO90cFQTWd/WP84IT7JM
# IW1fQL61sdfgmhlfT0nvYEb2kvkNF073ZwjveuSWot387LjE0TCiG93e6I0HzIFQ
# BnbxGP/WPBUirFq7WE5RAsuhNfYUL+PIb9jJq3CwWxICfw5t/pTyIOHjKvo1lQOT
# WZypir/psZwEE7y2uWAPbZJTFrKen5R73x2Hbxy4eW1DcmXjym2wFWv10sBH40aj
# Jfe+OkwcTdoYrY3KkpN/RQSjeycK0bhjo0CGYIYa+ZMAao0SNR/R1J1Y6sLkiCJO
# 3aQrbS1Sz7l+/qJgy8fyEZMND5Ms7C0sEaOvoBHiWSpTM4vc0xDLCmc6PGv03CtW
# u2KiyqrL8BAB1EYyOShI3IT79arDIDrL+de91FfjmSbBY5j+HvS0l3dXkjP3Hon8
# b74lWwikF0rzErF0n3khVAusx7Sm1oGG+06hz9XAy3Wou+T6Se6oa5LDiQgPTfWR
# /j9FNk8Ju06oSfTh6c03V0ulla0Iwy+HzUl+WmYxFLU0PiaXsmgudNwVqn51zr+B
# i3XPJ85wWuy6GGT7nBDmXNzTNkzK98DBQjTOabQXUZ884Yb9DFNcigmeVTYkyUXZ
# 6hscd8Nyq45A3D3bk+nXnsogK1Z7zZj6XbGft7xgOYvveU6p0+frthbF7MXv+i5q
# cD9HfFmOq4VYHevVesYb6P0CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBRV4Hxb9Uo0
# oHDwJZJe22ixe2B1ATAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBf
# BgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmww
# bAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAcwxmVPaA9xHf
# fuom0TOSp2hspuf1G0cHW/KXHAuhnpW8/Svlq5j9aKI/8/G6fGIQMr0zlpau8jy8
# 3I4zclGdJjl5S02SxDlUKawtWvgf7ida06PgjeQM1eX4Lut4bbPfT0FEp77G76hh
# ysXxTJNHv5y+fwThUeiiclihZwqcZMpa46m+oV6igTU6I0EnneotMqFs0Q3zHgVV
# r4WXjnG2Bcnkip42edyg/9iXczqTBrEkvTz0UlltpFGaQnLzq+No8VEgq0UG7W1E
# LZGhmmxFmHABwTT6sPJFV68DfLoC0iB9Qbb9VZ8mvbTV5JtISBklTuVAlEkzXi9L
# IjNmx+kndBfKP8dxG/xbRXptQDQDaCsS6ogLkwLgH6zSs+ul9WmzI0F8zImbhnZh
# UziIHheFo4H+ZoojPYcgTK6/3bkSbOabmQFf95B8B6e5WqXbS5s9OdMdUlW1gTI1
# r5u+WAwH2KG7dxneoTbf/jYl3TUtP7AHpyck2c0nun/Q0Cycpa9QUH/Dy01k6tQo
# mNXGjivg2/BGcgZJ0Hw8C6KVelEJ31xLoE21m9+NEgSKCRoFE1Lkma31SyIaynbd
# YEb8sOlZynMdm8yPldDwuF54vJiEArjrcDNXe6BobZUiTWSKvv1DJadR1SUCO/Od
# 21GgU+hZqu+dKgjKAYdeTIvi9R2rtLYwggdxMIIFWaADAgECAhMzAAAAFcXna54C
# m0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZp
# Y2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMy
# MjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51
# yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY
# 6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9
# cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN
# 7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDua
# Rr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74
# kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2
# K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5
# TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZk
# i1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9Q
# BXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3Pmri
# Lq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUC
# BBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJl
# pxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9y
# eS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUA
# YgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# 1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIw
# MTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0w
# Ni0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/yp
# b+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulm
# ZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM
# 9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECW
# OKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4
# FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3Uw
# xTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPX
# fx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVX
# VAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGC
# onsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU
# 5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEG
# ahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVT
# Tjo2NTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaIjCgEBMAcGBSsOAwIaAxUAJsAKu48NbR5YRg3WSBQCyjzdkvaggYMw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsF
# AAIFAOqUpmMwIhgPMjAyNDA5MTgwMTA3NDdaGA8yMDI0MDkxOTAxMDc0N1owdDA6
# BgorBgEEAYRZCgQBMSwwKjAKAgUA6pSmYwIBADAHAgEAAgIejDAHAgEAAgITxDAK
# AgUA6pX34wIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQCVHYy66H5knksj
# KpxzWMzaat4prJ/AVMQso0htXVxOkqEFhwAjxaoQCbMI46M8iSRN0CQw9Td1CKmK
# 4KN9IO6znX/0OB/Iikosm22PNvxtvzZoxU53cEOLqev12IWrPJK1+PEig3t6evCe
# RMTVzv1JnCcIDUDny8Gf0CN7KAMBHcxo6jg6WREh9B0gS/LNFQ7motf4+kYt2UHP
# 4Mtw+FbBk1qabbFmcy6G3Upc+qyP0iRiP1rumcW1UvuViFsoMF6gssARrVbYoJFx
# kBE8IDoKojdCvXb9EvgLXKL8+JIzPD07jLdf7e0n+vFVApT2J0ewMFxMQzyR0gN1
# 6QbuFSIwMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAH1mQmUvPHGUIwAAQAAAfUwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgvrZIi/QhqrRj
# 1/7H/8V4IJVhoBwb1SdM7w7887kkuzYwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHk
# MIG9BCDB1vLSFwh09ISu4kdEv4/tg9eR1Yk8w5x7j5GThqaPNTCBmDCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB9ZkJlLzxxlCMAAEAAAH1
# MCIEIP85joGyy/n/TSKpc2HtokjwHxoigV84uNorJ5BkglrLMA0GCSqGSIb3DQEB
# CwUABIICAMEafrJj4bpyAJhL6lp9MrFn6Q1HtzmEDbCJPwl5/P0ZFy5cYa+nYTYI
# uX7N3Okz62pGfv/9tFN24eAO5UPO8+4nRpjieq3G0vYAKkp+cyFsFmHjAgJIW94y
# 15IO5iJg/9WMOBsKS8t9g+WrZm5YepCEPecRp+Fb4p6/s7Wl/Ya6t61tkf9oUBcE
# djWJS1HvO7CMcj1MwxStJA+Dh7Jqc0HxZ7972FrGa5khbmgDlvSmQTUbNiB1jZmg
# rt+lDDTMDDBwO6h2ZaQqUMluPjAnWShBLXy8Mjev7D4KeVQemkXU70AJ7ivFVrH3
# F93PlsOYH9SxZ8TOIBXvLRQyuO3gNeicx1qCeIr3ax6N2HXScJKOWhHi2a034yB/
# jWbEdS5/I3lKgFgeio+VLBMY8bA8uLZU1AAKOIMCHyp1V9jHjUeCCmTmo97Iz2s3
# mlX5F5DlJ4wcVWWg8SoNjSX3WCA2IaQzlRTujxLdNWdHmmRu8JNzPB9XVObOM5nP
# pV8dqdG1FyAWyrS3E72BfS2A6I/LkLJIj00LywbQExnZKBWBghek2UelIlK0u/Iy
# S2oxIt+q7+i0Yz2Ic7Sca9kqQ30PIR8BcS+bcqcYvt+GJtc2UfRgGQaONUivipZs
# XCDjXjCdpyIDUuDNVxH1kBo9zUDUyS4qkdN8nfj5UVFnJLeFD0Jz
# SIG # End signature block
