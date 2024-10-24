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
# fG4hkomgrr3+SdC7U3bV/5m6fcWapqCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
# Bv9XKydyAAAAAAQEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjQwOTEyMjAxMTE0WhcNMjUwOTExMjAxMTE0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC0KDfaY50MDqsEGdlIzDHBd6CqIMRQWW9Af1LHDDTuFjfDsvna0nEuDSYJmNyz
# NB10jpbg0lhvkT1AzfX2TLITSXwS8D+mBzGCWMM/wTpciWBV/pbjSazbzoKvRrNo
# DV/u9omOM2Eawyo5JJJdNkM2d8qzkQ0bRuRd4HarmGunSouyb9NY7egWN5E5lUc3
# a2AROzAdHdYpObpCOdeAY2P5XqtJkk79aROpzw16wCjdSn8qMzCBzR7rvH2WVkvF
# HLIxZQET1yhPb6lRmpgBQNnzidHV2Ocxjc8wNiIDzgbDkmlx54QPfw7RwQi8p1fy
# 4byhBrTjv568x8NGv3gwb0RbAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU8huhNbETDU+ZWllL4DNMPCijEU4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMjkyMzAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIjmD9IpQVvfB1QehvpC
# Ge7QeTQkKQ7j3bmDMjwSqFL4ri6ae9IFTdpywn5smmtSIyKYDn3/nHtaEn0X1NBj
# L5oP0BjAy1sqxD+uy35B+V8wv5GrxhMDJP8l2QjLtH/UglSTIhLqyt8bUAqVfyfp
# h4COMRvwwjTvChtCnUXXACuCXYHWalOoc0OU2oGN+mPJIJJxaNQc1sjBsMbGIWv3
# cmgSHkCEmrMv7yaidpePt6V+yPMik+eXw3IfZ5eNOiNgL1rZzgSJfTnvUqiaEQ0X
# dG1HbkDv9fv6CTq6m4Ty3IzLiwGSXYxRIXTxT4TYs5VxHy2uFjFXWVSL0J2ARTYL
# E4Oyl1wXDF1PX4bxg1yDMfKPHcE1Ijic5lx1KdK1SkaEJdto4hd++05J9Bf9TAmi
# u6EK6C9Oe5vRadroJCK26uCUI4zIjL/qG7mswW+qT0CW0gnR9JHkXCWNbo8ccMk1
# sJatmRoSAifbgzaYbUz8+lv+IXy5GFuAmLnNbGjacB3IMGpa+lbFgih57/fIhamq
# 5VhxgaEmn/UjWyr+cPiAFWuTVIpfsOjbEAww75wURNM1Imp9NJKye1O24EspEHmb
# DmqCUcq7NqkOKIG4PVm3hDDED/WQpzJDkvu4FrIbvyTGVU01vKsg4UfcdiZ0fQ+/
# V0hf8yrtq9CkB8iIuk5bBxuPMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
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
# Z25pbmcgUENBIDIwMTECEzMAAAQEbHQG/1crJ3IAAAAABAQwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP6NdU08NRoNoLhjViwvqXhQ
# n0PusfKGN0+TCkY43y+DMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAmhihz4bmcX7f1onsIgiiaVxbmPDG7wd89PA8dT7IWAxTDndfhajI2LcY
# 5nwGDTem5pxU89SNFWTnawPCUtZP59CdpstYOlJzoeXB8aQmOknXTEc2+kt096ZP
# /yQeA1PyXK2LPE4ezkdC9h+p9j6tS6kFDI/3Pzs4q7Jy47fWRoQRF/GB2bQ3osw+
# nk6phIuwc7k59VbMuM4L716prmf46/QqL4bmhe2/AIZ9YyEDn1jhW4Ufdxw2o9GE
# LKDhnPkX1BcX1mnnD/07dPSlrCT8Vl3FKWnYOWpMxCLtIzoleRDsJzeAgBVgw/5F
# dEnSc6hRb1YC36p5CInAvsjnsT8KUKGCF60wghepBgorBgEEAYI3AwMBMYIXmTCC
# F5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsq
# hkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCC3FCW2EdtnLiLRAiIoyDNVZxcZb0phjd5fu/9etSucNwIGZutCq6YF
# GBMyMDI0MTAyNDEwMTA1NS41ODFaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVT
# Tjo0MDFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAAB/tCowns0IQsBAAEAAAH+MA0G
# CSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI0
# MDcyNTE4MzExOFoXDTI1MTAyMjE4MzExOFowgdMxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9w
# ZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQwMUEt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvLwhFxWlqA43olsE4PCe
# gZ4mSfsH2YTSKEYv8Gn3362Bmaycdf5T3tQxpP3NWm62YHUieIQXw+0u4qlay4AN
# 3IonI+47Npi9fo52xdAXMX0pGrc0eqW8RWN3bfzXPKv07O18i2HjDyLuywYyKA9F
# mWbePjahf9Mwd8QgygkPtwDrVQGLyOkyM3VTiHKqhGu9BCGVRdHW9lmPMrrUlPWi
# YV9LVCB5VYd+AEUtdfqAdqlzVxA53EgxSqhp6JbfEKnTdcfP6T8Mir0HrwTTtV2h
# 2yDBtjXbQIaqycKOb633GfRkn216LODBg37P/xwhodXT81ZC2aHN7exEDmmbiWss
# jGvFJkli2g6dt01eShOiGmhbonr0qXXcBeqNb6QoF8jX/uDVtY9pvL4j8aEWS49h
# KUH0mzsCucIrwUS+x8MuT0uf7VXCFNFbiCUNRTofxJ3B454eGJhL0fwUTRbgyCbp
# LgKMKDiCRub65DhaeDvUAAJT93KSCoeFCoklPavbgQyahGZDL/vWAVjX5b8Jzhly
# 9gGCdK/qi6i+cxZ0S8x6B2yjPbZfdBVfH/NBp/1Ln7xbeOETAOn7OT9D3UGt0q+K
# iWgY42HnLjyhl1bAu5HfgryAO3DCaIdV2tjvkJay2qOnF7Dgj8a60KQT9QgfJfwX
# nr3ZKibYMjaUbCNIDnxz2ykCAwEAAaOCAUkwggFFMB0GA1UdDgQWBBRvznuJ9SU2
# g5l/5/b+5CBibbHF3TAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBf
# BgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmww
# bAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAiT4NUvO2lw+0
# dDMtsBuxmX2o3lVQqnQkuITAGIGCgI+sl7ZqZOTDd8LqxsH4GWCPTztc3tr8AgBv
# sYIzWjFwioCjCQODq1oBMWNzEsKzckHxAzYo5Sze7OPkMA3DAxVq4SSR8y+TRC2G
# cOd0JReZ1lPlhlPl9XI+z8OgtOPmQnLLiP9qzpTHwFze+sbqSn8cekduMZdLyHJk
# 3Niw3AnglU/WTzGsQAdch9SVV4LHifUnmwTf0i07iKtTlNkq3bx1iyWg7N7jGZAB
# RWT2mX+YAVHlK27t9n+WtYbn6cOJNX6LsH8xPVBRYAIRVkWsMyEAdoP9dqfaZzwX
# GmjuVQ931NhzHjjG+Efw118DXjk3Vq3qUI1re34zMMTRzZZEw82FupF3viXNR3DV
# OlS9JH4x5emfINa1uuSac6F4CeJCD1GakfS7D5ayNsaZ2e+sBUh62KVTlhEsQRHZ
# RwCTxbix1Y4iJw+PDNLc0Hf19qX2XiX0u2SM9CWTTjsz9SvCjIKSxCZFCNv/zpKI
# lsHx7hQNQHSMbKh0/wwn86uiIALEjazUszE0+X6rcObDfU4h/O/0vmbF3BMR+45r
# AZMAETJsRDPxHJCo/5XGhWdg/LoJ5XWBrODL44YNrN7FRnHEAAr06sflqZ8eeV3F
# uDKdP5h19WUnGWwO1H/ZjUzOoVGiV3gwggdxMIIFWaADAgECAhMzAAAAFcXna54C
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
# Tjo0MDFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaIjCgEBMAcGBSsOAwIaAxUAhGNHD/a7Q0bQLWVG9JuGxgLRXseggYMw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsF
# AAIFAOrEjAgwIhgPMjAyNDEwMjQwOTA0MDhaGA8yMDI0MTAyNTA5MDQwOFowdDA6
# BgorBgEEAYRZCgQBMSwwKjAKAgUA6sSMCAIBADAHAgEAAgID4TAHAgEAAgIT9zAK
# AgUA6sXdiAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQCVFSYkTQHRQ00T
# znTlwrbctmdcO0+vRIjxarLFrpL4a7Xwu2PfL3gGp3Wi0Cl6ReEsOsJ4e77C0A2G
# nVWZ4H83KoLAG/vSqYgeHyPKVXP4C7QkO4ODM1YYHy4ej13qjNtYPdxjNEvnxsv6
# SPLnFFsoOiB4/yG6/aUDo+51knhqUVRe8HWo7PI/mKLLEGnLNnBikDWXhQ/U7hS3
# DlzgXC8kUt1gluW8Yw1u9AFUiGs3sx5u2u3PGnDPzL5c6a9KYEJO2QojGHX/Dq85
# zTQnuR8G64c9DpqVuaQq7lpIRl2LlCmTTjpfRW/4udJ2wW3tN47IqD+QA2x1WF4E
# C1G0rOzIMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAH+0KjCezQhCwEAAQAAAf4wDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgHuyyf42O29NM
# +z5a69XNItS8lkLk47vPd+Bw9ki5V2kwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHk
# MIG9BCARhczd/FPInxjR92m2hPWqc+vGOG1+/I0WtkCstyh0eTCBmDCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB/tCowns0IQsBAAEAAAH+
# MCIEIMbExdcTZnyoHeQCcLcjphHBZa+M+v5n91yQPiG0amthMA0GCSqGSIb3DQEB
# CwUABIICAHXLD1UDHJByskC8OQGuxbbsAbmR9fjSrBqLhYiIUVLzJNRwZ2uwreRi
# BF2ayUCuZ3PmXxvuwMONOfrf2SXLSpn0+IGMMSaKY0yFHMRmfL0uJwKl7MO4+WUo
# 1+BXMz8ND1GAP1Z7Evk9ngMlykZpE3Cx2BZT4UlX86Eff2eYThWOZyBlz+SYoZ7k
# H2rA32lcCcalB8MdH66e4vorC2UgCPO8t5AhKzHhBe7Ls4EK7cSjI2a7YcPEIPAl
# sQH5d9r3kRe1qnjQXGbkGiEbxV0F0/3lrhu2sh4NPIPHemqXtDaqyx1g1OGsQzWm
# jjjBzvHLuoSuoxxJJW10HoM9vJnht7V9+gfYHUhgvld4f6FeGAEXyBAk7g51dfyv
# Hy+Ctg9qnGX0HvwYJn6HzmAZ915rUUtLyCcdKfSl8FQL32ECgDJsOjwGiYFor/ts
# fvPo3b3kWfRFNYg7xHlSlDYjCXrFd044CdvC6cy0saFvJPZOsS3jn8gPYku5Yjkz
# 6wP1SZ9q1yNjxNlu6Bov5di1hMcDIskQjH7oy3fklpK9mBVpNOeFZAmH26es9L2l
# bjQNxG57FXI/Kk+DxH7Z3n7vI/PvE96SuGhN2QwcaHpMh+bImk0vMydBR1SQa+T6
# K5NvhPXOKdZlSYzz9AwtuXUYadMcvlDWT5Npm8MbV+JTfSZAb+2n
# SIG # End signature block
