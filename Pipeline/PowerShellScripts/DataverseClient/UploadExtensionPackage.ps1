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
# MIInbgYJKoZIhvcNAQcCoIInXzCCJ1sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghn7MIIZ9wIBATBu
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
# e6GCF60wghepBgorBgEEAYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheC
# AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIB
# QQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCBK2R6BYIs7b/E3XUPl
# T86PtWTIks8usfMby6kN2iBG6AIGajWQ640wGBMyMDI2MDYyMTEwMTAyMS44NDZa
# MASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo1MjFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKAD
# AgECAhMzAAACF3H7LqWvAR3qAAEAAAIXMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyM1oXDTI2MTExMzE4
# NDgyM1owgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTAr
# BgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjUyMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAwM82sEw+39vYR7iGCIFDnYNhRM+BzF2AYiq5dUpZpJFPRjCc
# ipQ6RUbI+RAYNRApExx5ygrXbaWtuwvqsqAVSWbU/W6fecujjILkPqn9pngtWRkf
# QgbYgvaXALl6PY2yOH9f72MD+6AyxQenSpAMdUzY/Qk/jtjsHdFXVBe+tshlIkSJ
# 3GZw8VVKqTg3GZElztwbJWNtrhBEvhf6anxMegQMJP7tO8/BJ7ITs4/AV3D2bv8e
# Hk81Y+fOmQ8mQ61WLq2wItvlzIT5bzelK9LvEycf5x1lXxAwEw5a7dpS+CKTanht
# v+Q2mwebAybjf9io4k48stTaq1rtcrOiDwddqVm1S9e8h1TszXFzjLLvE9EmjnNf
# IewsY+RChUaHnY4FFwwJEnEv/JS76oHT0oGdy7+J60fGOl7A1UoUyAkhpb2Bja+S
# wSIiHbQ4FDyJiLlZ6drZZ84MoJ852JSxM0hBjGO6FZlPO8iuNyk680Di8VnbSNpI
# dJN+DhlepeTUMBDHqCmd0mVWRWZPm1pvgty93asNt/Ng6o4m2dnooWOdM3yKsJaW
# jyHqic9gfTrZBM+PCXqeTaO1oEiaQ+h4w0nHVdV+XSvI2m1yN4iibqjm5HPaAO3O
# J+OmNLftNVmr4Z6U2T6pIcLBysoKcDUvCqycXj4C/+n1KFBpDGdDMw9gmu8CAwEA
# AaOCAUkwggFFMB0GA1UdDgQWBBRQrN9jlwNOoeE5ZQqnF5x8S1bJQzAfBgNVHSME
# GDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsG
# AQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEARmgFdhB7xIAIHEEg5I/5S+gx67aR6RiW8ZAwtE3m
# z8o0dyn+pIP+lidNR1IKQQ0r+RjYgI9cZ6mbvAyvh3e2q/BV8rjHE3ud9PyYyq32
# euFgdZ3vX4b5QXePWlpBAYrdziR27rHz6WwpH5dZsSypbXDBbQkWkNl6g82yTy3A
# bBbKDXBdzxZsEauaOplatK7Er4dhglKBex8JQ2dMSkSZweCNDXqd9r/9W2VdRZsD
# JKP/Xc4UyQlVsboBotKtYESXFkjwR1HVsH+Q0C69/N5CP/Tq3YgI1ub4b9+3MJFK
# WhJXCcJGFZkcLwUmYwoFg1XLo7DLJdGjrIH1jsI2NFXJFQHef6AdRe1ERvYQeqty
# rBvxIvR+P/83FNYyzx04inUT9TF2AwTOuqCC6Z67oNwR4pEEJyAIEREvkdhjjfWc
# gsk/nGTlfahvNY/SOHrNRKo49KDlccNzRCJQyQ+D59r7/qebNSyQPTfwI9++jEY0
# Q/UWKVNLhio55GYBseJ99s7NzkdxOr9Uftp597HEovbA69qGlZ3OpUE3H1RBGDVp
# /FvM2uXTum8LrMkPXx5Ap/kbPASsC9ju9oMCe2IEXO2SeD1aD3IqvAOdHFKHg1vp
# bPUQSWb6g2xfBV30wFcqaPYgzcbxPWPyZqK+S8l7zw64aO5hmJ7eQwoMfTu0Vay6
# r48wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEB
# CwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAe
# Fw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGm
# TOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/H
# ZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDc
# wUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62A
# W36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1w
# jjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCG
# MFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ
# 1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP
# 8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFz
# ymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHz
# NgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3
# xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsG
# AQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/
# LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEG
# DCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8G
# A1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQEL
# BQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfC
# cTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AF
# vonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l
# 9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn
# 8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5m
# O0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyx
# TkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4
# S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9
# y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM
# +Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhw
# RNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4C
# AQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo1MjFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIa
# AxUAabKAFaKt2haUdqkHfFYzAzfgSMuggYMwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO3iCaAwIhgPMjAyNjA2MjEw
# NjU2MzJaGA8yMDI2MDYyMjA2NTYzMlowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA
# 7eIJoAIBADAHAgEAAgICPzAHAgEAAgISPDAKAgUA7eNbIAIBADA2BgorBgEEAYRZ
# CgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0G
# CSqGSIb3DQEBCwUAA4IBAQBOg3NtWzXkjnwn5e0GoELknnhpTr8Yv6Na1K8GkQLD
# FBdQDGhr29A044RPXkC+G/dERlukFbpXay1TiyfrvFO2c2J0AZ1twvbDFKwVqABZ
# BMiMzZXqlta0EVn2HSnZpJIAy+OQHzE7+aIIrNMkybnN6nv9E5vBtU4Y74ul2r2f
# YmxwLuS+3yLmcYjWGwGpV7XpNyh01J/FYsolTlLe+D+/ROfVBjIa9w1YDHcHjY4P
# PBsP0c/tSB+YeP1YdzplWCAvFqtlXXHhglQ5GYzUzsSWOvcPQ5xAkG9k3xypqh69
# JZr9KhjEBpfWs9D8CPeXCh9zcggE92d3LrEMLNpYXqYHMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIXcfsupa8BHeoAAQAA
# AhcwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQgz8anVXDDX1soNzd+bOeO+C1YrN8aJG/6lEZ1hW2U
# DoEwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCDQ8lBgPl23yZ0SzUSt5phO
# IegHPywrkNwevxe2k+RaWzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACF3H7LqWvAR3qAAEAAAIXMCIEIK3QOWpORL4vEgjr+fzjIl5Q
# Dp8VfpfUPlgjFUsYNTBQMA0GCSqGSIb3DQEBCwUABIICAITp+ezDV4Z1S3oBgbcX
# zdK9JtXQqwf6urWuPpB9AfzsFXPNo9udqW/gei5yQ1CQHqi2+Q+qlUCUrODxrbtC
# 6oqYweTicPLjLnueiGWl2YA5SXThx1PzieOUtS8skA2rEi2KkwLG/HNClP15ydGy
# YYzPVN7dhVCRHHiXcChJ2AXjl32LkL8EVqqFxy5Rx8pynz9TIKcvY5rVBCowRvvc
# ITbQLeol+t6ICFndGtakctx1fj2Yttfi9ToJk7VEsmrRtaLF1rwCzgx30IfryAHP
# Yz83ll2WyBCre+ukVFJdJDtjWfWjOAbcixue9VwhAyaT7IiczdPleHd8aa+ny5nD
# bAZsvCiC5RVxiBdpjNyF3COPgvS5BWWJdLrmOKxqqK2sUlbGUWabjby+bWg/tPPG
# Sjl7VLQOpx9iYsyQUnRK1N5tbd3Evrb+YMP0+b97n6i8w6fc+pkoDZcQgsFquJB5
# tVOUKHjpQKBsTj2n3d2tMYMmnpxA4VHO+gQZHaxr6Z9zjTbRtUEkVmnoFhj9DcQ4
# pSnjVnUKIRUikFNNepC/0ZJgpz4GdmXpKC39crjbF2iY+DnIcO45a8RWK7iHbwX7
# PWLci774vbXCKwNcXRQaduXy2ZHepjRVtl6Jf9XeRE1OoV44WkPPKwdOM/ABVTLF
# DtiWDSUTFj4jotLUlQGhIYDi
# SIG # End signature block
