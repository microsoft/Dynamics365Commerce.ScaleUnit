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
Copy-Item -Path (Join-Path "$workspaceFolder" "\CommerceRuntime\bin\Debug\net8.0\*.pdb") -Destination  (Join-Path "$extensionInstallPath" "\")

if ($Env:baseProduct_UseSelfHost -ne "true") {
    # IIS deployment requires the additional actions to start debugging

    $RetailServerRoot = "https://$($MachineName):$port/RetailServer"

    # Open a default browser with a healthcheck page
    $RetailServerHealthCheckUri = "$RetailServerRoot/healthcheck?testname=ping"
    Write-Host "Open the IIS site at '$RetailServerHealthCheckUri' to start the process to attach debugger to."
    Start-Process -FilePath $RetailServerHealthCheckUri
}
# SIG # Begin signature block
# MIInNwYJKoZIhvcNAQcCoIInKDCCJyQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAj/Mb+xpVtxK/0
# CgapzAAxLR6515slx0NCODkBf9qyVqCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
# xZvoL37EAAAAAAIcMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQxWhcNMjcwNDE1MTg1
# OTQxWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDVsZfgOKmM31HPfoWOoNEiw0SlCiIxUMC0I9NMWbucKOw/e9lP
# oAoehQVu6SG65V4EPzrYsnBnFPNoi4/HoOdjhz1qkrEt4I6tEcxXU6oOeY9zGveC
# /3iBeuhLYxM3M/PkcUoebF+Nednm8OkdSPoDu8imViHPQq/8CQUu0WRR4rE+dMRf
# rpVqfmNi2qWCX94T4MsepijGVkwE//tJg0ryAiYdHT34LSnlG/RSBZmQRGWZ5g8j
# qnKjRParSqMft1gvjuUTVgtWNZfgcLFSK5Wa0myrq8OPcgTGGsRgun+tnSS+IxDT
# xVsAPH1OzvPjwomguByhUe/OcvUN0D5Wmp7xAgMBAAGjggGqMIIBpjAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFNoH7a2YDjOSwpkp6DHcmUS7J+0yMFQGA1UdEQRNMEukSTBHMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxFjAUBgNVBAUT
# DTIzMDAxMis1MDc1NjkwHwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEw
# YAYDVR0fBFkwVzBVoFOgUYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# bDBtBggrBgEFBQcBAQRhMF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmcl
# MjBQQ0ElMjAyMDI0LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IC
# AQAUnEqhaRXe0T3hIJjvdQErEkrA/7bByjn6t5IArODkkRjzkYwtKMc2yYj2quaN
# rLutWw2YZcngKPy1b71YyDJQTy4NDRwaSh9Tw5thrk3NmcPrAHia5vtcBJ1CgtKK
# 7mQbIcQ22d/N3813ayCDDFewu1+jsZmX+r/aTEqaOM4TVxVtRSkuCy8nAXKuChOK
# Li/zA4XuH8iEYqIsj2YoNaeSxVmeGiERXpKdo3dDmYi0kO5w2D8VS4c3+9h6gElY
# BaAAg/dYErBg27qT3vv0zRDJhJufvCNylA8S7/+8H5E/PV5cng6na9VV/w9OV3qu
# uND6zdGa2EX38Glp50F9AIQk3p2xXmcvorDeM4XJ7UlWYBi6g80J1SSOQnInCYFE
# msfUNn3+1AaTJKSJL83quKArTac2pKhu0Yzzzrzo6HrsRiQKzpnRBb1/dMa6P3hz
# 75XbMRBctNsFhZC07WCmjExdLg2eHW5uV0TY8D5+6wozJf7vF3+WHkYPO85Z+BC6
# U4FkNbYNycZ9cE4j1tXRdyDCfml6c0HWPHjNVDObrv9lKt3qUqFpX38VCqVCyNOO
# 1UcXfQiVjJw32U2WUKZjt/neJKHEBsm9kFsLuWzkQ53+qcaSaytmsCnk2gOglrlD
# 5d3kKyvvAw+rzm0lT8K38P6PLxfZQHhu4W8dV7Av8N2ZmDCCBr0wggSloAMCAQIC
# EzMAAAA5O7Y3Gb8GHWcAAAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoX
# DTM2MDMyMjIyMTMwNFowVzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQ
# Q0EgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeq
# lRYHNa265v4IY9fH8TKhemHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo
# 0dtS/EW6I/yEL/bLSY8hKpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATv
# QVL4tcf03aTycsz8QeCdM0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a
# 1uv1zerOYMnsneRRwCbpyW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1
# FyQfK0fVkaya8SmVHQ/tOf23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfO
# GSWHIIV4YrTJTT6PNty5REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7
# ttOu1bVnXfHaqPYl2rPs20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJ
# uz2MXMCt7iw7lFPG9LXKGjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxS
# CwyoGIq0PhaA7Y+VPct5pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOm
# VQop36wUVUYklUy++vDWeEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3
# SkE/xIkgpfl22MM1itkZ35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8E
# BAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPX
# LQaUEggxMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBP
# oE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAw
# TgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAFJQfOChP7onn6fLIMKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D
# 5W4wMwYeLystcEqfkjz4NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBY
# nbu0+THSuVHTe0VTTPVhily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSI
# vgn0JksVBVMYVI5QFu/qhnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6
# aR9y34aiM1qmxaxBi6OUnyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4w
# PKC5OmHm1DQIt/MNokbbH3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7
# RTX8AdBPo0I6OEojf39zuFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK
# /fg8B2qjW88MT/WF5V5uvZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSK
# YBv0VisCzfxgeU+dquXW9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkw
# YTu/9dLeH2pDqeJZAABVDWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVT
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghnEMIIZwAIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEID/2NWB8h7Q0aBzcsC1RcaM08WKf
# lGVqKwEPmwqaJoPTMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAWaxJ9csgY5YOyOHamdZMpr55mJQUr7uyq0nYTbhFrb5AqbSdFEVM9bzgh6Ri
# athYtiMJj76rYYgxZuHmZasoiQuIyVm32QTgC9mNoSsWP2nXQICefs9D/Ztm3NN/
# HK1J6x4E0LNp2jhxVyTNcdBiG4P28RVJ1FMWH4AUlXc8GlTXzTKQIsvlpRI3KsRU
# U3H4JZ4yy/6BagP+wfxyUvZMr9TXywl6LTuQNo+YsBYzay7kDmBP736pO6jqllYV
# PVwcHOF8dAznzJNkgL6bdL3RKsFxUu2e5p/DWDU4Fo1Ht4DPFUEDvm4r2O8RGGEn
# a7sVef35d1rHVZlBPlXseeggPqGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCCF3wG
# CSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCAjgr/HjtASXwnnPnV3nWA6LMmudHnIQJCAV+KdjDqMZAIGavNukVpnGBMy
# MDI2MTExNDExMTE1MC43ODdaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTkzNS0wM0Uw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHq
# MIIHIDCCBQigAwIBAgITMwAAAifVwIPDsS5XLQABAAACJzANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDRa
# Fw0yNzA1MTcxOTQwMDRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTkzNS0wM0UwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDixWy1fDOSL4qj3A1pady+elIDLwnF3UuLzJIOWwGHcEgr
# xxwtnyviUIDmmxylTUl1u+2rBPp2zT4BwwQhvGaJpExqvPLlDFlbfmSflKI86eFq
# ofiZ7j8NTRO4l7wGg9Njm+muNauTcFW2qdfIjKE950Okrm9MnMOGYy+fibNYdxTP
# RPq1T4MLZK3s3vdMyMEOldcOQkSKpxD6/1Gk6gOmCu2KgI8f0ex6vYxnKDl9W0OL
# SEa/6y82oIbsm+1QBifOQ47xWKTG1CmvtGr85LzA75/MAcUmRw5/of/qET0UFV1W
# ulMcJrI6DASAsNCNB+6WLrotuBZAj+VMlqbn5RMZ6Q4IY7JwaAiIXh7VjxrnwUOY
# ZG8WEGhfrA98di+7LEn9AqvvEOyG+UQcjVhCCbMGXigJXSApeyeWupCsD0jgQMNC
# xfB5BLBDWxgdY3dJBEPgxfkgTDQLBggtVv2d5CYxHKgIItB4bI5eSb5jkIG2Wotn
# FetT0legpw/Eozwf39ao6tENY21eVWIzRw/GsmvwjYQF6vVrxOD0pGVsfqGF8s3V
# PeY7hI2TxHFMqNA0IB/a2NLY7JTxYAKAP/11EJZt7xbqDLMgD1YDdGEzGpQijm3n
# APCL2CebP/jmu90abJ2W425yglGHTI/nCBrwSpfRCgwzrfFelJaCKM6+35aFfwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFNLW58N4MGSG6ud7jWqgT92orfReMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQAqncud4PSC1teb2H6nRuy7sDiKK13FXJirVB4T
# fwjdo2Mb+QL4j7wZ/k4G9P0CANHZFrDQcK0VFDTysrYu8Z0Aha14acDZPsyIoPvA
# GRRhaHEuf7NckRjkfa/ylo1KyII8jbL9N9sJAqBPL8V4FNBjljv+1GHDOw127rZz
# 5ZSTPoAPb2SA0v5yDgcpUMfxglPyp6cnPPoQpTtD9OGx8Dwm2P+o1TPxBIy6I0T9
# RauulogVCvKwflfeLTcKAvnSG1rCjerSXmU1DNXOsAD/bsrSjgbX5mAbD7XTRMF/
# vawAWESFcn/BjjizxeWZb00aYSlkJA2rVtFlMM481aVWXdAbXPP5RzUiWTlgyHf/
# G7lCxHYWGIZuB13T3aI6Y8mEgn/ou40aiFJo8r0+i0P5GdNneWtxiR0CMKUfko+5
# s/73cwe1Wfp8BKXa270cicVQasFf5sRV7pFm+V7fNRXwCu7anTOmga76zO7/2t+z
# OlibvphT+Q6Zd+B2qYsSn4xBaY+YzHpnycLW5cvJyhPxBCcb1oRYfhRzCADb2utI
# 2EtGCjc2P2ii4LyR4QMb/n8cOweL9IqVTKKzzVk+zZJxV3vrp4LyuQXw0O30la6B
# cHdNAAAB9UC83zs3G9d+AlIfZLM97tMUNKWjbBpIirFx6LTDFXVtZQd7hqzLYByj
# bjH0ujCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEw
# MB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk
# 4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9c
# T8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWG
# UNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6Gnsz
# rYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2
# LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLV
# wIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTd
# EonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0
# gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFph
# AXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJ
# YfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXb
# GjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJ
# KwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnP
# EP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMw
# UQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggr
# BgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYw
# DwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoY
# xDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYB
# BQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U5
# 18JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgAD
# sAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo
# 32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZ
# iefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZK
# PmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RI
# LLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgk
# ujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9
# af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzba
# ukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNNMIIC
# NQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOkE5MzUtMDNFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAjHzqt
# hPwO0GDckDMA6x54lIiMKqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7qKJlDAiGA8yMDI2MTExNDA3MTc0MFoY
# DzIwMjYxMTE1MDcxNzQwWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDuoomUAgEA
# MAcCAQACAhiHMAcCAQACAhHwMAoCBQDuo9sUAgEAMDYGCisGAQQBhFkKBAIxKDAm
# MAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcN
# AQELBQADggEBAE/USTfprLRVP2PbFDOafZFtHmRnwsAP8+oFb2mgbFk67bEqlRCq
# EkoU5j8EBT1dDsZC1upsmoYC8AcC5Owrd968krUmiu+6BNrt/nLxWVpRVeG2gW5x
# crtrsXnrkFB1meNs5OnkIvzNJApC/Xt3fAV+SrLSb+ZkC0vxXjjEkWeGArdrYkER
# pvoQi92UH2rdM6NWp+ze3kSlp+K1s1PhhL6uBEN4beno8tRAl6IxA01zvOcX+nth
# xbzybp4kc81d2oI0KnHoP3JYVmqxFNk+13crbZUynbPwtsb4KIyPjgjGuCUCshUZ
# gUqjRERe2yyO2gKkpDVc60kmP5WAUOMckUQxggQNMIIECQIBATCBkzB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAifVwIPDsS5XLQABAAACJzANBglg
# hkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqG
# SIb3DQEJBDEiBCCdzy2x2gus8XgEmATgibprinpso3w2bAs+Hml8ZyYMsDCB+gYL
# KoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOXnARo1oVIcOLJKDqlE0adq/jZ9TXdl
# nXWRcXGThBFyMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAIn1cCDw7EuVy0AAQAAAicwIgQgz0VXW5657pG7AdqG29hSwH89EdB0q8hm
# Ww0yN0Y5VGQwDQYJKoZIhvcNAQELBQAEggIAdYjHhzfO3q93cyWnw/ncuahVrQgf
# PffcBq8hFur1xgSu7iLiInM5NRqqbojNiN+N7s8ny+Ew2O/dt47B5hM2I4uS5c7e
# 7cS2FMaLVYoLvvXSJlBo0/zwvpWw4nrNeFD3AkxGHQzN2NhcHBu7tLIRfRypql30
# 5DFmil6t2MbZFzrgY7ivDUarGrzAhZwwq1iNPWJYMlb2+y4jpPyWB+VMRGbJsSyZ
# SGIpg3XRz+26CnVH915Ibm5+DUvCwUtFWoZKGFLaJDkG6n9O+UZ57jxWe7L777Zi
# 3Z1WGTo/qUDgomJ1ffso8kmEs9JyxFSH3v1nVufhAzkc1RfosURZ8hOVyHYptYkb
# PnYNiC8HKdCU62AOPZrpI7DnGh1rpyvPinB98RXar6e0eVXGxPgIe8ODuKcgJmDh
# UjQ5k2YETGuHQt0qpH9oKxf2VER1QjgrwRWikNzgVbCWKgWhYsrGJfFNaRZ1eDmc
# zTiJagnc6A4Fxphxa/0Y2fAmM79DT+gcAcCsGamThy45mPoIsxJvvAF4lod9i/RB
# d01jWYGdWKhIBuZWrtXekzKnJ+v+1rXXpTFTXIHEBgI3EcLMsS1n2GPMqM38J2QY
# fVmNiHyUZmEgZqGwpVDovi+93qRmu4sPeB8eIHPouGbXZ4cCo5wprfsv/t75cx27
# rbVW1ssSrq1sbV8=
# SIG # End signature block
