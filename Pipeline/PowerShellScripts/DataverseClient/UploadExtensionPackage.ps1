<#
.SYNOPSIS
    Uploads a CSU extension package to Dataverse.

.DESCRIPTION
    Connects to the specified Dataverse environment, reads package metadata from
    the embedded manifest.json, creates a CSU extension package record, and
    uploads the zip file in chunked mode.

.PARAMETER PackageFilePath
    Full path to the CSU extension package zip file or the uncompressed package folder.
    If a folder is provided, manifest.json is read from it, the folder is compressed to a
    zip in the same parent directory (replacing any existing zip with the same name), and
    the resulting zip is uploaded.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com/).

.PARAMETER TenantId
    Azure AD tenant ID.

.PARAMETER ClientId
    Azure AD application (client) ID.

.PARAMETER ClientSecret
    Azure AD application client secret. Required if CertificateThumbprint is not provided.

.PARAMETER CertificateThumbprint
    Thumbprint of a certificate for authentication. If both CertificateThumbprint and ClientSecret are provided, certificate-based authentication (CertificateThumbprint) is used.

.PARAMETER ValidationStatus
    Validation status to stamp on the package record. Valid values: 'Valid', 'Invalid'.
    Defaults to 'Valid'.

.PARAMETER Interactive
    If specified, signs the user in interactively in a browser (OAuth 2.0 Authorization
    Code + PKCE) instead of using a client secret or certificate. Intended for local /
    developer use only. When set, ClientSecret and CertificateThumbprint are ignored, and
    ClientId is optional (defaults to a Microsoft well-known public client with Dataverse
    pre-consent).
#>
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [String]
    $PackageFilePath,

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
    $Interactive,

    [ValidateSet('Valid', 'Invalid')]
    [String]
    $ValidationStatus = 'Valid'
)

if (-not $Interactive -and [string]::IsNullOrWhiteSpace($ClientId)) {
    throw "ClientId is required when -Interactive is not specified."
}
if (-not $Interactive -and -not $CertificateThumbprint -and -not $ClientSecret) {
    throw "Either -CertificateThumbprint or -ClientSecret is required when -Interactive is not specified."
}

$ErrorActionPreference = 'Stop'

Write-Host "Starting CSU extension package upload...`n"

# ── Load Dataverse client modules ────────────────────────────────────────────
. $PSScriptRoot\Common\Core.ps1
. $PSScriptRoot\Common\CommonFunctions.ps1
. $PSScriptRoot\Operations\ExtensionPackageOperations.ps1

# ── Resolve package path ─────────────────────────────────────────────────────
$packageItem = Get-Item $PackageFilePath

