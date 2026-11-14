# Well-known Microsoft first-party public client ID for Dataverse interactive sign-in.
# Works with any commercial-cloud Dataverse environment (prod and non-prod).
# Pre-consented for Dataverse user_impersonation; supports http://localhost redirect.
# See: https://learn.microsoft.com/power-apps/developer/data-platform/authenticate-oauth
$script:DataversePublicClientId = '51f81489-12ee-4a9e-aaae-a2591f45987d'

function Connect {
    param (
        [Parameter(Mandatory)]
        [String]
        $environmentUrl,

        [Parameter(Mandatory)]
        [String]
        $tenantId,

        [Parameter(Mandatory)]
        [String]
        $clientId,

        [Parameter()]
        [String]
        $clientSecret,

        [Parameter()]
        [String]
        $certificateThumbprint
    )

    if (-not $certificateThumbprint -and -not $clientSecret) {
        throw "Either 'certificateThumbprint' or 'clientSecret' must be provided."
    }

    try {
        # Ensure environmentUrl ends with /
        if (-not $environmentUrl.EndsWith('/')) {
            $environmentUrl += '/'
        }

        $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        Write-Host "Requesting token from $tokenEndpoint"

        # Build token request body — prefer certificate over client secret
        if ($certificateThumbprint) {
            $cert = 'CurrentUser', 'LocalMachine' |
                ForEach-Object { Get-Item "Cert:\$_\My\$certificateThumbprint" -ErrorAction SilentlyContinue } |
                Select-Object -First 1

            if (-not $cert) {
                throw "Certificate with thumbprint '$certificateThumbprint' not found in CurrentUser or LocalMachine stores."
            }

            $now = Get-Date
            Write-Host "Using certificate: $($cert.Subject) ($($cert.Thumbprint), expires $($cert.NotAfter.ToString('yyyy-MM-dd')))"

            if ($cert.NotAfter -lt $now) {
                throw "Certificate '$($cert.Thumbprint)' expired on $($cert.NotAfter.ToString('yyyy-MM-dd'))."
            }
            elseif ($cert.NotAfter -lt $now.AddDays(30)) {
                Write-Warning "Certificate '$($cert.Thumbprint)' expires on $($cert.NotAfter.ToString('yyyy-MM-dd')), which is within 30 days."
            }

            $body = @{
                client_id             = $clientId
                client_assertion      = New-ClientAssertion -cert $cert -clientId $clientId -tokenEndpoint $tokenEndpoint
                client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                scope                 = "${environmentUrl}.default"
                grant_type            = 'client_credentials'
            }
        }
        else {
            $body = @{
                client_id     = $clientId
                client_secret = $clientSecret
                scope         = "${environmentUrl}.default"
                grant_type    = 'client_credentials'
            }
        }

        $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint `
            -Method Post `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop

        # Define common set of headers
        $global:baseHeaders = @{
            'Authorization'    = "Bearer $($tokenResponse.access_token)"
            'Accept'           = 'application/json'
            'OData-MaxVersion' = '4.0'
            'OData-Version'    = '4.0'
            'Content-Type'     = 'application/json; charset=utf-8'
        }

        # Set baseURI
        $global:baseURI = "${environmentUrl}api/data/v9.2/"

        Write-Host "Successfully connected to $environmentUrl" -ForegroundColor Green
        Write-Verbose "Base URI set to: $global:baseURI"

        # Return connection info (without sensitive data)
        return @{
            Connected    = $true
            BaseURI      = $global:baseURI
            TokenExpires = (Get-Date).AddSeconds($tokenResponse.expires_in)
        }
    }
    catch {
        Write-Error "Failed to connect to Dataverse: $($_.Exception.Message)"
        throw
    }
}

