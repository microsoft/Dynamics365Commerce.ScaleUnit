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
# MIInQAYJKoZIhvcNAQcCoIInMTCCJy0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghncMIIZ2AIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIHOzdhZNektNXIsyABzoQEpYGRzfc8xQ5BDUesN6bmGXMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEASstHb+7BoOYAqzAR
# qAyCqnXve/IVMPYLaw2EdOvLC6eHed7So+RiwDSMsyAFDNUz1ONIVm8RNxkDjxUn
# oVjdmkWpZywkSZ3g1GDebVts0dfbTVglVuBrUY5AUSupzoF9DH6I2yvdMSTG/aWE
# WO0BKSphj+egtsu+YLK823j+rqF3ylnIq9vgBtQO/8YtSrjDBLjJ5Vy5qyM260Za
# 6bIh2FTKETnxnUJNAjqH7GHJuL+YIpTVKVfYIC9BBN2sKS47ZRhMp4Mj8DzPSwq6
# eSqcDXiW5PhlwZVb83DZed+ZbUTFywD1hSItJbQG2+2PBBrUVXeA1BGwX9Mr41LH
# Z3swPaGCF6wwgheoBgorBgEEAYI3AwMBMYIXmDCCF5QGCSqGSIb3DQEHAqCCF4Uw
# gheBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFE
# MIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCC20y/1xvVmsdMV
# XzqrEl30hfGDU1rTqJltHmE4X+6bqwIGaoihpBV5GBIyMDI2MDkwNzEwMDg1OS4w
# N1owBIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjJEMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQ
# oAMCAQICEzMAAAIS0QgGPMoYT6oAAQAAAhIwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODE1WhcNMjYxMTEz
# MTg0ODE1WjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEt
# MCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MkQxQS0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCvTNOgOSlZC2xl6RLRxXSq4N0pJMaSi+8FpkfQ4AgSLQ7c
# Jw7vsmJfxzgSmr26JsdVlnVb8ui58TXva+RFc75Bg21ZaisQInYBxlDXRukCW2SF
# k2JeVUnwvdDOEqCteuYySbYn7+DzVTbck9w7jBccR+2idPfCl3//3fquObDEybs2
# RuzKBsl/7gBUEw2vhow9CEF3vqh3QowHpau/IQY45TTz3c4W59LkQN7LifjhaBrE
# kTRWe/f846+47DkqnUo+qONgn4v3LAu4Ey1wN8uk1A7+HV4USgytuIQzrtM582Vd
# /FsPPgyWxi8uKjGB3ZfN7LVDGtXX6L4nJUMkyJJ72Ao67OmJBAUTX0NQ+CyJ3KMt
# PNcSFJUsGVGivR4JV/uALpF+Tw1jes7ayCA4vv29TkW4MpOH+wg61xQd4cLjaMEY
# H6190oLUo4FH5SU31o7ODyalQ0jYWCpC+KtU/2mlt4xR++nbAD2+jJOJFa8ODMLG
# jzGUnWexxhMchCuaQX2P8JrQgOa3x+86frieeUk4ZRhlgcwLWXTG2CRhMTURJSqq
# RrAqTuKpvF2cvLJxL51H7NrE+50wMutAXPyWB/L2huTQPwcLZ3OFalg2fmF2Sg8T
# OAKpBQ6ny/dCP+x3hqfK6l7kqgKSMAE4/fKFJDhb1n4OsmeEz+tuxcLuhO/bpwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFFIFuVLFvlxgpg7C939V+hc5+7feMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQBedICSZfv1FzuXFLXA6jNcntXSi7kOe1Vw4mmU
# iQOO8Q3wEhCmHhT6BI4tm5VF4//P1h1SJSRw/AvU8zbjn+QRfUR6CnE1zwcMDqEo
# IeDQAs0Ry7GcY6WAouiRd9R6vUPmGJbw8AEz1H6d6K15OA9ppGUkW8ZNi+i1zS6o
# aIRLmExCEvxE0WGlL1FwhYe2dAYSet05S8ICGzgV5WJrByYtMq/7XzvRz8x5MeLR
# AN15H7v9aDiqGQnaTWIQcl2Zh/yshXQ1EFlx1FNN0d57flJc/md40J8CSMMi5nJx
# G53qPM8sI0uI1jMZcGzDMnKCPgR5I5FPvAy9oW4p5EBehcLfDBi+AiwjXOfcMZjr
# blj7JlKLxQ1I0e6uLfpm/1r5Di8nAOlgrfpLRMHal/vEuKIffaeTtgrvdGD3xbp9
# nYg27NjNnsaGC999+SPgRReDUTQR99jWkSqRukNM/uH8MGq3Og9ezLDYxSH7vK9Z
# yrYEZlK5xroJjpfiKgy5zk9amya846WLsBE0DsBvyQp0JzaA0MtpyCWzB5kRz39V
# AHqGWz9voqTfaeTC4cTEqVp6hJWsoHlT3GWnX5zwn/sYmPhHDsCJDy1yn5aZ/IPw
# rFfZCUpsOLhJSOeCW/jrXtHz5r9wNYnJoy3zbv1aft/bIx503uR8YhDlJmPrpF2F
# 2Vk6rzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNWMIIC
# PgIBATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjJEMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4D
# AhoDFQDlUcGviHTQQ3uNR1DfdIT6puT/wKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7kjfKzAiGA8yMDI2MDkw
# NzA2NTg1MVoYDzIwMjYwOTA4MDY1ODUxWjB0MDoGCisGAQQBhFkKBAExLDAqMAoC
# BQDuSN8rAgEAMAcCAQACAgugMAcCAQACAhKLMAoCBQDuSjCrAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBACx1QJ64Nhts6bHeO7lhf7CveG2YKhg4qhDc73UJ
# T9TUzK1+qLaM27wwU+63HmnSiqbfSlu0g6dwoYcF9Jkv8aUrzwe995diZ4TB1tr7
# xakf3cZpVkI+4c8R0NOVRQYMyqVR4mCualnXaXh4I9uiMOewXmbKJGjBeiy1XDet
# o3qVNkQwl9mvbS5OFVFKZSKrK4POse/71a6c6KQzKmV+KLLO/2kJbpAduT6oOvSI
# 1oINIGuI8uy+m/V7LIg88vkBx7NElHD7zAq5qLVm6m8tQ1iyMQt13WjvA2ff4z5w
# ex6DTaM9PfyAI8SmKtc+PU9zxiAbyZfE4k0alK8jesZ8tH0xggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhLRCAY8yhhPqgAB
# AAACEjANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCDPfgu9JY5WjlBycm+QpPZmAsTp+K2/JUaMvGH6
# a0VOGjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIHP5fka87taeCScfgFl5
# hT4HMEvUnLmgnzBWVM0jF9iDMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAIS0QgGPMoYT6oAAQAAAhIwIgQghx3UU3c/33enKv/WflhO
# S/nQCWnN6FbROSAK7Oqcq+AwDQYJKoZIhvcNAQELBQAEggIAU1MGgiS9KkxlcBDs
# gJ9f1/Jtcc/AujXd+VMO4iO1MuKzevIN2Jh0uRucAnOc4zobIDNgWdeD2mPjYYWF
# j64wskc0lqEB4AQ2Ia6rrMjG/y9iEKI9R8pD9bmRI8mfm24Tf/1xzl1EbCnqtsTS
# mdqH8qkBVoZH0I7WJFEWaaBMrqKzN0NkNUwegS9bVRKz3/csQtEhXnGau1yGGFxX
# PHhmf0rb2400vPMXacWkrixfbzwwpNleHQp4sn9Ow3xeJXcPInp9GUypnPT41a9j
# 2b+CwTzQsSFieWIlGsf0xVy1vOc5yg+hPI4n1TqYhAatlz0DIZBDNf2lIiZqlzNO
# /SvrXLxLNpsWi/5G4JhoWsa46LInn2M3dr2cAA7zslrQXEe+hmAKEg90PqNegOG7
# vTOvExOZd2nGBPTuMuy60J3RtPVd/IkToy8UDRAY43EoaqYHwCbDFRbV6ggIgaQD
# cf7wqdB2NkDsJukf1VjgGBCVeaji4aewWMSc/oTBuGC6WY1QKCKpNRm7ssc1Aw68
# E/d04HPOucShWAGeMbcZYbld2S2BZ2eUZ5aoCrTIzfj7hvvJ0UYXHhQpxhpuktXQ
# GxYEOtfs8P85nY3h4OVzc5i6obT1SP4yYMzhFlA1s+VDY6QrxUg6RfjALg+hN1EW
# PJGWj3j6qyjETEquxotPe8AGAXk=
# SIG # End signature block