if ($packageItem.PSIsContainer) {
    # Folder: read manifest directly, then compress to zip
    $manifestPath = Join-Path $packageItem.FullName 'manifest.json'
    if (-not (Test-Path $manifestPath)) {
        throw "manifest.json not found in folder: $($packageItem.FullName)"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    $zipPath = "$($packageItem.FullName).zip"
    $tempZipPath = "$zipPath.tmp"

    Write-Host "Compressing current package folder to zip: $zipPath`n"
    Compress-Archive -Path "$($packageItem.FullName)\*" -DestinationPath $tempZipPath -Force

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    Rename-Item -Path $tempZipPath -NewName (Split-Path $zipPath -Leaf)

    $packageFile = Get-Item $zipPath
}
elseif ($packageItem.Extension -eq '.zip') {
    # Zip: extract manifest from the archive
    $packageFile = $packageItem

    $tempDir = Join-Path $env:TEMP "pkg_$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        Expand-Archive -Path $packageFile.FullName -DestinationPath $tempDir -Force

        $manifestPath = Join-Path $tempDir 'manifest.json'
        if (-not (Test-Path $manifestPath)) {
            throw "manifest.json not found in package"
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}
else {
    throw "PackageFilePath must be a folder or a .zip file. Got: $PackageFilePath"
}

# ── Validate manifest fields ─────────────────────────────────────────────────
$requiredFields = 'customPackageName', 'customPackagePublisher', 'customPackageVersion', 'sdkVersion'
$missingFields = $requiredFields | Where-Object { -not $manifest.$_ }
if ($missingFields) {
    throw "manifest.json is missing required field(s): $($missingFields -join ', ')"
}

Write-Host "Package file: $($packageFile.Name) ($([Math]::Round($packageFile.Length / 1MB, 2)) MB)"

if ($packageFile.Length -gt 1GB) {
    throw "Package file size exceeds 1 GB limit"
}

Write-Host "Package info:"
Write-Host "  Name:        $($manifest.customPackageName)"
Write-Host "  Publisher:   $($manifest.customPackagePublisher)"
Write-Host "  Version:     $($manifest.customPackageVersion)"
Write-Host "  SDK Version: $($manifest.sdkVersion)"
if ($manifest.customPackageDescription) {
    Write-Host "  Description: $($manifest.customPackageDescription)"
}
Write-Host ""

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

# ── Create package record and upload file ────────────────────────────────────
$params = @{
    PackageName      = $manifest.customPackageName
    PackagePublisher = $manifest.customPackagePublisher
    PackageVersion   = $manifest.customPackageVersion
    SdkVersion       = $manifest.sdkVersion
    ValidationStatus = $ValidationStatus
}
if ($manifest.customPackageDescription) {
    $params.PackageDescription = $manifest.customPackageDescription
}

$packageId = New-CsuExtensionPackage @params
Set-CsuExtensionPackageFile -PackageId $packageId -FilePath $packageFile.FullName

Write-Host "SUCCESS: CSU extension package uploaded - $($manifest.customPackageName) ($($manifest.customPackageVersion))`n" -ForegroundColor Green

# SIG # Begin signature block
# MIInSQYJKoZIhvcNAQcCoIInOjCCJzYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBgUYoSBZEPOZvY
# lvUz1p2GbW4279F+eyI8NdV4NuYsHaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKMo732W
# mwzxAKQPKwN2RKyVhDf7GTnfu1v3fpthZ7D6MEIGCisGAQQBgjcCAQwxNDAyoBSA
# EgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAfTJGTd4S4iOuSuJBrwyI2JQ0W+7OoKqVHts9/oi+
# YBspowXlrmq9057h1skOw/jhReI7/G+UYNV1J/JK90PbvFurVsUk+NVX7vwFdcq9
# 6IEEb5o52MtLhCJaUeflGLDrcv+RclPl4g/GwJaS0TYAeoDzZTtOtbZewEb4hsAj
# KnwlSdVa0MqSsYA0W5EBZTs7TQSuiYfzqalMa4o6765jJ0o4pBcd+VSEX9H3Bi7k
# HMMe9kyQi3PSR7fvz6AJ/6/+Nkhn84LQgJWV1x4/zK9JZXUBZ3xedFsv7ZsIsu56
# vaZJ9NaT+SACKjV0+hroRVutLEHEqPb/jiW7SnattK0h36GCF5cwgheTBgorBgEE
# AYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoD
# ATAxMA0GCWCGSAFlAwQCAQUABCAa131rRqgb3P0Xa8fFq+mLEwTj7hKhhtK5C8MT
# bDtYlAIGah9M6IoAGBMyMDI2MDYxMjEwMTIyMS43MDhaMASAAgH0oIHRpIHOMIHL
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046QTkzNS0wM0UwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAifVwIPDsS5XLQABAAAC
# JzANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0yNjAyMTkxOTQwMDRaFw0yNzA1MTcxOTQwMDRaMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTkzNS0wM0Uw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDixWy1fDOSL4qj3A1pady+elID
# LwnF3UuLzJIOWwGHcEgrxxwtnyviUIDmmxylTUl1u+2rBPp2zT4BwwQhvGaJpExq
# vPLlDFlbfmSflKI86eFqofiZ7j8NTRO4l7wGg9Njm+muNauTcFW2qdfIjKE950Ok
# rm9MnMOGYy+fibNYdxTPRPq1T4MLZK3s3vdMyMEOldcOQkSKpxD6/1Gk6gOmCu2K
# gI8f0ex6vYxnKDl9W0OLSEa/6y82oIbsm+1QBifOQ47xWKTG1CmvtGr85LzA75/M
# AcUmRw5/of/qET0UFV1WulMcJrI6DASAsNCNB+6WLrotuBZAj+VMlqbn5RMZ6Q4I
# Y7JwaAiIXh7VjxrnwUOYZG8WEGhfrA98di+7LEn9AqvvEOyG+UQcjVhCCbMGXigJ
# XSApeyeWupCsD0jgQMNCxfB5BLBDWxgdY3dJBEPgxfkgTDQLBggtVv2d5CYxHKgI
# ItB4bI5eSb5jkIG2WotnFetT0legpw/Eozwf39ao6tENY21eVWIzRw/GsmvwjYQF
# 6vVrxOD0pGVsfqGF8s3VPeY7hI2TxHFMqNA0IB/a2NLY7JTxYAKAP/11EJZt7xbq
# DLMgD1YDdGEzGpQijm3nAPCL2CebP/jmu90abJ2W425yglGHTI/nCBrwSpfRCgwz
# rfFelJaCKM6+35aFfwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFNLW58N4MGSG6ud7
# jWqgT92orfReMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1Ud
# HwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggr
# BgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# DgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQAqncud4PSC1teb2H6n
# Ruy7sDiKK13FXJirVB4Tfwjdo2Mb+QL4j7wZ/k4G9P0CANHZFrDQcK0VFDTysrYu
# 8Z0Aha14acDZPsyIoPvAGRRhaHEuf7NckRjkfa/ylo1KyII8jbL9N9sJAqBPL8V4
# FNBjljv+1GHDOw127rZz5ZSTPoAPb2SA0v5yDgcpUMfxglPyp6cnPPoQpTtD9OGx
# 8Dwm2P+o1TPxBIy6I0T9RauulogVCvKwflfeLTcKAvnSG1rCjerSXmU1DNXOsAD/
# bsrSjgbX5mAbD7XTRMF/vawAWESFcn/BjjizxeWZb00aYSlkJA2rVtFlMM481aVW
# XdAbXPP5RzUiWTlgyHf/G7lCxHYWGIZuB13T3aI6Y8mEgn/ou40aiFJo8r0+i0P5
# GdNneWtxiR0CMKUfko+5s/73cwe1Wfp8BKXa270cicVQasFf5sRV7pFm+V7fNRXw
# Cu7anTOmga76zO7/2t+zOlibvphT+Q6Zd+B2qYsSn4xBaY+YzHpnycLW5cvJyhPx
# BCcb1oRYfhRzCADb2utI2EtGCjc2P2ii4LyR4QMb/n8cOweL9IqVTKKzzVk+zZJx
# V3vrp4LyuQXw0O30la6BcHdNAAAB9UC83zs3G9d+AlIfZLM97tMUNKWjbBpIirFx
# 6LTDFXVtZQd7hqzLYByjbjH0ujCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkA
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
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkE5MzUtMDNFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEw
# BwYFKw4DAhoDFQAjHzqthPwO0GDckDMA6x54lIiMKqCBgzCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7dZQMjAiGA8y
# MDI2MDYxMjA5MzAyNloYDzIwMjYwNjEzMDkzMDI2WjB3MD0GCisGAQQBhFkKBAEx
# LzAtMAoCBQDt1lAyAgEAMAoCAQACAglzAgH/MAcCAQACAhKFMAoCBQDt16GyAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAH4TTkO1bzFmSZzz1EZQLkjOT36l
# agtstyRYP9Q4iFh9Z0JcJ+s9waFY0CsvrMlAZzYy9rV4b/7eG62mseODfxaBcHsb
# A5zcEsprMWV4o5B2/gRMsjqTUruy5cGHJM4YZb2GGiftZXxHS6+5dVhb/6/TT1EQ
# FptqxaV0u/JRGAavrDwRCY45JqBvY1Ha7FIS8KjaJmSkPX/wnVFpTMZc17KH0nek
# 16Khki3eZoSjcgoi5SWPtTecxNunW+/yz2jrFw39z5LBENMQvHeXNN8pdnAwBaq8
# ujVIEuJjJn3h0ed2O1Si15IYJ8Hr7lK4ngkskdB6+q01wUTHyvlHXtycH6oxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAifV
# wIPDsS5XLQABAAACJzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBE8evTuF7VISe6FHQQ8dSQk4BF
# OKLXbis2yzsgyGYD3DCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOXnARo1
# oVIcOLJKDqlE0adq/jZ9TXdlnXWRcXGThBFyMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIn1cCDw7EuVy0AAQAAAicwIgQguF72WH8B
# 4mjaJrZl+YMdZUgXgrJc4RHfGy1RLG7XxGkwDQYJKoZIhvcNAQELBQAEggIA4gLC
# VaJWEXgSw8FxWvosQHTkiHCiugKcMiyZ8J7R+PeTTJTc5/Bcpxtjfs7Ky5aFQP/z
# kClGaQqslZKaNGr3W+1mEml8y/kJWmlM41sEnM7BXsolUShimjC4NXjU66tmfTge
# yRYaT4YULUV3ExpUf3/EpayyUlzjh5Jfv2FuSVYJD14GMdx6POHMiiEPb/a4JtzN
# BjAeuWpA4qAt9BPqvuIQTUdfFHuuYyLVwvf/aM4kybCt2PtT+IJ2PPR++0AorQaH
# gj7CiyCd5t5UGihiSAl8KBewSpuFgnKlVMfTPZUXq/RzqFdQ+7QuQP/V/hS849TI
# XEM+sHA4p74aVm6hh23l6hPMtuBBXjxbmCCFRyBYIs1+BejeAlJlf/hmiiHIwQxi
# ySGDq9fYh7B+tXjOq1Kbig9jv7H9dnSiraEHF6QK3sfMKFMQti6cOrCZg+vu/3/s
# 4uzW7fg/QUTMTLGJY/qFhmUgu5I/Jpy/ib9S5izSZTzDwD3YM+/2RjVmVSht8mRo
# DeM8SyVjffPM4E4q6jviq+xlTZ01MHr5pbZNskqoo686gbZ1zG1WEiwdyTVXuXbu
# aKgxKgzLqZ/B8UNpEgb4tAhFew3cW37PKUSXp0saZpZSDjSIG4PQkqtsi2p89Y3t
# MoXDzUBSe7OM5hnjfLDHR4nNpKEhcZGd2+G0sGE=
# SIG # End signature block
