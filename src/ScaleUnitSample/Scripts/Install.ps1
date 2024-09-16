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
# MIIoQgYJKoZIhvcNAQcCoIIoMzCCKC8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGiIwghoeAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
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
# CX7mE35RbrOTkH4TSKeZKS0PvLg5YqGCF6wwgheoBgorBgEEAYI3AwMBMYIXmDCC
# F5QGCSqGSIb3DQEHAqCCF4UwgheBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBPw/VwP5NbG/yE9jjPlztEPA+hF9bhYKuOOiA3OKpkkQIGZsaIl/Ap
# GBIyMDI0MDkxNjEwMTIzOS4yM1owBIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVs
# YW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNO
# OjU1MUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIB0UVZmBDMQk8AAQAAAgEwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjQw
# NzI1MTgzMTIyWhcNMjUxMDIyMTgzMTIyWjCB0zELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046NTUxQS0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1at/4fMO7uyTnTLlgeF4I
# gkbS7FFIUVwc16T5N31mbImPbQQSNpTwkMm7mlZzik8CwEjfw0QAnVv4oGeVK2pT
# y69cXiqcRKEN2Lyc+xllCxNkMpYCBQzaJlM6JYi5lwWzlkLz/4aWtUszmHVj2d8y
# HkHgOdRA5cyt6YBP0yS9SGDe5piCaouWZjI4OZtriVdkG7XThIsAWxc5+X9MuGlO
# hPjrLuUj2xsj26rf8B6uHdo+LaSce8QRrOKVd6ihc0sLB274izqjyRAui5SfcrBR
# CbRvtpS2y/Vf86A+aw4mLrI3cthbIchK+s24isniJg2Ad0EG6ZBgrwuNmZBpMoVp
# zGGZcnSraDNoh/EXbIjAz5X2xCqQeSD9D6JIM2kyvqav87CSc4QiMjSDpkw7KaK+
# kKHMM2g/P2GQreBUdkpbs1Xz5QFc3gbRoFfr18pRvEEEvKTZwL4+E6hSOSXpQLz9
# zSG6qPnFfyb5hUiTzV7u3oj5X8TjJdF55mCvQWFio2m9OMZxo7ZauQ/leaxhLsi8
# w8h/gMLIglRlqqgExOgAkkcZF74M+oIeDpuYY+b3sys5a/Xr8KjpL1xAORen28xJ
# JFBZfLgq0mFl+a4PPa+vWPDg16LHC4gMbDWa1X9N1Ij6+ksl9SIuX9v3D+0kH3YE
# AtBPx7Vgfw2mF06jXELCRwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFLByr1uWoug8
# +JWvKb2YWYVZvLJSMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQA6NADLPRxXO1MU
# apdfkktHEUr87+gx7nm4OoQLxV3WBtwzbwoFQ+C9Qg9eb+90M3YhUGRYebAKngAh
# zLh1m2S5SZ3R+e7ppP0y+jWd2wunZglwygUsS3dO2uIto76Lgau/RlQu1ZdQ8Bb8
# yflJyOCfTFl24Y8EP9ezcnv6B6337xm8GKmyD83umiKZg5WwfEtx6btXld0w2zK1
# Ob+4KiaEz/CBHkqUNhNU0BcHFxIox4lqIPdXX4eE2RWWIyXlU4/6fDnFYXnm72Hp
# 4XYbt4E+pP6pIVD6tAJB0is3TIbVA308muiC4r4UlAl1DN18PdFZWxyIHKBthpmV
# PVwYkjUjJDvgNDRQF1Ol94azKsRD08jxDKpUupvarsu0joMkw2mFi76Ov//SymvV
# RW/IM+25GdsZBE2LUI7AlyP05iaWQWAo14J9sNPtTe4Q69aiZ6RfrRj+bm61FxQ9
# V4A92GQH4PENp6/cnXLAM13K73XWcBU+BGTIqAwrdRIsbfsR2Vq0OTwXK4KvHi2I
# fKoc7fATrE/DfZDx7++a5A+gFm5fepR6gUizJkR6cerZJwy6eFypbfZJRUCLmhnh
# ned/t0CA1q7bU0Q/CBb7bCSs2oODsenzIfKg4puAQG7pERBu9J9nkqHg9X5LaDF/
# a6roahgOeWoAE4xjDPfT0hKLRs8yHzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
# SZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIy
# NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXI
# yjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjo
# YH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1y
# aa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v
# 3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pG
# ve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viS
# kR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYr
# bqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlM
# jgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSL
# W6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AF
# emzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIu
# rQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIE
# FgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWn
# G1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEW
# M2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5
# Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBi
# AEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV
# 9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAx
# MC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv
# 6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZn
# OlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1
# bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4
# rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU
# 6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDF
# NLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/
# HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdU
# CbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKi
# excdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTm
# dHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZq
# ELQdVTNYs6FwZvKhggNWMIICPgIBATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVs
# YW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNO
# OjU1MUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQDX7bpxH/IfXTQOI0UZaG4C/atgGqCBgzCB
# gKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUA
# AgUA6pH7ZTAiGA8yMDI0MDkxNjAwMzM0MVoYDzIwMjQwOTE3MDAzMzQxWjB0MDoG
# CisGAQQBhFkKBAExLDAqMAoCBQDqkftlAgEAMAcCAQACAga+MAcCAQACAhSYMAoC
# BQDqk0zlAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBALM/zJZZIGm4zhN/
# 1cY0hYAHdvlhTLRMNF8lVTYjOH/YP6gQLCP9ZY3gebWrpxvIZcURiwNYBsMpNukw
# AgaWXWnqVodSG0vDC6ONAd0LuRMPM4Lb5lOkcTObnEnMrDhlGXi75bUoRFAF7FjO
# PmwrBL9WKWJEJ+6yMDh9Ccafiryt6WZ+PCNSmypx3qemTIdFDekVm/Zzw4jXVvh0
# s3uEgO7Sax+KCKHQOeFpvdp9VXHMPE6WOSU1uN2h2B/ohwI+vtzlHeJE0PdEi52A
# /e9b5TfDBMS7RbDIPb5HUjriGQtIf6QfhjsV9kFyCIG0RCJMvJYE/H0+H8/APzpD
# +fswJ3oxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAgHRRVmYEMxCTwABAAACATANBglghkgBZQMEAgEFAKCCAUowGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCB5O2QPeXGJ51OK
# /uRBe4I+nKN+NTUkFD/76rGy+jc/AjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQw
# gb0EIFhrsjpMlBFybHQdpJNZl0mCjB2uX35muvSkh2oe1zgjMIGYMIGApH4wfDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIB0UVZmBDMQk8AAQAAAgEw
# IgQgeRNHHtu5e97T1MS7WYCUkatHnPV81ECZaM5GgDC82lcwDQYJKoZIhvcNAQEL
# BQAEggIAp+9AUY6fp15RJGAhbn3vJdsL+ZV+qVgbjM6bi15GyrC16gybKudNWtlB
# ObpRmzGADurCvBQIL6NK2d3c7hT9GPDz/J1HdjfwnLOtXK5ck0d3a5F+0BXXEKfd
# 358TON4J4iXUs8NAFTb1ckwcv3Oee6o0DUXih6Dp4vq5e7jwOj8zVwfEu5EbQHwq
# tUWr7HIshpw5qsa4PbJoUNjtb/DovHeXWBx8Vu5HaPH2n60j13hNXM99Az9/eaLR
# Kx7N2SCsSnpVcF8HHxt7S2zuXhDmLqGuMXn7Un6frRnMdN0Qir2+dYCBLlWmeJlY
# HJPnPAGJhiUvEkjFAEQ4T922IxV2cGXuZi/V6Y/Y3cFybVuXsHyUbMQAHfcFfAR3
# JnWXOmXMAm9DJsg/fwVPh8DevTOrIeEMdVisLB3w4d+KzX6/kcUH6mWriow4DSh8
# 5KW79Ru+Bp63hHYNUAvkiDxiE3G5e5idP37hANkA1wrhD+jh6cSzrz5JNBUNTNL2
# l7MgcY9h7WC+KmZvVJ3+2BAiY+0hT3WGLF9joHNdMaa1sXtW1rgwLo5QiumYNY36
# O5ugt+YoY/OeUGHu49L9YTBKjiseaPDk3xno1nm8UyuUISmXPC/rfFIgfctlL2bS
# OOKWt8UQnxfxq24GMAnvmh3SQACwTJFzL3reeoogknXNJSkCBTc=
# SIG # End signature block
