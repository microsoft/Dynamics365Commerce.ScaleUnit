. $PSScriptRoot\TableOperations.ps1
. $PSScriptRoot\FileOperations.ps1

function New-CsuExtensionPackage {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackagePublisher,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion,

        [Parameter()]
        [String]
        $SdkVersion,

        [Parameter()]
        [ValidateSet('Valid', 'Invalid')]
        [String]
        $ValidationStatus,

        [Parameter()]
        [String]
        $PackageDescription
    )

    try {
        $body = @{
            msprov_name       = $PackageName
            msprov_publisher  = $PackagePublisher
            msprov_version    = $PackageVersion
            msprov_sdkversion = $SdkVersion
            msprov_assettype  = 0 # CSU Extension Package
        }

        # Add optional fields if provided
        if ($ValidationStatus) {
            $statusValue = switch ($ValidationStatus) {
                'Valid'   { 202570000 }
                'Invalid' { 202570001 }
            }
            $body['msprov_commerceextensionasset_validationstatus'] = $statusValue
        }

        if ($PackageDescription) {
            $body['msprov_description'] = $PackageDescription
        }

        Write-Host "Creating CSU extension package record: $PackageName ($PackageVersion)"

        $recordId = New-Record -setName 'msprov_commerceextensionassets' -body $body

        Write-Host "Successfully created CSU extension package record with ID: $recordId`n" -ForegroundColor Green
        return $recordId
    }
    catch {
        Write-Error "Failed to create CSU extension package record $PackageName ($PackageVersion): $($_.Exception.Message)`n"
        throw
    }
}

function Set-CsuExtensionPackageFile {
    param (
        [Parameter(Mandatory)]
        [System.Guid]
        $PackageId,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [String]
        $FilePath,

        [Parameter()]
        [String]
        $ColumnName = 'msprov_payload'
    )

    try {
        $fileInfo = Get-Item -Path $FilePath
        $fileSizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)

        Write-Host "Uploading CSU extension package file: $($fileInfo.Name) ($fileSizeMB MB)"

        Set-FileColumnInChunks -setName 'msprov_commerceextensionassets' `
            -id $PackageId `
            -columnName $ColumnName `
            -file $fileInfo

        Write-Host "Successfully uploaded CSU extension package file to record: $PackageId`n" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to upload CSU extension package file: $($_.Exception.Message)`n"
        throw
    }
}

function Get-CsuExtensionPackage {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion
    )

    try {
        Write-Host "Querying CSU extension package: $PackageName ($PackageVersion)"

        $escapedPackageName = $PackageName.Replace("'", "''")
        $escapedPackageVersion = $PackageVersion.Replace("'", "''")
        $filter = "?`$filter=msprov_name eq '$escapedPackageName' and msprov_version eq '$escapedPackageVersion' and msprov_assettype eq 0"
        $response = Get-Records -setName 'msprov_commerceextensionassets' -query $filter

        $records = $response.value

        if (-not $records -or $records.Count -eq 0) {
            Write-Host "No CSU extension package found: $PackageName ($PackageVersion)" -ForegroundColor Yellow
            return $null
        }

        Write-Host "Found $($records.Count) CSU extension package record(s): $PackageName ($PackageVersion)`n" -ForegroundColor Green
        return $records
    }
    catch {
        Write-Error "Failed to query CSU extension package $PackageName ($PackageVersion): $($_.Exception.Message)`n"
        throw
    }
}

function Get-CsuExtensionPackageFile {
    param (
        [Parameter(Mandatory)]
        [System.Guid]
        $PackageId,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [String]
        $OutputDirectory,

        [Parameter()]
        [String]
        $ColumnName = 'msprov_payload'
    )

    try {
        Write-Host "Downloading CSU extension package file from record: $PackageId"

        $file = Get-FileColumnInChunks -setName 'msprov_commerceextensionassets' `
            -id $PackageId `
            -columnName $ColumnName `
            -outputDirectory $OutputDirectory

        Write-Host "Successfully downloaded CSU extension package file: $($file.Name)`n" -ForegroundColor Green
        return $file
    }
    catch {
        Write-Error "Failed to download CSU extension package file: $($_.Exception.Message)`n"
        throw
    }
}