function New-ClientAssertion {
    param (
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $cert,

        [Parameter(Mandatory)]
        [String]
        $clientId,

        [Parameter(Mandatory)]
        [String]
        $tokenEndpoint
    )

    $x5t = [Convert]::ToBase64String($cert.GetCertHash()).TrimEnd('=').Replace('+', '-').Replace('/', '_')

    $now = [DateTimeOffset]::UtcNow
    $header  = @{ alg = 'RS256'; typ = 'JWT'; x5t = $x5t } | ConvertTo-Json -Compress
    $payload = @{ aud = $tokenEndpoint; iss = $clientId; sub = $clientId; jti = [Guid]::NewGuid().ToString(); nbf = $now.ToUnixTimeSeconds(); exp = $now.AddMinutes(10).ToUnixTimeSeconds() } | ConvertTo-Json -Compress

    $toBase64Url = { param($bytes) [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    $unsigned = "$(& $toBase64Url ([Text.Encoding]::UTF8.GetBytes($header))).$(& $toBase64Url ([Text.Encoding]::UTF8.GetBytes($payload)))"

    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
    $sig = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($unsigned), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)

    return "$unsigned.$(& $toBase64Url $sig)"
}

function Connect-Interactive {
    <#
    .SYNOPSIS
        Connects to Dataverse via interactive user sign-in (OAuth 2.0 Authorization Code + PKCE).

    .DESCRIPTION
        Opens the default browser to sign the user in to Microsoft Entra ID, receives the
        authorization code on a temporary http://localhost loopback listener, and exchanges
        it for an access token scoped to the target Dataverse environment. On success, sets
        the same $global:baseHeaders and $global:baseURI used by the rest of the client.
        Intended for local/developer use only — the pipeline continues to use client secret
        or certificate.

    .PARAMETER environmentUrl
        The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com/).

    .PARAMETER tenantId
        Microsoft Entra tenant ID.

    .PARAMETER clientId
        Optional public client ID. Defaults to the Microsoft well-known public client with
        Dataverse pre-consent that allows the http://localhost loopback redirect.
    #>
    param (
        [Parameter(Mandatory)]
        [String]
        $environmentUrl,

        [Parameter(Mandatory)]
        [String]
        $tenantId,

        [Parameter()]
        [String]
        $clientId = $script:DataversePublicClientId
    )

    if (-not $environmentUrl.EndsWith('/')) { $environmentUrl += '/' }

    $authority = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0"
    $scope     = "${environmentUrl}user_impersonation"

    # Generate PKCE code verifier, challenge (S256), and CSRF state.
    $b64url = { param([byte[]] $bytes) [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = New-Object byte[] 32; $rng.GetBytes($bytes); $codeVerifier  = & $b64url $bytes
        $bytes = New-Object byte[] 16; $rng.GetBytes($bytes); $state         = & $b64url $bytes
        $codeChallenge = & $b64url $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($codeVerifier))
    }
    finally { $rng.Dispose(); $sha.Dispose() }

    # Reserve a free loopback port atomically, then hand it to HttpListener.
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $probe.Start()
    try { $port = ([System.Net.IPEndPoint] $probe.LocalEndpoint).Port }
    finally { $probe.Stop() }

    $redirectUri = "http://localhost:$port/"
    $listener    = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($redirectUri)
    $listener.Start()

    try {
        $authorizeParams = [ordered] @{
            client_id             = $clientId
            response_type         = 'code'
            redirect_uri          = $redirectUri
            response_mode         = 'query'
            scope                 = $scope
            state                 = $state
            code_challenge        = $codeChallenge
            code_challenge_method = 'S256'
            prompt                = 'select_account'
        }
        $query        = ($authorizeParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))" }) -join '&'
        $authorizeUrl = "$authority/authorize?$query"

        Write-Host "Opening browser for interactive sign-in..."
        try {
            Start-Process $authorizeUrl -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Could not launch browser automatically. Please open this URL manually:`n$authorizeUrl"
        }

        # Wait for the auth redirect, ignoring unrelated requests (e.g. favicon).
        # Polls in 500ms intervals so Ctrl+C can interrupt between iterations.
        $deadline = (Get-Date).AddMinutes(2)
        $callback = $null
        while ($true) {
            $contextTask = $listener.GetContextAsync()
            while (-not $contextTask.Wait(500)) {
                if ((Get-Date) -ge $deadline) {
                    throw "Interactive sign-in timed out after 2 minutes. Please try again."
                }
            }
            $context = $contextTask.Result

            # Parse query string.
            $params = @{}
            foreach ($pair in $context.Request.Url.Query.TrimStart('?').Split('&')) {
                if (-not $pair) { continue }
                $kv = $pair.Split('=', 2)
                $params[$kv[0]] = if ($kv.Length -eq 2) { [System.Uri]::UnescapeDataString($kv[1]) } else { '' }
            }

            if ($params['code'] -or $params['error']) {
                # Auth redirect received — respond to the browser and break.
                $callback = $params
                if ($callback['error']) {
                    $safeError = [System.Net.WebUtility]::HtmlEncode($callback['error'])
                    $safeDesc  = [System.Net.WebUtility]::HtmlEncode($callback['error_description'])
                    $htmlBody  = "<h2>Sign-in failed</h2><p>$safeError`: $safeDesc</p>"
                }
                else {
                    $htmlBody = '<h2>Sign-in complete</h2><p>You can close this tab and return to the terminal.</p>'
                }
                try {
                    $responseBytes = [Text.Encoding]::UTF8.GetBytes(@"
<!doctype html><html><head><meta charset="utf-8"><title>Dataverse Sign-in</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif;padding:2rem">$htmlBody</body></html>
"@)
                    $context.Response.ContentType     = 'text/html; charset=utf-8'
                    $context.Response.ContentLength64 = $responseBytes.Length
                    $context.Response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
                    $context.Response.OutputStream.Close()
                }
                catch {
                    # Browser may have closed the tab — safe to ignore since we already have the auth code.
                    try { $context.Response.Close() } catch { }
                }
                break
            }

            # Not the auth redirect (e.g. favicon) — dismiss and keep listening.
            $context.Response.StatusCode = 204
            $context.Response.Close()
        }

        # Validate the callback.
        if ($callback['error']) {
            throw "Sign-in failed: $($callback['error']) - $($callback['error_description'])"
        }
        if ($callback['state'] -ne $state) {
            throw "State mismatch in sign-in response (possible CSRF). Expected '$state', got '$($callback['state'])'."
        }
        if (-not $callback['code']) {
            throw "No authorization code returned from sign-in."
        }

        $authCode = $callback['code']
    }
    finally {
        if ($listener.IsListening) { $listener.Stop() }
        $listener.Close()
    }

    # Exchange the authorization code for an access token.
    try {
        Write-Host "Exchanging authorization code for access token..."
        $tokenResponse = Invoke-RestMethod -Uri "$authority/token" `
            -Method Post `
            -Body @{
                client_id     = $clientId
                grant_type    = 'authorization_code'
                code          = $authCode
                redirect_uri  = $redirectUri
                code_verifier = $codeVerifier
                scope         = $scope
            } `
            -ContentType 'application/x-www-form-urlencoded' `
            -ErrorAction Stop

        $global:baseHeaders = @{
            'Authorization'    = "Bearer $($tokenResponse.access_token)"
            'Accept'           = 'application/json'
            'OData-MaxVersion' = '4.0'
            'OData-Version'    = '4.0'
            'Content-Type'     = 'application/json; charset=utf-8'
        }
        $global:baseURI = "${environmentUrl}api/data/v9.2/"

        Write-Host "Successfully connected to $environmentUrl" -ForegroundColor Green
        Write-Verbose "Base URI set to: $global:baseURI"

        return @{
            Connected    = $true
            BaseURI      = $global:baseURI
            TokenExpires = (Get-Date).AddSeconds($tokenResponse.expires_in)
        }
    }
    catch {
        Write-Error "Failed to connect to Dataverse interactively: $($_.Exception.Message)"
        throw
    }
}

