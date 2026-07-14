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
# MIInSAYJKoZIhvcNAQcCoIInOTCCJzUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnkMIIZ4AIBATBuMFcxCzAJBgNVBAYTAlVT
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
# DnUftBgp5TkDqI08wF//IBh7iW4O1g/WrShyNc6357qjD6GCF5YwgheSBgorBgEE
# AYI3AwMBMYIXgjCCF34GCSqGSIb3DQEHAqCCF28wghdrAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDxv20slaZuZywG8rOfgz9eV7SpSg1qybMlAN8N
# DjCB1wIGajE4VJs3GBIyMDI2MDcxNDEwMTMyMi45MVowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpBNDAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAACKPClh9fzyB5AAAEAAAIo
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5NDAwNloXDTI3MDUxNzE5NDAwNlowgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBNDAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK6O9uT+ypwJJF5lol8K5/U3BFxz
# teSeETrCQuh+Q2PWbEQCDfmrLbFwWOCNqu1W8DT1bxAdynIypVJc5PE0cmyaTSo/
# YIMu9QC6VaDtpLmgE5GkRfWjPefRHac+p4fQgcrXMnGPFodbbUBu5nRn7AzdZg3O
# QGVweZV7TdkbuuWTbyHvavk/kwTwUakWZhbkeXumwpuAsR+tgCK2m22xv6xmwFQj
# 6EwqXi4slii0rJm/V7A4iKcF9FTxCiyK+Oh9oF7NR/011X6IataHfbVadKwrcD8m
# XoYu1tJZdwlZQuBvG6qehs8r5iUHfXvhMxZOBfhhaMbujQ63P+mMc0IoFsHvzx3K
# eEt0ZjoHTwT37hIatGmy3LiIkc7J0cIDkziLnJhHCx2636Ca/EilPzI1clyMkKDS
# 87ya/+cVj1bK2/aqYK0IUWK8ZRapTbT+xR5GihBkaJA4lCfT3kKPeKwiy9E/wpTu
# E38QMjwdWxv80/MwUu9HOetGePRM6cOI5NRydjCaT5d+hLWjCyRwIILAedsLTQPn
# zPzfLsrlkkHvjmFyfgITadHd7pEayvjbLmq23ox3P+zsxOcNLZSZUdZfVf8dl7dS
# VfyCP+3rcvnTEg+qREIER0zUAM1RpJ+j05CIpv9uPV2JkIZN8QNQEEuinWaGTAgX
# zZ9qmVXZu6xn5TiRAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUqsmljPjy3Oi69WQF
# W2EBIWlD3cMwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAJDo18uatFqGBW2BaDfz
# cZpLTt8fKh3puFxQ423a1637oFo24fSvsAGRUeF46nEF2tSs4RhURoiKL10rdy5k
# s2anWJQDH9VuY5liXvHP602uMJaquDWNCarShEHyIThAmnA2EY/ruhjmG5ghTQPi
# WEOhqGp+Aomf/QGT71QoM/DleVRiat4WYmWP1hDNw896nwzEFfGH9jkju9B5Fpbl
# KO2ItA4tGTeCC+toOzlJ/j0wlXr8HDFcLau9R8QVfpJQOiioogT02BUhGrRFm7s6
# 3SLQiz4e88/SEHorA7EyDVJYo59O0Wlal2jwwm+AoIeQ+lcTOCms/6nIge47uBVG
# VJOxtgEUuHbIh3+K0zi5gvRH7ZJIEFOlJJG2Gsa4SYSUjkEIczHMyD+iodI/BkAg
# CQzYLjHGLRK3uoy4D6b5nMViR+gXjVChImf4eOqGpZhDSb9I738qclEklTAx3lOI
# yeNn4T8MmJSvLm52JbJCm9+PaFAUjR2OFqGgBcNrN4RyIsXa4SdO6v1R+NzA66f+
# gxj5Qt+2c6LaMosyut5XT3tqTPP8nGmcOBglT+2BTt9B+WDsiqIv37Tbvr6OhAej
# bWZV5jlgPwqH+RRpjomb85Mzzwbt69PP+qdG6bGi9OMxK2+lsAc1GGZJN0g9NXfY
# LK7EMpL9XlrmLAD5/1WIGj7CMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
# AAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2
# AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpS
# g0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2r
# rPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k
# 45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSu
# eik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09
# /SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR
# 6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxC
# aC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaD
# IV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMUR
# HXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMB
# AAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQq
# p1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ
# 6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBB
# MAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP
# 6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWlj
# cm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMu
# Y3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2
# Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03d
# mLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1Tk
# eFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kp
# icO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKp
# W99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrY
# UP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QB
# jloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkB
# RH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0V
# iY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq
# 0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1V
# M1izoXBm8qGCA1AwggI4AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTQwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVAHWtuYWTNLuoArU5q/TwBSeFs0hSoIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDt//RDMCIYDzIw
# MjYwNzEzMjMzMzIzWhgPMjAyNjA3MTQyMzMzMjNaMHcwPQYKKwYBBAGEWQoEATEv
# MC0wCgIFAO3/9EMCAQAwCgIBAAICGfQCAf8wBwIBAAICE5QwCgIFAO4BRcMCAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEASrhy1eQ3wBmqlmK4YIi7Ct56kFrw
# x1qAjTRpbw4+i9mB9iq3eMw3HmrHKpEi8RDIdrNRbzdPWwRBpPGM5XAKDICnYB52
# TR9+IL3dhMrIyOCixBBKqwCVRuN455vyYei2JSsJ2Cs53+CS1LRiTtSrC8rqJOUb
# NAQrXiLfRdHKjGVcIoODQANLJrKZ/gQZdyx6/zzBaa3NTxFeg08aI1dtOoy/Co2a
# jXvXNTFlRZ856vkkkKNXDwh9WU7Vb74Bs0j5N0cTyw34Lah2Ky3L/IdYNp3p4PDA
# Mzs3K8/FdB3gyOk5qP5lPR/YwJ9pWy8iHDRHLn2a4SKKgSOa3xDQN7Oz1DGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACKPCl
# h9fzyB5AAAEAAAIoMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIGmF1xYwr/nZ+AbDVIMqRPftLhjS
# XVEjwr+H2RRnC3WZMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVbGKRlFg
# Y1/igRVkrV5Pjkf7cZDf+rFXvlXC4G36ItcwgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAijwpYfX88geQAABAAACKDAiBCDnl/15v5iq
# EHNcoB77Wdsa7KvbR4npd+VzKMIP4nOtlzANBgkqhkiG9w0BAQsFAASCAgCKYSNW
# X3v8VzJ6tQ6ZTmJxQnkkVjryE9h5y+gLz4QuZGBmV/CwFZJlpxC8afKvpjl0WMJf
# joA9pLx++vWJL9lPvrkFzBFZ4MLaZrTtPUuv5GFy/zEHssyHDTw8BZ6MKiw/lqfM
# jOST2AzmbLdD7fenxfdZP4KWn1p0Un2PRwbxaXwSCXZHRdVFJCnGijxN2/x2bYys
# Eyor+mvMDj50gsIL591q5i5gYeIf1bpzPUWUiwK4uFC+UA7bIQoV80LCytWWboNX
# gO+nQ7JXWx1BbDRKh14TmoIHqTDJH3hjX+bZdA39lIA/rueLE03tXT493ROyE2Cs
# H+5kfltY/56Zrrrr6vrnaohoAFgJMtzUqzZIR5dVyQ4NiNckgtGLDq+X3ilQ7lQL
# Hw5qGNnhTIpFxNt+GkkSjZdFlsN7Oh07nNNGrkgJS26sJwQVbVJa9TmD19l4BlV+
# CVSks3gzWKWUWv188TB5hyf/RROc/CEdsyHXZq7ie4mhoQ3ONSx5FGdZPpatRECX
# OLr4/ZQF8K7j5/vqURyYN/3ndNv9osutbbrUlP9qDXWC0VNTtZcczD6sEswksCIJ
# 1C5j3CmDzdAFDqI6CNj1y9XjrGCaZ1bO0pG8EH6sGDToxCr10U42E8C6AnsKd52/
# h9tjjlrcg7K1uggJYvanJSu1CLPGP6++xqsk3Q==
# SIG # End signature block
