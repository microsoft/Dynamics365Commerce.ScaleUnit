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
# MIInKAYJKoZIhvcNAQcCoIInGTCCJxUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnEMIIZwAIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIKMo732WmwzxAKQPKwN2RKyVhDf7GTnfu1v3fpthZ7D6MEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAbeWEyhro87AN0kEJ
# 1PL0D5Bux0eTmHp5UREjIS4R1yp0lMHkQ0d/HC04cJW2M8KXqE6kfqd+vX6z8HaH
# MrOHsCIqzbntw1aHc28BdMm/ociyC7DuaYy4khGsS8v6PFXdT9J97LCh/rFum9XD
# xvT9pORmlpundes4lOuoIQwTvnIjzSm+JKNkVrECPaxkzhj3qOpszFUHpx48davA
# 3a5Eny+vFNnmZ0qtlIeksZ/lxuh5gU/SwvykSkPboEjNtYQ2efysQqR3kIhbZcoM
# bpHCyAXHT1DwHVObRwWh5EkS+mfHRQE1fxtOjJS4rNVmICS93Fast+7KzAQSUOhI
# l6Tpg6GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20w
# ghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAlBgm0BsRtHIoq
# ZwTgUnN2TjvdHKwPGYMy8APqZAtqrwIGal9XNagHGBMyMDI2MDcyODAwMzIyMy43
# MzZaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTQwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgIT
# MwAAAijwpYfX88geQAABAAACKDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDZaFw0yNzA1MTcxOTQwMDZa
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046QTQwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCu
# jvbk/sqcCSReZaJfCuf1NwRcc7XknhE6wkLofkNj1mxEAg35qy2xcFjgjartVvA0
# 9W8QHcpyMqVSXOTxNHJsmk0qP2CDLvUAulWg7aS5oBORpEX1oz3n0R2nPqeH0IHK
# 1zJxjxaHW21AbuZ0Z+wM3WYNzkBlcHmVe03ZG7rlk28h72r5P5ME8FGpFmYW5Hl7
# psKbgLEfrYAitpttsb+sZsBUI+hMKl4uLJYotKyZv1ewOIinBfRU8QosivjofaBe
# zUf9NdV+iGrWh321WnSsK3A/Jl6GLtbSWXcJWULgbxuqnobPK+YlB3174TMWTgX4
# YWjG7o0Otz/pjHNCKBbB788dynhLdGY6B08E9+4SGrRpsty4iJHOydHCA5M4i5yY
# Rwsdut+gmvxIpT8yNXJcjJCg0vO8mv/nFY9Wytv2qmCtCFFivGUWqU20/sUeRooQ
# ZGiQOJQn095Cj3isIsvRP8KU7hN/EDI8HVsb/NPzMFLvRznrRnj0TOnDiOTUcnYw
# mk+XfoS1owskcCCCwHnbC00D58z83y7K5ZJB745hcn4CE2nR3e6RGsr42y5qtt6M
# dz/s7MTnDS2UmVHWX1X/HZe3UlX8gj/t63L50xIPqkRCBEdM1ADNUaSfo9OQiKb/
# bj1diZCGTfEDUBBLop1mhkwIF82faplV2busZ+U4kQIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFKrJpYz48tzouvVkBVthASFpQ93DMB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQCQ6NfLmrRahgVtgWg383GaS07fHyod6bhcUONt2tet+6BaNuH0r7ABkVHh
# eOpxBdrUrOEYVEaIii9dK3cuZLNmp1iUAx/VbmOZYl7xz+tNrjCWqrg1jQmq0oRB
# 8iE4QJpwNhGP67oY5huYIU0D4lhDoahqfgKJn/0Bk+9UKDPw5XlUYmreFmJlj9YQ
# zcPPep8MxBXxh/Y5I7vQeRaW5SjtiLQOLRk3ggvraDs5Sf49MJV6/BwxXC2rvUfE
# FX6SUDooqKIE9NgVIRq0RZu7Ot0i0Is+HvPP0hB6KwOxMg1SWKOfTtFpWpdo8MJv
# gKCHkPpXEzgprP+pyIHuO7gVRlSTsbYBFLh2yId/itM4uYL0R+2SSBBTpSSRthrG
# uEmElI5BCHMxzMg/oqHSPwZAIAkM2C4xxi0St7qMuA+m+ZzFYkfoF41QoSJn+Hjq
# hqWYQ0m/SO9/KnJRJJUwMd5TiMnjZ+E/DJiUry5udiWyQpvfj2hQFI0djhahoAXD
# azeEciLF2uEnTur9UfjcwOun/oMY+ULftnOi2jKLMrreV097akzz/JxpnDgYJU/t
# gU7fQflg7IqiL9+0276+joQHo21mVeY5YD8Kh/kUaY6Jm/OTM88G7evTz/qnRumx
# ovTjMStvpbAHNRhmSTdIPTV32CyuxDKS/V5a5iwA+f9ViBo+wjCCB3EwggVZoAMC
# AQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIy
# NVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9
# DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2
# Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N
# 7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXc
# ag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJ
# j361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjk
# lqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37Zy
# L9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M
# 269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLX
# pyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLU
# HMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode
# 2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEA
# ATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYE
# FJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEB
# MEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# RG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEE
# AYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB
# /zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEug
# SaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9N
# aWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsG
# AQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt
# 4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsP
# MeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++
# Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9
# QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2
# wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aR
# AfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5z
# bcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nx
# t67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3
# Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+AN
# uOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/Z
# cGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCB
# yzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOkE0MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQB1rbmFkzS7qAK1Oav08AUnhbNI
# UqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7hJmgzAiGA8yMDI2MDcyNzIzMjEzOVoYDzIwMjYwNzI4MjMyMTM5
# WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDuEmaDAgEAMAcCAQACAgTeMAcCAQAC
# AhKqMAoCBQDuE7gDAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKg
# CjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAIrErFLR
# D7D+JGvZ9vtViyAj4Wf/3pPUmUBpg/efT5vVopAu9CHxxqs3cPNPb1Olxw7Hqii5
# uxACD/zKj3SHTFq1LdrfEqJoh2ZeP1MQW51E4+Q3V/PMWMxHOPgE7rVI31Esqisn
# xozljsUKUzYQ8Phcvt3fPL9jWk32+gD65Dwu/jbZVdfNRLm/sawqEbO2N4rBed65
# BmIRIGzuLso5mNe/tb0Uilodl4OOs1/9ZYYH3eDTQEyM+JDEVts4CzLn9cmHPt7m
# gSV1gZRipGgB0Olu/pNkqYjWGcm4WXAL0WTXuVoAnmM4Gq+CPRb0pbFtLiiLqh77
# Cc0wip4o/2YMyJoxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAAijwpYfX88geQAABAAACKDANBglghkgBZQMEAgEFAKCCAUow
# GgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBb7zyg
# u7l/t1VPt1nMQRr8ZqJD7Y/7LguKD6t8AtMOCDCB+gYLKoZIhvcNAQkQAi8xgeow
# gecwgeQwgb0EIFWxikZRYGNf4oEVZK1eT45H+3GQ3/qxV75VwuBt+iLXMIGYMIGA
# pH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIo8KWH1/PIHkAA
# AQAAAigwIgQgZ6aZC/yQC9X89rs2pRTU+dz+dEnAuqM3bseoNkUKOHUwDQYJKoZI
# hvcNAQELBQAEggIARceuMGzF9w7b+cj0qWLh1zElizn0yImB5ZRjT+qMfpWM2uBg
# WkHBT+L2pjwHqK2l1wnmm8H7vN+R5Tu0QIS16My+dDxkEYT4WMk7uc49kuefDTdr
# kr+WtuuTZotn3rc0VbrySzbqLrGg16i9E1oaWBAeXxyRQo2GpZ9GzZTlKB9Rs5Pa
# lPuKxKMYwIGRT9vJX4Bqcw/8cOYpP4fj18UTp4knnsTF8/KdW44X0qglrqjI4zza
# 9LRfegSkY2Fx4jQi5Fih8GFKp/3aE5RxDQbBqhyRIirANaUdWYJczL1fhmXsUhgY
# +LWVC5xcTi0i5lOFAmEuklo1cVjOM8uBoZGTeVd/uDo8lh9Co0AsaUPVLAND+90E
# r5Pk0tJ/z8xD1jL2onwn/lUtog6hZF1reUwBOBRSa+io1aGJlstca0LbacOs5qyi
# 0VS8xvPOaxzAnAjzkocMgaODe9TSrNMJ+H4p03GGrxBvnDXByz9p11GbqMpWm0A8
# C3XoC5T3NvXGvpTjJEKqvcGp5n7pq1ywXqGu9Cyq6JUPWZmk2hXITlJIQjeNfATE
# 12knm1YHkUS7ybRoqYX4EMV0exaEllGWaBlKIIidqDFD8ceGKSXoLDB5YjI/xgsM
# DNjZThyeYhyV0/RA4ZEYwxpPJT2jp+zZ5ny2AOC0dO0qtsrDeijeLq+PdMg=
# SIG # End signature block