# SIG # Begin signature block
# MIInNgYJKoZIhvcNAQcCoIInJzCCJyMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDX5hJmtLOvMpLs
# XkShtsJXkhwNGBeqRZeqk/6aiuQquaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIIFUeJ0JHGftJd8pWZZMi2XQ9hnh
# 9j+yXwiGGvR7GjdeMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAlkbGDTzaks0Ig/qLhmUayhTVELZ1JemcaRbaVCjUZkhyQHNYG2AGmGtVl6Oh
# ITSilh88s4RwH3PxK1OROJuL9u/+8DfAh/FFF2xX6Qw0xwzSyWQDf+acmGD5ZmP9
# 8l410iDDAUV0gy14yR6THrtAo2pgiowTKb2dvZkE8xFQg2u/Ni3sQ32T7cTJWm/M
# kbq/R9BdPVojrI7ci6vjfzLqBP+/lRF3V7FVhUuApPa2S2Ber2aa/J8s3bbCczMW
# KbU9bYiDQZ0ObvIUmUlkUTOMdVKldyMuRdhY9MdNO/C2HUdFpSMv3NxmAEaIBf5H
# WYlzQ71rsLv/KhZfZtzrPVKCoaGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sG
# CSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG
# 9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCCMuz295tKhCTKuorZ+5G//3sfmezNIKkikftAEasnpWgIGavNtec4jGBIy
# MDI2MTExNDExMTAzOC4xMVowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5MjAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeow
# ggcgMIIFCKADAgECAhMzAAACI0/ZYCRTz/4rAAEAAAIjMA0GCSqGSIb3DQEBCwUA
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5Mzk1N1oX
# DTI3MDUxNzE5Mzk1N1owgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAl
# BgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5MjAwLTA1RTAtRDk0NzElMCMGA1UEAxMc
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAIrpDaeTlZR0rNIJJp+n5SNQBGxbEcpLresmEUL/NJpsW6ZM
# G5onRA2uap6+5vkNvt9KPmq3DAqeMg73b4dcXrvX3Z+6MvsMWi3lYSP8C0Rn9evM
# UeKYqU3WHqARDA/kjrvCLNo9blnNIE2losGDmge8BI85m3B01Shn4NAoXeEmXUpm
# 6giVUr6qLtwuOBqTqzmg5lxEIysqe4LdqhVrrBENti8pS6PuuQXH0o7Q+wcn+T4u
# dkyCBGF6HgBV1rDKH6g7Mo+OVAZQ19J5ZSDKbZT0Itry23SZBfgPEPPr6tqbnSCP
# WgB/JDpNDuv3o8AMU4oGBpTv5ykedpkbz11N6BDrJ0FEYjJw7DV1FfZ4oNFHPOIr
# dyfRZoib/s54azJAqMjMRC5RMO/QmP/3NDu2u4s46kkP3wElU4ruN7zhLPaFvce9
# RJPuPWPY3yl4PqiWSkUdH/VnwnPgX6aStQXsyY8CKtgdHO6dsiDcesMw3AVg3vIG
# QMDj9Uyj0JjTL2gZSirbKNsLBOJvP1ViX3ecHdBCJMJP2dbcz5M5YH48ytmkTGrU
# FIeYo/Mip6EqqtQOgzfc8r50QrClgsRPq5erge5BExdZP/+w+5tSdABppQx9CEBl
# LLbce3HC03d4r35PjAJq/bBAW3nt5Q7BRbn8MLMwX225rkd7WE2+BwBdqIbXAgMB
# AAGjggFJMIIBRTAdBgNVHQ4EFgQU1sCHz2/b2c9j1vBBvVBgLPFWB5cwHwYDVR0j
# BBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggr
# BgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# DQYJKoZIhvcNAQELBQADggIBAIdDB7vPm2ng1nAB/VwH7hz0niy/Dc/paoYEzG2r
# OdLoN3NTNK1ccJo9mEzjWDWIoc2eZycuPAu6M4Ro2OFKdQOIBmpCNbllqk4HGBzs
# SCCGH2T6vvypYB7esnhCiEFuFIZ1m0qK9NFp5GqaeHLz5OGsqHMJ4TBpqtcmKZnB
# Kl1BBQNuF5Yd7IDEBKq6W13ko7Sb9QW87Te196moZcDi0KD9YYQLAqo6MnOlEB88
# gHrLUfJWuT6+YvmukRtPDAs61ftbEUYbz5xguT0eNoOTGtoD8diUpBHHWx3Nr7D+
# C6UvCA6cHJEkoXauvwzsU0iXCiLrLAWlo1zwDsd7BoaODD+19wTbrQjVd6QaW4A0
# j0ec405haUjsEoFBtYTa16jq+xDVWDwHytNlJ49V2ZcvU8+qqzcpV0UozmRihw8I
# Mz7pUvfYhX3qwRJ/ZPsOPFqekKDYPZRiPhnWLtzLxTUssMaDnkpazhp/ZFEGMfYy
# 6UeACZbmhsrGJkINCNFqugnZcSVdSGKAT0HO+EIVtP8cNja+lWmXkedKlwJLGYvm
# LmUhP/FsBAwjsu6Hvleub4iyV8VY4Y4YyUKn7bioQkSCVcQ/vHCyiU10E2d1eKGH
# Ih59UaUjUNHvEYQuImuTyJ9VZij1cRsRe/+Vu+noXZHZSyfB5ZyS+rTLUdacscOo
# fp0+MIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0B
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
# VQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVADhFYWz6
# ROJmehmICPUG1iPzMI1qoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwDQYJKoZIhvcNAQELBQACBQDuooiDMCIYDzIwMjYxMTE0MDcxMzA3WhgP
# MjAyNjExMTUwNzEzMDdaMHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAO6iiIMCAQAw
# BwIBAAICN78wBwIBAAICEmgwCgIFAO6j2gMCAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQsFAAOCAQEASgkQ1Jym+Jl5qGa3rjA2ti7k/cpmN5VNYk/hDGBR4vIEntwsYywz
# bHo0YbyEcmyOhU9EWuxeRrZbaDxB4+p/oKuXr6TTEBSqdgx2ud5yk6gv/RO4UcA/
# tGYfwtjTINlZYWrKS5xO+fKVX/uCmJkTfMI6ZaF1VRblgzW6P8Cmgwz2oGPc9Fsd
# 6tRKHtUCvHqHd4ewpjvieGAsbSpU63zo2C1xCAvWyN8sPJNA42oGYTxyTD1JDDSh
# 6L7exMn4ssQ20gyiSJ/rchU9I7J/CoVliUzKpoTx9a1XP6tRwDoDqCqdxOl9bmy6
# KcLPRwnOpk0C/4AKjad7un3bGP90dc3hzTGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACI0/ZYCRTz/4rAAEAAAIjMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIAQPla1hHFouxzmacnbBtMBU7IcgPg22mjCJoc8n9X9kMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQglvAzLBFu9waLKeOfCMCpxoPjvJi95spl
# EC+0QBHm7rMwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAiNP2WAkU8/+KwABAAACIzAiBCDYQ/Gm5EKwQemwp8lrnl6C8NCQa03sXV0T
# a7MH7MABmTANBgkqhkiG9w0BAQsFAASCAgBR+VTN7f3zAEh5PaTFMY/eV3WnGrZ3
# /daJfnDPN4GpwQUlHoIKgCruvvkCx2VNc+neeMCsrcc13s+AS4vnQc7hjbCTbtsY
# xur7a4m+Gz6GM8UaK3GEdQh4cJqOK+qqdqnjX3fdL/HXkQoIBC9W6bPtJPAjPd5H
# JQY4u1cX9kn9YY3c5rhpCFiv1BOGeD+8urW9OAONUD9ot0jXkslK8LjCruMAwhi+
# H8GW0OIb2M2RNzVKpw/l9fEG0x/TQYnN8D3aRE0xhmV/y+PdOkBoecyBBCMHbTOX
# 6K5fW6x/9xA9pjOmng2QPgu6EoPy5jDVrCbzCl2TQ2Kcz3EWp7T5qqdWYOcsKvko
# /2aIN2bHQw7IwNFx1zW1ffVSNJOVIO7n9vuiTF9O7yf/PrtFKgV4DJJuXxmjacKd
# PTO2amJP5qaLJXNeS4h+7C5p5r6py/g7wmZ3QDefznRVUtMSCzPXl1Px+3RMbAdd
# B7/wIJCYFRw3lifFX8OJZXFKLKaEf9F6Rp275yGNOQP1shAF+sn/DEFW9A4qmR3L
# 9iyxfYoWpf4SEqGIqy3cP0cwYJrM1D8C25GPYFon/tEYkUqUtIk7v+mJAnZ2PJxS
# /Tn3AHMjvempOzFmfzA7tLSLzcZijwQLr4sAPhHl5ZnNKuQg2Zms7kul/geKS6bz
# NQBMtbFG6iDKMA==
# SIG # End signature block
