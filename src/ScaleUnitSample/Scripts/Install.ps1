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
# MIInQwYJKoZIhvcNAQcCoIInNDCCJzACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAj/Mb+xpVtxK/0
# CgapzAAxLR6515slx0NCODkBf9qyVqCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
# yE7XD1dIAAAAAAIdMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQzWhcNMjcwNDE1MTg1
# OTQzWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDQvewXxx9gZZFC6Ys1WBay8BJ8kGA4JQnH5CMafqOASlTpK9H8
# o5ZXTXt0caVQTNMUPt445wXYD+dFtaKWTwDn1I52oUSrC9vJin1Gsqt+zyKJL5Dg
# 3eQXbQNR61DmMy20GLTIO3SFed9Rfi/ophgCLGFLDR3r0KvHjwMb/jYWS0celV/4
# Lz27LfAekm8v9E5IXaeiXbAUYZKK090n4CVl3JBtbN+9DtI9SNu/yjvozW52/u7R
# X/Ttpa/KDlpuokZ+Zcbvmtd9ur9gFLvZzh41o9MsE/clQtdaFWGvuo6Jua/ntpgk
# ey3E5/vBFe+MJPG6phdnuo6r57ZudCudiI1bAgMBAAGjggGbMIIBlzAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFH6QuMwqcPG0hQlQ6c5jCtTTLrVeMEUGA1UdEQQ+MDykOjA4MR4wHAYDVQQL
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xFjAUBgNVBAUTDTIzMDAxMis1MDc1NTkw
# HwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEwYAYDVR0fBFkwVzBVoFOg
# UYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0
# JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNybDBtBggrBgEFBQcBAQRh
# MF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# dDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBKTbYOjzwTG/DXGaz9
# s6+fQeaTtDcFmMY+5UyVFCyj7Pv+5i37qfX8lSL/tBIfYQfWsMuBQlfZurJD6r4H
# VJ2CeH+1fgiq8dcHdVKoZ3Sa2qXoX3cq9iS8cVb06B7+5/XJ7I0OxHH9fDsvJ3T3
# w5V/ZtAIFmLrl+P0CtG+92uzRsn0nTbdFjOkLMLWPLAU3THohKRlSEMgFJpPkm5n
# 5UAZ35xX6FWCrDLsSKb555bTifwa8mJBwdlof0bmfYidH+dxZ1FdDxvLnNl9zeKs
# A4kejaaIqqIPguhwAti5Ql7BlTNoJNwxCvBmqW2MQLnCkYN/VVUsR3V2x/rcTNzo
# Bf/Z/SpROvdaA2ZOOd1uioXJt3tdLQ7vHpqpib0KfWr/FWXW10q38VxfCnRQBqzb
# SuztR7nEMuzX7Ck+B/XaPDXd1qh72+QYyB0Z2VzWmO9zsnb9Uq/dwu8LGeQqnyu6
# 7SDGACvnXii2fb9+US492VTnXSnFKyqwgzUyFMtZK1/sHYTv6bG4TtQUygQxTN+Z
# V+aJIlKO2MqZ7bKrAnOzS9m6NgoTdWOq11bTOZwKlIEV/EhV9SWkDmdpR/hPPT2v
# 6TEj4F8PT/zHjRezIU5c/DGlt/VhY/pK0XkJtEyMmmS1BMtjU/rqBZVMIm3dnxQs
# /TBByr+Cf8Z1r7aifQVQ+WSqzjCCBr0wggSloAMCAQICEzMAAAA5O7Y3Gb8GHWcA
# AAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoXDTM2MDMyMjIyMTMwNFow
# VzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEo
# MCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAyNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeqlRYHNa265v4IY9fH8TKh
# emHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo0dtS/EW6I/yEL/bLSY8h
# KpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATvQVL4tcf03aTycsz8QeCd
# M0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a1uv1zerOYMnsneRRwCbp
# yW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1FyQfK0fVkaya8SmVHQ/t
# Of23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfOGSWHIIV4YrTJTT6PNty5
# REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7ttOu1bVnXfHaqPYl2rPs
# 20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJuz2MXMCt7iw7lFPG9LXK
# Gjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxSCwyoGIq0PhaA7Y+VPct5
# pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOmVQop36wUVUYklUy++vDW
# eEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3SkE/xIkgpfl22MM1itkZ
# 35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPXLQaUEggxMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# ci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAwTgYIKwYBBQUHMAKGQmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOCAgEAFJQfOChP7onn6fLI
# MKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D5W4wMwYeLystcEqfkjz4
# NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBYnbu0+THSuVHTe0VTTPVh
# ily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSIvgn0JksVBVMYVI5QFu/q
# hnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6aR9y34aiM1qmxaxBi6OU
# nyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4wPKC5OmHm1DQIt/MNokbb
# H3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7RTX8AdBPo0I6OEojf39z
# uFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK/fg8B2qjW88MT/WF5V5u
# vZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSKYBv0VisCzfxgeU+dquXW
# 9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkwYTu/9dLeH2pDqeJZAABV
# DWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVTQl0v4q8J/AUmQN5W4n10
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnfMIIZ2wIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEID/2NWB8h7Q0aBzcsC1RcaM08WKflGVqKwEPmwqaJoPTMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAo00S6Z+17Fao5P6Z
# 3EBjJAtJcrV4dmUPv7+mPqNwMjxRnf8IqzBCQFDXJ/qzyBDqcZLvS3YSO+XvUzee
# mMiwN10TcVjH3KfQe8wZKOS+2JrfTYASQFynGXU4JGNhUN0jyGyY5xHHalK2XZvD
# 7zeoIQGuF8kyGKHYtg2qWGxxDHc6C9Hfc3sp+wcaHdPFuxj+6BMaZYUpAuho/35F
# G/BDv6seNjaHiLxWhQc6JNYudQsuSI5r4ljAWbvAYXPnh/fP1p/Qm7Or7vYfDPJq
# 2PNBdp+dTbEHWWGYJZKDtlKn4Ox+TenzQIu5UsB5mwE0aa6cYJrLUTFKZkIJkFQm
# dZ9jBKGCF68wgherBgorBgEEAYI3AwMBMYIXmzCCF5cGCSqGSIb3DQEHAqCCF4gw
# gheEAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFF
# MIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCASEeTcKZ9QvcCy
# B+XPv9kJViPWmNVH2d/hoDNeBCtaMQIGaojzK0OzGBMyMDI2MDgyMjEwMTAyMi4x
# NTFaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf0wggcoMIIF
# EKADAgECAhMzAAACGCXZkgXi5+XkAAEAAAIYMA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyNVoXDTI2MTEx
# MzE4NDgyNVowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# LTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAsdzo6uuQJqAfxLnvEBfIvj6knK+p6bnMXEFZ/QjPOFyw
# lcjDfzI8Dg1nzDlxm7/pqbvjWhyvazKmFyO6qbPwClfRnI57h5OCixgpOOCGJJQI
# ZSTiMgui3B8DPiFtJPcfzRt3FsnxjLXwBIjGgnjGfmQl7zejA1WoYL/qBmQhw/FD
# FTWebxfo4m0RCCOxf2qwj31aOjc2aYUePtLMXHsXKPFH0tp5SKIF/9tJxRSg0NYE
# vQqVilje8aQkPd3qzAux2Mc5HMSK4NMTtVVCYAWDUZ4p+6iDI9t5BNCBIsf5ooFN
# UWtxCqnpFYiLYkHfFfxhVUBZ8LGGxYsA36snD65s2Hf4t86k0e8WelH/usfhYqOM
# 3z2yaI8rg08631IkwqUzyQoEPqMsHgBem1xpmOGSIUnVvTsAv+lmECL2RqrcOZlZ
# ax8K0aiij8h6UkWBN2IA/ikackTSGVRBQmWWZuLFWV/T4xuNzscC0X7xo4fetgps
# qaEA0jY/QevkTvLv4OlNN9eOL8LNh7Vm0R65P7oabOQDqtUFAwCgjgPJ0iV/jQCa
# MAcO3SYpG5wSAYiJkk4XLjNSlNxU2Idjs1sORhl7s7LC6hOb7bVAHVwON74GxfFN
# iEIA6BfudANjpQJ0nUc/ppEXpT4pgDBHsYtV8OyKSjKsIxOdFR7fIJIjDc8DvUkC
# AwEAAaOCAUkwggFFMB0GA1UdDgQWBBQkLqHEXDobY7dHuoQCBa4sX7aL0TAfBgNV
# HSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBU
# aW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwG
# CCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEAnkjRhjwPgdoIpvt4YioT/j0LWuBxF3ARBKXD
# ENggraKvC0oRPwbjAmsXnPEmtuo5MD8uJ9Xw9eYrxqqkK4DF9snZMrHMfooxCa++
# 1irLz8YoozC4tci+a4N37Sbke1pt1xs9qZtvkPgZGWn5BcwVfmAwSZLHi2CuZ06Y
# 0/X+t6fNBnrbMVovNaDX4WPdyI9GEzxfIggDsck2Ipo4VXL/Arcz7p2F7bEZGRuy
# xjgMC+woCkDJaH/yk/wcZpAsixe4POdN0DW6Zb35O3Dg3+a6prANMc3WIdvfKDl7
# 5P0aqcQbQAR7b0f4gH4NMkUct0Wm4GN5KhsE1YK7V/wAqDKmK4jx3zLz3a8Hsxa9
# HB3GyitlmC5sDhOl4QTGN5kRi6oCoV4hK+kIFgnkWjHhSRNomz36QnbCSG/BHLEm
# 2GRU9u3/I4zUd9E1AC97IJEGfwb+0NWb3QEcrkypdGdWwl0LEObhrQR9B1V7+edc
# yNmsX0p2BX0rFpd1PkXJSbxf8IcEiw/bkNgagZE+VlDtxXeruLdo5k3lGOv7rPYu
# OEaoZYxDvZtpHP9P36wmW4INjR6NInn2UM+krP/xeLnRbDBkm9RslnoDhVraliKD
# H62BxhcgL9tiRgOHlcI0wqvVWLdv8yW8rxkawOlhCRqT3EKECW8ktUAPwNbBULkT
# +oWcvBcwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
# DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAx
# MDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/
# XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1
# hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7
# M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3K
# Ni1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy
# 1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF80
# 3RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQc
# NIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahha
# YQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkL
# iWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV
# 2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIG
# CSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUp
# zxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBT
# MFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYI
# KwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186a
# GMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcN
# AQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1
# OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYA
# A7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbz
# aN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6L
# GYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3m
# Sj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0
# SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxko
# JLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFm
# PWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC482
# 2rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7
# vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWDCC
# AkACAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsO
# AwIaAxUAnWtGrXWiuNE8QrKfm4CtGr57z+mggYMwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO4zcaUwIhgPMjAyNjA4
# MjIwMDUzNTdaGA8yMDI2MDgyMzAwNTM1N1owdjA8BgorBgEEAYRZCgQBMS4wLDAK
# AgUA7jNxpQIBADAJAgEAAgE8AgH/MAcCAQACAhLzMAoCBQDuNMMlAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMB
# hqAwDQYJKoZIhvcNAQELBQADggEBADiSuzuH1zojjOvJNr8l5xBeUrmemnLx7qJS
# Ipy+oWZZvU5ffUyHzVXnOwYP2ibVd3YIVWULYGzavinIDbLV6R1WZQPpVSiLNI1m
# pca2U+LnJHdpXkxwRdgUKUuz8xm3ICO0BPB2v8Wk0OSwTzDxzR12SsnPNN6oinbg
# bjXRaeBImChoB/W1YxiEzVbDvOrpIYk2WH/WpAmT5mMzzZpOP09OKmoSOcorUYsc
# HkroxPRbaUZZcpqANxiNhMnHEtRwi2fHNIQBxRUTPDo1v3N8sRiDBkp3lYeHTfT2
# Jted+N3EAvf9wZjpSSdREE3ix/g/VDwFhUvZjLvkLvJrOynYm4oxggQNMIIECQIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhgl2ZIF4ufl
# 5AABAAACGDANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCB6ABDq5dgAz5dSrCdJbuTUVHWHckTpt+Ax
# z7SOxnCCzjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIJkT3Im45Mi0jBZo
# RLqXMYorVdxKjPXKdHNo5XPH14VqMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTACEzMAAAIYJdmSBeLn5eQAAQAAAhgwIgQgexhlzSkKJdbYJSxC
# homiSyU6TfRIQ6FkQI0tGsl9NZ4wDQYJKoZIhvcNAQELBQAEggIAVCVZ5EQfZbCu
# qHEWca++J+n/d2oOImwKop13rbeYFaeMQubMM+nRO20hjD3qSgj5qVx3nNxXIkuj
# EfAVtXnf7//pjvglnrt53Z8IjPw2g4neJSJRO4Pu4W/pw1slTR6bogJYV8ekj+0M
# 6oA1L9CROUOFmWDZ63Qg92LmOW/RaKaYMqgil6dlP4mpsoLhyourPPQzJwfTRQQZ
# c6xnbZa2c9S9kmjmP8r+gwJrNQOfDXmC5RfQv2deFogV4vCOKy9EuhZBvqFOJUMM
# jgPKc2OElx6b72pYUa4HXlWn86svCU323DhBID3s76Xf2YHSMs7t9ANe8MqL/obx
# qBrBCAIbE4DiUCMzlAQj5vzdePcZfMeTZapSGh8CWRLeagl0ZZiA1BdP5mDb2qsT
# 8l1p9/lHLsHI35yNS/SjQ4BgHvH0DyztFwoIEThBkkuUcHGjl0thdNS2fvEYG7QD
# obkB0HeU/HbxUJmY/7zcySz6WGc9DhQ3eBu1THOur6JGjTAUiq1yzVoTuCohQxDY
# 2v8htfuTDuMoupVUuGGWookmDTUhNxroRUifta31hk3fKLfJtqzeXdCvHX/S3FHx
# D0i/ryfP/NdfwU9qNKTN4brYst8nGwJxa4WmzhvvIsaatn7ENojxtlCkQyTto36x
# yrgjRaVeRkDGha1W7qt47bbFYDkJ13o=
# SIG # End signature block
