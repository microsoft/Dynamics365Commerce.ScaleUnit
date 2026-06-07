<#
.SYNOPSIS
    CLI entry point for local CSU extension package operations.

.DESCRIPTION
    Provides a unified command-line interface for uploading and downloading
    CSU extension packages to/from Dataverse. Configure Local.vars.ps1 before use.

.PARAMETER Command
    The operation to perform: 'upload' or 'download'.

.PARAMETER PackageName
    (download only) The name of the CSU extension package to download.

.PARAMETER PackageVersion
    (download only) The version of the CSU extension package to download.

.PARAMETER Help
    Show detailed help and usage examples.

.EXAMPLE
    .\Run.ps1 upload

.EXAMPLE
    .\Run.ps1 download -PackageName "Contoso.Commerce" -PackageVersion "1.0.0"

.EXAMPLE
    .\Run.ps1 --help
#>
param (
    [Parameter(Position = 0)]
    [ValidateSet('upload', 'download')]
    [String]
    $Command,

    [Parameter()]
    [String]
    $PackageName,

    [Parameter()]
    [String]
    $PackageVersion,

    [Parameter()]
    [Alias('h', '?')]
    [Switch]
    $Help
)

$ErrorActionPreference = 'Stop'

function Show-Help {
    $help = @"

CSU Extension Package CLI
=========================

Usage:  .\Run.ps1 <command> [options]

Commands:

  upload      Upload a CSU extension package to Dataverse.
              The package path is set via ExtensionPackagePath in Local.vars.ps1.
              If not set, defaults to the build output folder.
              Package name and version are read from manifest.json inside the
              package. The name + version pair must be unique per environment -
              bump the version in manifest.json before re-uploading.

  download    Download a CSU extension package from Dataverse.
              Use -PackageName and -PackageVersion to specify which package.
              The file is saved to OutputDirectory in Local.vars.ps1
              (defaults to your Downloads folder).

Options:
  -Help, -h   Show this help message.

Getting Started:
  1. Open Local.vars.ps1 and fill in TenantId and DataverseEnvironmentUrl.
  2. Set UseUserSignIn to `$true (recommended) or configure app credentials.
  3. Run one of the commands below.

Examples:
  .\Run.ps1 upload
  .\Run.ps1 download -PackageName "Contoso.Commerce" -PackageVersion "1.0.0.0"

"@
    Write-Host $help
}

# Show help if requested or no command given.
if ($Help -or [string]::IsNullOrWhiteSpace($Command)) {
    Show-Help
    return
}

# Validate configuration.
. $PSScriptRoot\Local.vars.ps1

$missing = @()
if ([string]::IsNullOrWhiteSpace($TenantId))                { $missing += 'TenantId' }
if ([string]::IsNullOrWhiteSpace($DataverseEnvironmentUrl))  { $missing += 'DataverseEnvironmentUrl' }
if ($missing) {
    Write-Host "`nPlease set the following in Local.vars.ps1 before running:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nFile: $PSScriptRoot\Local.vars.ps1`n"
    return
}

# Prompt for command-specific parameters if not provided.
if ($Command -eq 'download') {
    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        $PackageName = Read-Host 'Enter the package name to download'
        if ([string]::IsNullOrWhiteSpace($PackageName)) { throw 'PackageName is required for download.' }
    }
    if ([string]::IsNullOrWhiteSpace($PackageVersion)) {
        $PackageVersion = Read-Host 'Enter the package version to download'
        if ([string]::IsNullOrWhiteSpace($PackageVersion)) { throw 'PackageVersion is required for download.' }
    }
}

switch ($Command) {
    'upload' {
        & $PSScriptRoot\Local.UploadExtensionPackage.ps1
    }
    'download' {
        & $PSScriptRoot\Local.DownloadExtensionPackage.ps1 `
            -PackageName $PackageName `
            -PackageVersion $PackageVersion
    }
}

# SIG # Begin signature block
# MIInSQYJKoZIhvcNAQcCoIInOjCCJzYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDqbqvq5rsaFn2l
# +zHEbWyYYvkL5VyLqe+LdJ1Yl40euqCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnlMIIZ4QIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHOzdhZN
# ektNXIsyABzoQEpYGRzfc8xQ5BDUesN6bmGXMEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAh6CDY6Gmm0ff6AZ3wq94eo/D2bDgBUuNBW3fSvaJ
# vB6/ziHSTe/vuLWoi81q4yqCrYQQ/czXoSdZ7KyXFwdwiV4IDlRaPabOdO5aeEyZ
# X5rtARDvZ0RBavEl6Zp/Hh1dV8BEAlItbRbDbMTNDyaCAGG09bCN1a9K9tb7XHtj
# ASogb7cdliAepVrYGs4XWbLzVpz9UxTUIwtqlu2nmocLCViJY4QC1WYN+H+s3qAG
# QgS74IW6RYL8fD6y1/ovQ8BKBQx28EhYNOgD5w3Dung1QuByUi67h21Q+z2KEi5q
# DnUftBgp5TkDqI08wF//IBh7iW4O1g/WrShyNc6357qjD6GCF5cwgheTBgorBgEE
# AYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDxv20slaZuZywG8rOfgz9eV7SpSg1qybMlAN8N
# DjCB1wIGahdRVJMEGBMyMDI2MDYwNzEwMTIwNi42NzFaMASAAgH0oIHRpIHOMIHL
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAiJB0vaq/8i1/wABAAAC
# IjANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0yNjAyMTkxOTM5NTZaFw0yNzA1MTcxOTM5NTZaMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1ueKJukIuUsAAJo/AY5DZRqH7
# bhgv7CWGNlEdbRGoITrdE6Wsn57NaNu1BTdjBbFcv7Rfixte0x+HRvXSqsD+WeSX
# /6/y9wE0Mz+xRPTGIY20K7aQDa68OyzVyUeUCypyZC/gW/3ytO/ZOnU9H2ri77kJ
# P8ABrqyy1UxX/OseEgvHsj8yikWT0ARtrjWbXMHFzSOo5hQcfUmMXKqWWz6+N0+U
# ynhGy1n+doW4WZgpH8Y5W7hpSokWj1M/Lu4wi3o6Dz9vVWukcgUFGjLAl4YZpOha
# h7HuiC/alXImMQf8C3A8q/6/1hFoeIZB4UGkywxB/OSTOSsL6+39pDqzM7CgOpf4
# V799kN94yM9uXJI5T/SiA5MdIZIhEW0+bh85RqDh5YW3/oav54RPxw5OPlH64QV6
# KJkl0FIElMVoLNo8UWRQcMD179x7WASjC6LsaNZ7yK0qcESIsL1wiQmdfQBxcqrF
# CpIQfnmQFkOp9IyXUWqza8tmpz8E6aXg9b1eiAT3PVTgrOlPi/hYZCfPxX/6jGty
# Pjy1CiwOmJamohmSU//COAenfRT2G2HMRUpCX1zs+AmDmdQM1XRab4YSALLAlDzG
# CsgI77nnuJjoXAliJmv7NfrvWAcA5KqCUOWQ6kSPt5r28MfKXWJJpSXtFeS/MkDz
# Jy/iJRVyHcFy/B+MtwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFFkHwGoDJ5ZbEEiu
# 8KstiusqaozQMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1Ud
# HwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggr
# BgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# DgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBiAM+nqrpwG29txSXv
# 42o+CsTe2C4boaRfFju9JaWkLTHwq7pknNONL3n+UG3x/B083EKXiFYrAmul7BTH
# CGXU63/xRsZ2wj3ZmR0A4d9nf9saCJVm4juPVFBai/oktOOYH2j+1+zM70woN5on
# gB/pvy7X8AfY6JB4XPvb80Qz7fY5eddbnwjzg1sZhUPFbbcweWeACINrzqFK62mM
# eXKmhtufMraoogJeJXfWY3x4/pbubgENT3+pXT65203CPF9kfdKE7GKAIRYy3xkB
# TDvFd8dufjOpCn38nK6qMlVtnBjDhWQG0PM3E/oxBs5UBrI6pBYkmIHtbjifDquH
# T+ThaVV7xHc6InoSc3aNzX49JHUgQmuvDdMjLkbYXeA0/1q5IxSg2U+ycZBOvAi3
# udZPKhA5VzODjf/ucu/vFtXrYcRkmGKN3jujaK3/yMZi2Ju5NEL3ISWorwp7RjeZ
# g+JMIK0fosuVj+YCm5r64LH/D9QJDAj+XfZaNeFdv90K5A0QRRGP/poB9yTIVjEX
# j/uJzp8L4Dd44sAquqDOiHdkLgxfK8nPqpCSWPZ9G+RCPm85o9cAfxENtrSuOwcp
# yKzxsRCYCL+PK4+98orit9EVJ/LLoCeG+jLlj0KaD4Qy6sZe4rWMr1brQLosTBZN
# wFnXxNjInCWBd0i7is1yTS/4qTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkA
# AAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVow
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX
# 9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1q
# UoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8d
# q6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byN
# pOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2k
# rnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4d
# Pf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgS
# Uei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8
# QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6Cm
# gyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzF
# ER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQID
# AQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQU
# KqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1
# GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0
# bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMA
# QTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbL
# j+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1p
# Y3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0w
# Ni0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIz
# LmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwU
# tj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN
# 3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU
# 5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5
# KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGy
# qVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB6
# 2FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltE
# AY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFp
# AUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcd
# FYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRb
# atGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQd
# VTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjg5MDAtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEw
# BwYFKw4DAhoDFQC7ycXVZx3bsDpJkr7VucgpksozuKCBgzCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7c+mFDAiGA8y
# MDI2MDYwNzA4MTEwMFoYDzIwMjYwNjA4MDgxMTAwWjB3MD0GCisGAQQBhFkKBAEx
# LzAtMAoCBQDtz6YUAgEAMAoCAQACAhEzAgH/MAcCAQACAhOfMAoCBQDt0PeUAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAILNIVe2bpEVM237ccO3wREbRpkm
# sZ0gfGotPjGRAQQ8qmFgTG4nHZXdb6YxhI7ZHUQattLpUaX2MfFskLWI4v2qODtN
# kJt9R2oYq3CmnYJG+3kyhRa+bKHc9I6Ay44hcbqZKd7P0MBOn3kfzeTA7m9kNNiE
# 5ylOXTGLyufMo9uf6InXJPPLoNnnuoN5S5cM44pBIjjYg/TPKntmkMqFOIwWM2Zl
# vZSgoUichjO8HLRaKyIhuhQn5ZAB/+jWM63FbgOFAbgfksVJmuIb4wo6uaYNcxn5
# 1cRoagZ36fZt0xbhEQXvUQKMzYYUrsO7ViSpU3PT+RLnQsOoD04Dt0JZpw4xggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiJB
# 0vaq/8i1/wABAAACIjANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCC6wpGG+HsCRaH6ELjHUkvEl6BA
# sZsZEOz2Hb1OSJL/+jCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIAVgXQEK
# BOfGgjNskmDOmbcEIOnHGNwA+QcRufDR5AkTMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIiQdL2qv/Itf8AAQAAAiIwIgQgGLfVpAsE
# ECuF7UO1Gyvz1AFfevrVW3mWaEHTznSP5fYwDQYJKoZIhvcNAQELBQAEggIAXA3J
# PahIuzr/n40RqLXcenvk1pxdmkZsr5mIHI0yE2wAdYVpWGO9X1ZTuAKVm46hGZgR
# YQXBGjrs/JL5kwZbgu0dEc2fy8Cn2yu1OW8AlYdda1fUhFUhQm2DXl+0i9LY0P8g
# 4L49BAHOdqgXzQ/BWBeGdL4d333N/wPz3blOjOT5Z2LgmzVQuM6XtFyDKz2ngHGc
# d6do2F+/A+WyJ/+/+rc9FN6eqC5YrVn09dgdj45gUWLkzK867NKqom4UJ6QdXs5J
# ewhf1/v5ytpWAg2fttA5ePJutRbbFUxwbWKEqElUmK/PjQ3VLq+ji2f4v4ywOHwc
# T0kKdl0EUMiD4u9meemftNS2hJzm0bTj9rS/1cGDk8zvqO+75eqek62qUdeT3VCc
# PFlqhFqAKuTTqs6qY64JyEl75yPjP3lrfk0y/+Yshu/eaBEyoQ+wpjgW8g/ugg1V
# osh6lakEoTbpScaytDd88OiI0NedHSBc3LHLYyZ4XgkV+4zCC6EIx9HOEV92yBj4
# 5eyQYO1ci4QO3dTV2+jM4Pvg1WZafDVEA2yMR2KoiGG34Bq+cuyZpMjhheVwmWsN
# 0U3iaTfJU8aJj9m0s4oiPTFnLImu7CECxjdJ41YMJgkgcOUn4+6Gi8jsqBrdDXr4
# boApIX4yst6IZ5c39xCkuL2G86AS5h/QQ3euZJo=
# SIG # End signature block
