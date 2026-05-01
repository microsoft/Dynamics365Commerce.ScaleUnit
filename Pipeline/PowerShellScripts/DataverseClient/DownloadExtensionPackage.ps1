<#
.SYNOPSIS
    Downloads a CSU extension package from Dataverse.

.DESCRIPTION
    Connects to the specified Dataverse environment, queries for a CSU extension
    package record by name and version, and downloads the package file to the
    specified output directory.

.PARAMETER PackageName
    The name of the CSU extension package to download.

.PARAMETER PackageVersion
    The version of the CSU extension package to download.

.PARAMETER OutputDirectory
    The directory to save the downloaded package file to.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com/).

.PARAMETER TenantId
    Azure AD tenant ID.

.PARAMETER ClientId
    Azure AD application (client) ID.

.PARAMETER ClientSecret
    Azure AD application client secret. Required if CertificateThumbprint is not provided.

.PARAMETER CertificateThumbprint
    Thumbprint of a certificate for authentication. Preferred over ClientSecret when both are provided.

.PARAMETER Interactive
    If specified, signs the user in interactively in a browser (OAuth 2.0 Authorization
    Code + PKCE) instead of using a client secret or certificate. Intended for local /
    developer use only. When set, ClientSecret and CertificateThumbprint are ignored, and
    ClientId is optional (defaults to a Microsoft well-known public client with Dataverse
    pre-consent).
#>
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $PackageName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $PackageVersion,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [String]
    $OutputDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $EnvironmentUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $TenantId,

    [Parameter()]
    [String]
    $ClientId,

    [Parameter()]
    [String]
    $ClientSecret,

    [Parameter()]
    [String]
    $CertificateThumbprint,

    [Parameter()]
    [Switch]
    $Interactive
)

if (-not $Interactive -and [string]::IsNullOrWhiteSpace($ClientId)) {
    throw "ClientId is required when -Interactive is not specified."
}
if (-not $Interactive -and -not $CertificateThumbprint -and -not $ClientSecret) {
    throw "Either -CertificateThumbprint or -ClientSecret is required when -Interactive is not specified."
}

$ErrorActionPreference = 'Stop'

Write-Host "Starting CSU extension package download...`n"

# ── Load Dataverse client modules ────────────────────────────────────────────
. $PSScriptRoot\Common\Core.ps1
. $PSScriptRoot\Common\CommonFunctions.ps1
. $PSScriptRoot\Operations\ExtensionPackageOperations.ps1

# ── Connect to Dataverse ─────────────────────────────────────────────────────
$connectParams = @{
    environmentUrl = $EnvironmentUrl
    tenantId       = $TenantId
}
if ($ClientId) { $connectParams.clientId = $ClientId }

if ($Interactive) {
    Connect-Interactive @connectParams | Out-Null
}
else {
    if ($CertificateThumbprint) { $connectParams.certificateThumbprint = $CertificateThumbprint }
    elseif ($ClientSecret)      { $connectParams.clientSecret = $ClientSecret }

    Connect @connectParams | Out-Null
}

Write-Host "Connected as: $((Get-WhoAmI).UserId)`n"

# ── Query package record ─────────────────────────────────────────────────────
$records = Get-CsuExtensionPackage -PackageName $PackageName -PackageVersion $PackageVersion

if (-not $records) {
    throw "No CSU extension package found: $PackageName ($PackageVersion)"
}

if ($records.Count -gt 1) {
    throw "Expected 1 record but found $($records.Count) for: $PackageName ($PackageVersion). Data may be inconsistent."
}

$record = $records[0]
$packageId = [System.Guid]::new($record.msprov_commerceextensionassetid)

Write-Host "Package record:"
Write-Host "  ID:          $packageId"
Write-Host "  Name:        $($record.msprov_name)"
Write-Host "  Publisher:   $($record.msprov_publisher)"
Write-Host "  Version:     $($record.msprov_version)"
Write-Host "  SDK Version: $($record.msprov_sdkversion)"
if ($record.msprov_description) {
    Write-Host "  Description: $($record.msprov_description)"
}
Write-Host ""

# ── Download package file ────────────────────────────────────────────────────
$file = Get-CsuExtensionPackageFile -PackageId $packageId -OutputDirectory $OutputDirectory

Write-Host "SUCCESS: CSU extension package downloaded - $PackageName ($PackageVersion) -> $($file.FullName)`n" -ForegroundColor Green

