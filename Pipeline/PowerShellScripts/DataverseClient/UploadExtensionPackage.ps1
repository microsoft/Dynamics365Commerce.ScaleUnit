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
# MIIncAYJKoZIhvcNAQcCoIInYTCCJ10CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBgUYoSBZEPOZvY
# lvUz1p2GbW4279F+eyI8NdV4NuYsHaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghn9MIIZ+QIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIKMo732WmwzxAKQPKwN2RKyVhDf7GTnfu1v3fpthZ7D6MEIGCisG
# AQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAdHT7aJU8BB7dKlCtvJ2A
# Z/1mlLMsDJOdRmjVI1PixF0RCoCPi6BBFXWiqdqP2Cs8Esyzb1+1DcEk5BkQQ19v
# zLRqXxt7Wzz2Ut//jcsv4vZks1df9Jy+F/Ix28Xfr1scdVqBAN9NLQvMJjQKZ34v
# r1C/JWbqviMw9xowU+J5F6nNh1TakQoFvfG0ZF9zsIOJ2MVsn5rjJoHw9TVwlVlw
# uhGVmF5EheR60+MhMHP6UxWHgXAsphGaoKxb9TOGHAJYakhDxbp2kAPaR7LtoKiH
# cqyzTsfNNsEiOb086vA4wl6SGWX98lLkGqLoznB3eaVLwyGUWVnAhcV2VVFaHIfI
# e6GCF68wgherBgorBgEEAYI3AwMBMYIXmzCCF5cGCSqGSIb3DQEHAqCCF4gwgheE
# AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFEMIIB
# QAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCBK2R6BYIs7b/E3XUPl
# T86PtWTIks8usfMby6kN2iBG6AIGajWS4fKJGBIyMDI2MDcxODEwMDkxNi45OFow
# BIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjUyMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMC
# AQICEzMAAAIXcfsupa8BHeoAAQAAAhcwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODIzWhcNMjYxMTEzMTg0
# ODIzWjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046NTIxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQDAzzawTD7f29hHuIYIgUOdg2FEz4HMXYBiKrl1SlmkkU9GMJyK
# lDpFRsj5EBg1ECkTHHnKCtdtpa27C+qyoBVJZtT9bp95y6OMguQ+qf2meC1ZGR9C
# BtiC9pcAuXo9jbI4f1/vYwP7oDLFB6dKkAx1TNj9CT+O2Owd0VdUF762yGUiRInc
# ZnDxVUqpODcZkSXO3BslY22uEES+F/pqfEx6BAwk/u07z8EnshOzj8BXcPZu/x4e
# TzVj586ZDyZDrVYurbAi2+XMhPlvN6Ur0u8TJx/nHWVfEDATDlrt2lL4IpNqeG2/
# 5DabB5sDJuN/2KjiTjyy1NqrWu1ys6IPB12pWbVL17yHVOzNcXOMsu8T0SaOc18h
# 7Cxj5EKFRoedjgUXDAkScS/8lLvqgdPSgZ3Lv4nrR8Y6XsDVShTICSGlvYGNr5LB
# IiIdtDgUPImIuVnp2tlnzgygnznYlLEzSEGMY7oVmU87yK43KTrzQOLxWdtI2kh0
# k34OGV6l5NQwEMeoKZ3SZVZFZk+bWm+C3L3dqw2382DqjibZ2eihY50zfIqwlpaP
# IeqJz2B9OtkEz48Jep5No7WgSJpD6HjDScdV1X5dK8jabXI3iKJuqObkc9oA7c4n
# 46Y0t+01WavhnpTZPqkhwsHKygpwNS8KrJxePgL/6fUoUGkMZ0MzD2Ca7wIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFFCs32OXA06h4TllCqcXnHxLVslDMB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQBGaAV2EHvEgAgcQSDkj/lL6DHrtpHpGJbxkDC0TebP
# yjR3Kf6kg/6WJ01HUgpBDSv5GNiAj1xnqZu8DK+Hd7ar8FXyuMcTe530/JjKrfZ6
# 4WB1ne9fhvlBd49aWkEBit3OJHbusfPpbCkfl1mxLKltcMFtCRaQ2XqDzbJPLcBs
# FsoNcF3PFmwRq5o6mVq0rsSvh2GCUoF7HwlDZ0xKRJnB4I0Nep32v/1bZV1FmwMk
# o/9dzhTJCVWxugGi0q1gRJcWSPBHUdWwf5DQLr383kI/9OrdiAjW5vhv37cwkUpa
# ElcJwkYVmRwvBSZjCgWDVcujsMsl0aOsgfWOwjY0VckVAd5/oB1F7URG9hB6q3Ks
# G/Ei9H4//zcU1jLPHTiKdRP1MXYDBM66oILpnrug3BHikQQnIAgRES+R2GON9ZyC
# yT+cZOV9qG81j9I4es1Eqjj0oOVxw3NEIlDJD4Pn2vv+p5s1LJA9N/Aj376MRjRD
# 9RYpU0uGKjnkZgGx4n32zs3OR3E6v1R+2nn3scSi9sDr2oaVnc6lQTcfVEEYNWn8
# W8za5dO6bwusyQ9fHkCn+Rs8BKwL2O72gwJ7YgRc7ZJ4PVoPciq8A50cUoeDW+ls
# 9RBJZvqDbF8FXfTAVypo9iDNxvE9Y/Jmor5LyXvPDrho7mGYnt5DCgx9O7RVrLqv
# jzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
# BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4X
# DTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM
# 57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm
# 95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzB
# RMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBb
# fowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCO
# Mcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYw
# XE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW
# /aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/w
# EPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPK
# Z6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2
# BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfH
# CBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYB
# BAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8v
# BO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYM
# KwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBW
# BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUH
# AQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# L2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsF
# AAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518Jx
# Nj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+
# iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2
# pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefw
# C2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7
# T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFO
# Ry3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhL
# mm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3L
# wUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5
# m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIICQQIB
# ATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjUyMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQBpsoAVoq3aFpR2qQd8VjMDN+BIy6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7gWiIDAiGA8yMDI2MDcxODA2
# NTYzMloYDzIwMjYwNzE5MDY1NjMyWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDu
# BaIgAgEAMAoCAQACAgQ1AgH/MAcCAQACAhMdMAoCBQDuBvOgAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBAJ3ICYrrJeiBpig6PwLqHf5bVMrgdpZIQMQ86ozi
# BVWdnqnv9IIeGt0zV/zScAJvC6GLaas6b6EvIAMzNz+YRQ6+21OQZ7Q5OMNL/oMd
# Kd/UKAJ8xVfMa6JTgGys0l846bdRwX+JK3FHPkvE+VOHsN3ZU2veyXKPh3eK4y8a
# 2aGXoow9OVeZ+bIzlLSiAYHOoztMx+2L2AzHDuO7XRXflHBrS7l7Q0AQSMoq/32s
# 4kiLQW1K6PQ5GIT3ZqQtkOx5/5sOTurNxtbUBLCdu3iWZ+YZten/NpsOn/0/Qxkf
# I6OOCSKf0fO04m5s82+ohEfMdFiipOFAn07tstDzlGX5fkIxggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhdx+y6lrwEd6gAB
# AAACFzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCACFmrA07nOy9tmuyevItHDUEDm9p+T/kiffjYx
# OdiwxDCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EINDyUGA+XbfJnRLNRK3m
# mE4h6Ac/LCuQ3B6/F7aT5FpbMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAIXcfsupa8BHeoAAQAAAhcwIgQgCu+JlMwlBMHFBlEC04Bf
# jZVd2oZfHYoa2wu8OqEqdCowDQYJKoZIhvcNAQELBQAEggIApwmDuwRmLEaalPRf
# yPKGtKaFS23dxuTpA8ZpV0nGgUdMteW73zZ18qB9vjAuxpHLlGFh2WM7hUWLKETs
# 4q5/+AcbJEybwJcV+6yt0nQRDYvMIqYyihceqvnW6wEc8KS0hWkuq2Bw9Q3P2gOS
# /BDYR8a14THaSLHiJgbK+uQqq8PdHJnUNwubLH9aRbInPwhQICpWtZGWMHD1Er2r
# WU+t9GNrKTvg6I0XvnMfRrBSRnCYMXtpaSQZcH2b19Ccow/16b+9gRF5oNQf2Mkn
# P008gzKUrwf4+QVtm0zCEYLA8eRvV0XKdqWbZ/6cP7qM+CBmitFu5DbAytStG8uF
# VhI76AI9ZaE8aXUzTVE6S1wIEd4Se33M7QNuS3YYvsq3C3y7Q3NhUYy0fx1vSreJ
# gl2RNLPO7gnzMcZq3nsZqKXr0pAQfITCZDOhoZSr1WQL8ijAHW9j+DzGU8ylKyjP
# fVuR8lr1H+MShYaD+KG09GqBfDJfAKewRjYJUWUAHnJNi/0VKCUODwQNn2rG2qFb
# bUOqcyYVQWNlj2FPxrZnxWvTQbXVrd76/srE0BoWEXrXlGLxNAVKhYA0hpv3Ehvj
# MBo7048mp8tIoKHSku+gtQdVQGUVVswwJAwoH6KFk/+YBR9AylT86CVpkh81bFEb
# n1U9WfOqQ4CPp0ocG+A4c/C/4fs=
# SIG # End signature block
