function Set-FileColumnInChunks {
    param (
        [Parameter(Mandatory)]
        [string]
        $setName,

        [Parameter(Mandatory)]
        [System.Guid]
        $id,

        [Parameter(Mandatory)]
        [string]
        $columnName,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.IO.FileInfo]
        $file
    )

    $uri = '{0}{1}({2})' -f $baseURI, $setName, $id
    $uri += '/{0}?x-ms-file-name={1}' -f $columnName, $file.Name

    $chunkHeaders = $baseHeaders.Clone()
    $chunkHeaders['x-ms-transfer-mode'] = 'chunked'

    $InitializeChunkedFileUploadRequest = @{
        Uri     = $uri
        Method  = 'Patch'
        Headers = $chunkHeaders
    }

    Invoke-RestMethod @InitializeChunkedFileUploadRequest -ResponseHeadersVariable rhv | Out-Null

    $locationUri = $rhv['Location'][0]
    $chunkSize = [int]$rhv['x-ms-chunk-size'][0]

    Write-Host "Chunk size: $([Math]::Round($chunkSize / 1MB, 2)) MB"

    $stream = [System.IO.File]::OpenRead($file.FullName)
    try {
        $fileSize = $stream.Length
        $totalChunks = [Math]::Ceiling($fileSize / $chunkSize)
        $currentChunk = 0

        for ($offset = 0; $offset -lt $fileSize; $offset += $chunkSize) {

            $currentChunk++

            $count = if (($offset + $chunkSize) -gt $fileSize) {
                $fileSize - $offset
            }
            else {
                $chunkSize
            }

            $buffer = [byte[]]::new($count)
            [void]$stream.Read($buffer, 0, $count)

            $lastByte = $offset + ($count - 1)

            $range = 'bytes {0}-{1}/{2}' -f $offset, $lastByte, $fileSize

            $contentHeaders = $baseHeaders.Clone()
            $contentHeaders['Content-Range'] = $range
            $contentHeaders['Content-Type'] = 'application/octet-stream'
            $contentHeaders['x-ms-file-name'] = $file.Name

            $UploadFileChunkRequest = @{
                Uri     = $locationUri
                Method  = 'Patch'
                Headers = $contentHeaders
                Body    = $buffer
            }

            Invoke-RestMethod @UploadFileChunkRequest | Out-Null

            Write-Host "Uploaded chunk $currentChunk/$totalChunks"
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-FileColumnInChunks {
    param (
        [Parameter(Mandatory)]
        [string]
        $setName,

        [Parameter(Mandatory)]
        [System.Guid]
        $id,

        [Parameter(Mandatory)]
        [string]
        $columnName,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $outputDirectory
    )

    $uri = '{0}{1}({2})/{3}/$value' -f $baseURI, $setName, $id, $columnName

    $chunkSize = 4 * 1024 * 1024  # 4 MB

    # Use minimal headers for file download (OData headers cause 400 on file endpoints)
    $downloadHeaders = @{
        'Authorization' = $baseHeaders['Authorization']
        'Range'         = 'bytes=0-{0}' -f ($chunkSize - 1)
    }

    $InitialDownloadRequest = @{
        Uri     = $uri
        Method  = 'Get'
        Headers = $downloadHeaders
    }

    $response = Invoke-WebRequest @InitialDownloadRequest

    $fileName = $response.Headers['x-ms-file-name'][0]
    $fileSize = [long]$response.Headers['x-ms-file-size'][0]

    Write-Host "Downloading file: $fileName ($([Math]::Round($fileSize / 1MB, 2)) MB)"
    Write-Host "Chunk size: $([Math]::Round($chunkSize / 1MB, 2)) MB"

    $totalChunks = [Math]::Ceiling($fileSize / $chunkSize)
    $currentChunk = 1

    $outputFilePath = Join-Path $outputDirectory $fileName

    # Avoid overwriting existing files by appending an incrementing number.
    if (Test-Path $outputFilePath) {
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $counter   = 1
        do {
            $outputFilePath = Join-Path $outputDirectory ("{0} ({1}){2}" -f $baseName, $counter, $extension)
            $counter++
        } while (Test-Path $outputFilePath)
    }

    $stream = [System.IO.File]::Create($outputFilePath)
    try {
        $stream.Write([byte[]]$response.Content, 0, $response.Content.Length)

        Write-Host "Downloaded chunk $currentChunk/$totalChunks"

        $offset = $response.Content.Length

        while ($offset -lt $fileSize) {

            $currentChunk++

            $lastByte = [Math]::Min($offset + $chunkSize - 1, $fileSize - 1)

            $chunkHeaders = @{
                'Authorization' = $baseHeaders['Authorization']
                'Range'         = 'bytes={0}-{1}' -f $offset, $lastByte
            }

            $DownloadChunkRequest = @{
                Uri     = $uri
                Method  = 'Get'
                Headers = $chunkHeaders
            }

            $response = Invoke-WebRequest @DownloadChunkRequest

            $stream.Write([byte[]]$response.Content, 0, $response.Content.Length)
            $offset += $response.Content.Length

            Write-Host "Downloaded chunk $currentChunk/$totalChunks"
        }
    }
    finally {
        $stream.Dispose()
    }

    Write-Host "File saved to: $outputFilePath"

    return Get-Item $outputFilePath
}
# SIG # Begin signature block
# MIInNgYJKoZIhvcNAQcCoIInJzCCJyMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB5Qs/8OQ7PkXRp
# G8MTN7VFnOxqW8zfjWBkuQgmOeGpBKCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghnDMIIZvwIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEICxniBSbMP1+S4bTX6NfZFlK7a1Q
# qa9pj3crnRhmS4EfMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEABk82YjWuXJ3gOxZLKPrn8oUuf3HKLod4mN9t4ptYF1tON2NOInzsXsHKM2a0
# NUBzT0KihQe+r7lZ8Y9bJp/Hhm/GT7dR28JOn5fFqGVjOqWSp3eIfF+3vvZnGwqY
# UnchK9MbNswfghdra2yYvx7SltZ0/yUosY5Hk+4wKRLLhJQ76/xqDk4FseHFOLVy
# OYKUM2YetF4Imke9yL/L+Y3g6z7nsuIdZ+QgwOtLxp6TJha984omZRdd4V7rHDVq
# FDseDq/BSuvrWf8iuBoT2lfaEzGbVoUy+fJln9cvThKPL3a8rqttD0NS34R4xAcC
# Fw/eOpMyhk8FyzbGACqgkNxLiqGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sG
# CSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG
# 9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCDKSOETfjWJC3ibpjWwnHbADS7X5WfYkEWS66DgXnc5YAIGan3tM2CSGBIy
# MDI2MDgxNTEwMDkxNS45NFowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo4NjAzLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeow
# ggcgMIIFCKADAgECAhMzAAACJYDHN8bNqndJAAEAAAIlMA0GCSqGSIb3DQEBCwUA
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5NDAwMVoX
# DTI3MDUxNzE5NDAwMVowgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAl
# BgNVBAsTHm5TaGllbGQgVFNTIEVTTjo4NjAzLTA1RTAtRDk0NzElMCMGA1UEAxMc
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAKbxEg/R4sDjpVwI+i++aqwiU3qqSbPkiwdaZRTSd5Sqny4b
# Fp16j5LBYELBDlqVkj8M12ld/KJktlHpdiClE8XN6kiXs4INvg20SyQkIhkORAw3
# Csf1jBTK7vUYaKCwsjF6V4e0De62hVN4eNLVvxSfA5FG2ScqTKtQCtPpmkHauh0h
# yZwty/fHfDCBiU6zQUSDkSxWtlvss1z+d3RtcOn4dM5Za6Lx6hNXAl4vFxU/zr2g
# XyWLlJTzVpra0Ynr8mx6OLP0kxbxIlcoFPYMJcw5SQKwaOic9lGp++gxIhBmC1o5
# PIAmWu+zLRNnvxesaqjKC1CKZCds4Avgo0tIK5blNkRAZMcs5AkaCCBvePmAoLvv
# z5Eg8kD6f+GYcn/HipP8dNM+hV4wJy4EpatBdHX7+lhq7cXB7S1YjIb4tbORGv9k
# 08+6lwDZhyLeqfwdH1HC9CimpI0nCfZGLpqbwBDJ9VXL8EHDS3qOmhE+PAq+5SN8
# LOlp7p247FC1DVcM308DbKX2wOSj/4BdX9I57x5rxChBy/ezcSuQb4unqGe/Do4w
# +JqfiCA2RG2C0HuujU6Kik5Rcmf1jkQ7clQBc1y4z2b7kzLVUS68bK2AAfe7GayV
# Odbdhut9rNrJIJJKdaSFo5nfeGBu5RB8fufY0UQBRz9wXN+YJBSKRaKycljLAgMB
# AAGjggFJMIIBRTAdBgNVHQ4EFgQUsTjSqhdO4wdfcB9lS7WfyfHaH3cwHwYDVR0j
# BBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggr
# BgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# DQYJKoZIhvcNAQELBQADggIBAAed9zbJTKgdlu+/JUoW5eHkfHEci8hpH0lakh8h
# MmVz8qLTeO5H69yTOre2nl8Ufksvt4gVdEi6h7Ayy9Z4Wta5+utbgeGaELCSoCt8
# DULTGT4dpizY7jxhLExf2WBLWRNMhvdix+gV0Wkq6s9/adzZh3jAuD4WDCaTGR7I
# TcxQpWdrxJl5WkSOdLm5wVyTiys/ArY5EB/vQjbcYbI+GqAgpmmE1eFKxxMBCzIi
# oHkbAMx1FXksrfs19ThibG8JiHdMVgT8aHTVDrIm9/0fGIRmnBb6hSTSCu4ehuDe
# yAhHmt+BSjyXfS9SdoNgxw8AKVoUwL9BsdlJpSFZdkbU45wynSD29hA0sMSoVfaO
# Wq6/NVJLC0e2bUpOV0KNEQP6R0LJtw/Fs9qXAmKBdzUGwj0KK2dN/SWPBv02Rn8l
# Ujz8PratdfOHPgXe7SJUbPCdwZrFHEcb9e/idOumQ556mhhs0FsxZLYbWo/dePul
# V/T7ipHIConSy2NCOhU4kiZU9ZGPPk9HcOfpp1BUwEkMzqAOuPWtlMVWAK1OKOoZ
# lIbO9ekaQXe9izITpkOZr+QZ2JR7mxp4jqUfro+JZZeCrG3uzLYTO/TIiNJW/54w
# 5PZAxSJnpYJzuBW0CZel94i6z42aAW8z4hzVfnx7gj0QvhlICJ1KlZbQZlMs0LTa
# avIuMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0B
# AQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAG
# A1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAw
# HhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOTh
# pkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xP
# x2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ
# 3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOt
# gFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYt
# cI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXA
# hjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0S
# idb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSC
# D/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEB
# c8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh
# 8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8Fdsa
# N8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkr
# BgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q
# /y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBR
# BgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAP
# BgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjE
# MFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kv
# Y3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEF
# BQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEB
# CwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnX
# wnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOw
# Bb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jf
# ZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ
# 5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+
# ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgs
# sU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6
# OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p
# /cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6
# TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784
# cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA00wggI1
# AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAFNv5so4
# 8CMIF+WHPDkRcG5JbF4OoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwDQYJKoZIhvcNAQELBQACBQDuKmWnMCIYDzIwMjYwODE1MDQxMjIzWhgP
# MjAyNjA4MTYwNDEyMjNaMHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAO4qZacCAQAw
# BwIBAAICHtAwBwIBAAICEp8wCgIFAO4rtycCAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQsFAAOCAQEAJCbI1sG4zN9lC39qzmR1/RFU86mSc/o3GzFhEZEJdEZUjsHboc3X
# kaxWhaHXT2AgyvKsFzDicj5J0HPXOPgFuAnZF5VUST2XjuqYfsMJrikDXgm2TLNO
# sbp82oGoSjnVk9iYM1UJvzzLStrMWVFkB4/aKGDPnVjbLXjyHgx0djyTdwH1Hdv4
# kWvQ7Vg8wK/9t2SLDuh01C2xHdJi6NUi8OX1pK4u/LkF/4kgzPt0xbFzbadKk3s8
# cu2nUMBJrvoScHCNY1u84n/2x+kifCnYmWPGpSB6sfrgxkQUvhzg7GLSZQT7Cdsl
# IgD+Ei1mwYJrv2VAVvMDVpTzNAUtoJWgpzGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACJYDHN8bNqndJAAEAAAIlMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIM4fFqeDPijjdAQO8floF8kUiLewgFA9mzZzE57y2DBuMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVg3uiHo43fL3YKYCX+UXQJjCuNZZA/p0
# JTFqM9IcoRAwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAiWAxzfGzap3SQABAAACJTAiBCAVu97YuuR1G9NDPN4QK3icWquS13YSLcPc
# TuCRfhrsGTANBgkqhkiG9w0BAQsFAASCAgBsIkc2JeJIG7AtuISB+djsbA9wZrNG
# BWBtSxX74Zxv/ibyYYs5OPg2gHgc1xvP9M7J36fwxfDBe0suayQbJlLiYPvCC/5E
# 4PhmbqCRhPedaQixEd7ohCQHhhrLj8mUI12oiDQIkUts1yVz0Mv4Wep0ii3+nJRN
# szQDG0r+1kfhSZbg4hm9NsVF83sgzt8C25Z7YuS/CwfVrKiCpU3N7iV5xiE8+mR8
# 1VwypgWDUOx7VrE2j+nxGgsE/SnLSqaxyn6VHLHQkWauF1zwDzsUO44WWATwndvx
# A+1iyvulI4SqSKKZDZlCUf9D9liMCbnZhNrZsKrvkxhQ9T3EUXuePOLA3vzmyXnm
# yPitBhPv4Nd6j1p9H9x/FZsrlqTpQ81IhoVbX/6Dhm+/VRAYJB9YYzVpK0SOgS15
# 9aAnj/I/yx0EBHv07g/91kdV6vf6+ZwjDpqE7yzkQVLWwWS7/yGtlSC4F1qcF4GL
# vyCNkGx3QIv7pcgPCqGvIp5aSAVjAhAV+gxixlbHNKd2WMaeSydmQ2ptkF0s0FMG
# pGSiXID3XHCMkiVQC6/Y+4uQg/uShh6xABb6AyekAlyMSJw10Ki8EKtqhezsdvCR
# RZIH179+rDOomWsJuXZ3h9bjywXyVf2dcYmGFKAXyD7XT9ws2GshSPH4K93iOrUi
# PQFxiePZX1B0yQ==
# SIG # End signature block