# SIG # Begin signature block
# MIInJwYJKoZIhvcNAQcCoIInGDCCJxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCkH0lDp4vhyVxg
# HqQpKbs8RRWIikHX+xG/HV6lxe2g+KCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnDMIIZvwIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIEmTHlnvA3iWfg047E+x1uVZorkKLLnmEix29tMQH/fnMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAOPqCa2nA3l+Bgx+/
# +r8QLwYsNoa+YDkLntS4myfV9lxkAYcnSFAfJ4ykzUn9j9WVq4w4YaXxQVLuchjq
# uvOGpoR4fdXEH7vwJxteSz/dBRM2mWTh8CfMPy+4Gk8yvfeS4g6OfLCzZkfnseO+
# 1OPbTOklz/EMOq18MmO8CBIN9qBN0YuS5k2Ck4onb4tUramSvpCeN1+Dre1OXn3K
# kMZc3Me2rJ9T1v+8yY+6G7DPWP9Bn3pUQEyotEDApkIfGOwNre4mupr3Zt+yOL0j
# /Md0Ibd0rYEKf3sK8sN7RnKHcXU5hlgt6UNlxcUN/RYhTthl9a/bYWYeS3duG3sS
# P3ajCaGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2ww
# ghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8
# MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDRtHs30EDxNplp
# CuzABObHWkYmqPjqk8dFt21SCJVrzAIGaqpn3ufhGBIyMDI2MDkyNjEwMDg1NS4y
# OFowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAl
# BgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5NjAwLTA1RTAtRDk0NzElMCMGA1UEAxMc
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMz
# AAACJjW0PmdDk/YfAAEAAAImMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5NDAwMloXDTI3MDUxNzE5NDAwMlow
# gcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQg
# VFNTIEVTTjo5NjAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL//
# D5lkgvlEUWlUjwPdnK427wjNwAQ4PfQ4tiOHffuteNysiU5LOklzhl5TETKWLrHo
# XrObg1Hx1s9v12IOn+E5TMdYbGIDVndFcoFv/gX+iPK83jdIQZapJ9VzcjcGWxhP
# fl5xUAn2RV/3Rg6/b20WMkEFmRi+tP8PDDJEuxw7I/in73+XImMP5QuzdhcGFWt9
# n4xtAH4FgoupG8EpuP/BH1qQ2szFAg2gZoPmNk783+dKyYbY/XO/9y/iBKgwGdZ5
# AgGSN3YjnDUN5e6mna9KI2ZHmwDZmQErfKJBZom9HE4OWR+LIeT0yST9OthOOaM8
# JuF766qEc1HLxSVs69awKrS1G1TKQe/f0OCoB8k2sTw5K3zfmsHMOmutwCHCaB+G
# hWLgAp6rCKRjSdRrjwrRDLzRdPh+IQDcTERk1pEWj02r8bBt+CoqoaZz3GEq5EVy
# O25rgodm+cC+laAQVI4KSi9ez8FwueQQcz3FnyJRqDkLKE2pdhgT/PSlxd1ho0iR
# DrwRaa68ubuD2ih9Xa86bkZU2iCGeRYbqcY+j8nASCYD2hJLQR+8VExY8D+ClK8X
# eyECsoedoSlVJKLcM1vKK5iISz0qjQiRlzzEoV5BFqoZHGsH7av/sHdfzVOmz30q
# EXCD7APzuh3bYXYxSDXHu3C3eBpWcWTQhkjBQ8IbAgMBAAGjggFJMIIBRTAdBgNV
# HQ4EFgQUXeGf19gk3Zj9n0tVsE8jEDNcexAwHwYDVR0jBBgwFoAUn6cVXQBeYl2D
# 9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQAD
# ggIBADZTHS2v2xgKOyrQVHKJWnHXk66s1e/pCTuJf4CtU+XPfDi2qNxM2bV23e1O
# 5rbAkykmE8fyftReGZP3x3kO7jguXhp2ex7hJB9WDdAvppGRceclSfzL2J+0H8/L
# baf3GfA8V+PdCUM5KAu4eV673tTSIfZlqW5hptZcmKF2Jikrxw8cWWpk4CKi3T4Y
# Px0/5Ey6+nG38XYuZh6WmhnCuKIU5SaXERRXvEkfJlmUOq6yR7K6rTUNO/3U3ioz
# xx88+GX/alzgd4x/+d3Yei6J8lsNAU13hY+EvOfRLLe7VmHf5Le2NB2o353LDrRF
# pX5FcKg4uAVncwCD8agOX5+9vmHL/VrvVy1fzARp3U9/p15/amp+XfAVz76GQXwN
# ddNmh8k3hhVo3cifBsAZAMOQ0riWp5wKLHGZIrCJ0/KcZ4Tk6282grWmQuyb+LwX
# VGMZzNn+RIXZUOSobzrqJD6NVsY5DoO7d7LIVwUpmgMngHmYQBL1pPZIqqWUt7Js
# 5ugfqvruyJHkH/Yee7v4pi5hnLQERp20DqeAbhydJH0myuSGGwqZvXW6OrCAnI3H
# 3YyygYbA2A3VojRAgPwKyMIXCl+YzOUDjjEcpi/eGaPF6oFLi5TmtB6ICdWCkl5p
# UYqb+XM8O2emkZX7teFGnlvVnFP9ntfFz4jsfv+MK1ANmhplMIIHcTCCBVmgAwIB
# AgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1
# WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O
# 1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZn
# hUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t
# 1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxq
# D89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmP
# frVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSW
# rAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv
# 231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zb
# r17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYcten
# IPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQc
# xWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17a
# j54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQU
# n6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEw
# QTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9E
# b2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3h
# LB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x
# 5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74p
# y27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1A
# oL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbC
# HcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB
# 9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNt
# yo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3
# rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcV
# v7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A24
# 5oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lw
# Y1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHL
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046OTYwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAKL98zEW2Sqvtcxd2xHJZTSVIodn
# oIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcN
# AQELBQACBQDuYhPGMCIYDzIwMjYwOTI2MDk0OTU4WhgPMjAyNjA5MjcwOTQ5NTha
# MHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAO5iE8YCAQAwBwIBAAICKgwwBwIBAAIC
# FDswCgIFAO5jZUYCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAHrrHI1Ls
# SxTyzws/p13UodF8zKw0TE5OiEHaKPhjll4bwGu2KCtHgOLGDT3LPQZ+ZX/yxlno
# 1E4sSv3apMPRFTa5VgUS+XVfUjeW1yRbhb3ijhTEUaTNbnwtnhnaJVrBTLDeT+6J
# N63yzQjdz40XNF/VYE4RKngeLBNj5Ly6dnCoSON4sVf2u/uymfLH6K9/TbKDeB3I
# vI1YCOxrWHAd8aGeP3/aGg3d0ZcLXXwTQ8Isj8cVmgQkTw1ATzDaoS3nBqKiqR7t
# CNnE9RmGYdTyL4BguO+jd3WMT+TyoxGSzGXASY3baJLdjf3rpilrJWpTnW/rK6DF
# fz5gIvWTULpDmzGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACJjW0PmdDk/YfAAEAAAImMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEILXW9WV+
# Yi46BIjlpDMIe8s5UI0g+SfjYtpczPG8NOZOMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgzDJcYWdM2xlEGuzoY38FtXSiRo0/dUFiosWNSwWduCowgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiY1tD5nQ5P2HwAB
# AAACJjAiBCBRle6Ol1S0GVqHBpqo5qpnF3KS0OCRdrwY1Dvl5lmavDANBgkqhkiG
# 9w0BAQsFAASCAgAv9JeEyNP1sgr2bU/VRJ5V2YGs9KPkjg8RMupSUqRpb2HuFU3x
# ej0BDzD0jH3+RVL7e05ZR7Z5jfNRzYOPVGGEYEZftCOZ4JZaDDKAWnz5qpYixEXA
# jI9zBuN28Bx2v5Vbqm6geVQFif4zDGUJdGzbrVCqt2ch85y5iCP1bQxV/IOJ7vIk
# mZEdsANjjyeAzFIvBzLty+QgU0yKsQb2mWNjQoGcaUfvodPzx5y3P0IV5oNgq+Rz
# Hx4a0eaovNFEwxJZ0t5ttaYjto33BIXBJcXvNypB7XbuWC3sr0kvxPlsjUdhVsbq
# lHNEqnFL4FV5FYAtZr2IlfS+OORajAAUAXtMK3hE93MzLNDB/ZnQ1pMw2V835NCf
# oqjxDibHkCo0hQhtNZafSEZuadSttp4b9GAsfW7RACOUZ8jtM1s1adEshVzA91Z8
# 3WS5OQ4lqo5krHP58UUYjYgpty1zxdhDiQfG51QX2O/V6dIofNJzaGaKha/GJ12j
# WBzV4qLgSKofOZCpL8hPDmcObN3HL526qU1zxoDyLFbnsX00gaYEZuwB3paZ9Ykz
# TTSzP3JJbjpzWA3y9+k0VmZlciGlHXuTzWaN4laOYEB3cDEie7HRDGVjHxu+9Mwb
# duoC4eA+pKOgLFqdHOS2bBRD2tvKpli42Pf44cyGn2fRjI1B2Creg2w7xg==
# SIG # End signature block