# SIG # Begin signature block
# MIInSQYJKoZIhvcNAQcCoIInOjCCJzYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDuuhBjpbxkEq3I
# QkevV8SoJy/SXty0y+sI9mymwbr5yaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEHKW29P
# 4IqKMyPm6g9FfM8fOmcAl2C4LihQvs/4vujoMEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEARrS0e4/IpRLmHlUWbv0/2DLdfLan4HBchei2TNdD
# 0E8ISCfrOR61HyCH9pn1/d8hTKXG1nGzThP4lp6GCLkmOStLYVn81BipKsnpIWU+
# tpLdCmSu/ehyd1XC2YN4oI4gK0yB3lUJIRqoZPeNRH5i31F+U/k9EeHdk/fxUMSw
# yrZSXzk21/BfZFzSrv8ugxfAuTWmLYOBPoBk29RVXgdbTKTmr5e07R7bvHcbUD3r
# drflmid3e3DARHnMc/k+Odku7nPpscIV367GtCepXSF7SfVDoFmrZFfm/E7xHNjX
# FFfVijuEcG9Nl/zZ9xlify2lfv03LPqyIa92OU3+jzmaHKGCF5cwgheTBgorBgEE
# AYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCDcRyUmZr793YDMIMKcNFT4gxT2EIS/5iEyqShn
# A2b9tgIGaegMjr2fGBMyMDI2MDUwMTEwMTExNS43NzhaMASAAgH0oIHRpIHOMIHL
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046MzMwMy0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAiEzwDX70g8hpAABAAAC
# ITANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0yNjAyMTkxOTM5NTRaFw0yNzA1MTcxOTM5NTRaMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzMwMy0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDbcTACqU1YvRocyWL2PL9fyf/+
# ULs2qK7U1aZsRnDZSnlCr7K7jgA3eFCEJL5BZ7dUTC0DeZepf+ZC+7HEbB4IdzmJ
# fQAUDFFerqY5VTHmQvP2XA3lWSFj740idcGUHglP5H/PbCJU7GAHWP2HdcCjdx1l
# YAo0A+zLI7xwnTQeMyOXX212Eg4UmDPPJgxdTMw6WFVWsBPWRBi5gDixy2s+7R8A
# Dk5lbBBFDB5h0CjrNWIN7uCAzF5g7trrL8nXIKp10mj9RxhcGQ+tlht6VIvdygRV
# TUGdzFB2/nBvJqQ9kxxFltQST70fEdx4TyaKow/f5+BSh4z4/9f7NXIVVTLn/8kc
# JAfRqFmRrrFt3IKby7VrzmYuoQWD0lmNFtGQ57BrJkPrPFAPek1ALtcbb7FH3nQp
# vi8ngz/MFX/+cnmNFWFU29VVLmzB9XvLZxbYvkeett0mh5lfteeN2rEwUyrdrKuf
# z9h2S6pbate+C2h02CrXwSka0x6ezpTmGkIJLFt25ub/UYXNLdHdsxGD6EfckOIo
# JYsm4MS9F/vSqLNHK89I0vTLBngQEp6LIFkINanRT3PtNx3pNKRKJRALc6L6mhW4
# hL4aHL749qPfQ72t5qAMm5xiKYMgJ2WanidRLNuI251JIN7raaeA/2vb0XFkZcIb
# TR1pfQGsco4U0g5tjwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFOYjIs5qa6pfuquP
# yyK1FTr5QDCnMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1Ud
# HwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggr
# BgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# DgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQA4I/3bkdnTxD2rFum3
# MF8xVKdEkohAObbePrQ+0fr5bRimjz9sVkKT/7gcj4OMcClSYG+IdX6Mp3EYsLHW
# fjvwfzFoeZE+yTbdBj/1VHZQRuCmw6QqeVCTbw2nnS7nBxnWd9oZXbPUpqEawH5D
# qXQaWFgR9A4KWVK/IvXVDMj1PlPCES1P3JonNbdhkkkz49rJuKOm5b7e/BH8loqA
# mXOXRc22yxWVTMWrEp4pslmv8eT7VoY8X/jdKYTPVEXsfmLbVFcqzMuB8vFGfUyW
# sWROS8wgq7lQYfWcYqh7NymoATX+wWYK3zWG7aRciPGUAzznXdf+aHtIWnQLNa5H
# FmSXkiak3fSuprWYZiHhuYjE16hroApcBHpm+8S/kNqhm9WjQX+2BxnYv+Jejy6l
# qTi8fLBLS069WXVw/ptf5IV+FtYl34GvVoeg31UoUmVVZe1SDUJkm9dDXc8l/qBD
# YiAIT2CCsPTyt9XA9JVuHxdP63n7ChvWAO/47QRuCDsUlFJoWwyBwl7jeYpaRVMt
# Qt0iuJMGGjgEaJX1Q/2j8sXURvTceLHDD9ipWt092ZDWMQciDRmhHNFOX1dnjBvk
# /k1UMcg997j5oYznAnSpJvlg/4BP3aVE0h/YH2KgsKbU4NXZHAjJXj2Slqo1C115
# CG6qBZaFkM8W6vPZCm5qnSezOjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkA
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
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjMzMDMtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEw
# BwYFKw4DAhoDFQALbEgZZnyYHXJ1DGb5fGjplXptuaCBgzCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7Z5nCDAiGA8y
# MDI2MDQzMDIzNDA1NloYDzIwMjYwNTAxMjM0MDU2WjB3MD0GCisGAQQBhFkKBAEx
# LzAtMAoCBQDtnmcIAgEAMAoCAQACAisIAgH/MAcCAQACAhLKMAoCBQDtn7iIAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAARXk8+eSnlzsb1cXKGh2w0JXW4o
# TEaj696+/Q47SiEaL8ee0Gq7zGxC1TfmmYKoPj5vqHqzT7shXwuPLznZ0bNscjYO
# o84AS6iwKvns/KRerbftRApELmXC7W8+G0b1JrYcwZjcQm26qK25fwI9qGILqW7e
# O+9vkj8uqJul66Xnq5+l/OJYWNHwuPZ1dGWm866GGJXwwRZ5dsDC0x3kAg2a/3QU
# L6/beHqjiqlXTrupc5xn5hLijnMG6QXhiItoO6m+XWYg0vCaOh2s07U4mEZBzATj
# eLncTeyVC61jMi4L2I84Q4G3dOP05rKrDMf/tnxdXFxCIg1dc8q8t85hUDcxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiEz
# wDX70g8hpAABAAACITANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBC7H6IuYhpredM/Z30h5fV0Ivt
# 4h2K0qNYIv0zhQCRcjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIADvIQef
# FVUa4BJy8IZywMAvmGSKdUVqEmy9A++PCj1EMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIhM8A1+9IPIaQAAQAAAiEwIgQg844sFFz5
# +DuwaUGekWxz/j2DAVR5/ezzV9PGk46HwdAwDQYJKoZIhvcNAQELBQAEggIAaSMO
# p7EC0uHkNL9IOWMjKRs/g7YBxg47uYCKz84ils3fjxpqm/ngfYHzDCHAo33sIgHw
# LFgJ2NlQPr9hISgsJ6GJGt+iuMhR0cVgFJH+zoy3eNIebuHOD7ocyfJjYIAQzFqc
# Q2PUCcs+TFYXSOZeVHbgk9knaBOs7nZYYYsmX8mcQTvyLxilSI9Itpl29d1t8vWr
# ZfWpHwpT5myE6DArcDZXsQTzWLQMQZlD1sqkmyYNLGFSkY99viK2BV5aQ798J3Nk
# G2ZtGBhJP62P0GGPE8i0B/Uc+TrKMDiSuRIPFNxVul29+zMAFeCSz7pZO3MHgZxz
# eXIJ8kXh1/+vZPqEMAjH4eCyef9JmRqINGCgivUonF7UR60tO27VdENsOwYM4zaq
# pG/6iUxJGnqZYA84FwWG1yXILkP6G5aCI/4jXj+qkll/A9B/aS9nDsgq0xYLIFBh
# Almm7IEX2tVm5p4Nhd6dsKxkzYgwVJjNZB65necWv0nNWHuLxpTBohv826H0QuWn
# NOcv5/WvFFzMuTykkhfY+1M5DS1/p7+EAkRQAoZgquHPYf/xQjoeLQ4MF7mavqAZ
# dTY3kyhqToejQTNMRjytWkbWlkzH3gFN0XBNcU/xqv3x7Z5KuAijhIyIwKMb5VtA
# qHlQIGALXWxEibCAGbCLrvyo50J9aXGMdpa5HJA=
# SIG # End signature block
