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
# MIIncQYJKoZIhvcNAQcCoIInYjCCJ14CAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghn+MIIZ+gIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIIFUeJ0JHGftJd8pWZZMi2XQ9hnh9j+yXwiGGvR7GjdeMEIGCisG
# AQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAKz/YyrvOAWHdvTDE4KWG
# 7YXni6oF9PToXLTxHGdX0Rv+sAEnRf/3vSI5zu0jdR8cVWmjo0GP7ErS7E0Dl2Hw
# VTwfLckhvuvsKVj9fAiSc+DisWzfOKiKDucj7YlhiTz2Z0KmQJx1FVkJqquFJQtR
# ymnCwqdO7CiSsgTD+LLFlow74LhLGxddhq0BIuhVwn+iB/OcqwKDgOs7XwIQcDeC
# P16EPpaNjQkd0vJ8tc6LB2Q1aXfDYHzNyrn8pzuXV+1fXuW5py3z6o64m4gcqxOK
# xfTG4dNrymxfGcpLCIf6/3jTiOyZEw4hrBp85HGH0yEI4t1qi//Hr4KF7MlNa/ed
# eqGCF7AwghesBgorBgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kwgheF
# AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIB
# QQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAqo9DTJTT8fA3jxmYn
# gAQ0+UaZbIlWoqspLgtnoj56AgIGaeuJr17oGBMyMDI2MDUwMTA2MzExNy42NzVa
# MASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjoyRDFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIFEKAD
# AgECAhMzAAACEtEIBjzKGE+qAAEAAAISMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgxNVoXDTI2MTExMzE4
# NDgxNVowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTAr
# BgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjJEMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAr0zToDkpWQtsZekS0cV0quDdKSTGkovvBaZH0OAIEi0O3CcO
# 77JiX8c4Epq9uibHVZZ1W/LoufE172vkRXO+QYNtWWorECJ2AcZQ10bpAltkhZNi
# XlVJ8L3QzhKgrXrmMkm2J+/g81U23JPcO4wXHEftonT3wpd//936rjmwxMm7Nkbs
# ygbJf+4AVBMNr4aMPQhBd76od0KMB6WrvyEGOOU0893OFufS5EDey4n44WgaxJE0
# Vnv3/OOvuOw5Kp1KPqjjYJ+L9ywLuBMtcDfLpNQO/h1eFEoMrbiEM67TOfNlXfxb
# Dz4MlsYvLioxgd2Xzey1QxrV1+i+JyVDJMiSe9gKOuzpiQQFE19DUPgsidyjLTzX
# EhSVLBlRor0eCVf7gC6Rfk8NY3rO2sggOL79vU5FuDKTh/sIOtcUHeHC42jBGB+t
# fdKC1KOBR+UlN9aOzg8mpUNI2FgqQvirVP9ppbeMUfvp2wA9voyTiRWvDgzCxo8x
# lJ1nscYTHIQrmkF9j/Ca0IDmt8fvOn64nnlJOGUYZYHMC1l0xtgkYTE1ESUqqkaw
# Kk7iqbxdnLyycS+dR+zaxPudMDLrQFz8lgfy9obk0D8HC2dzhWpYNn5hdkoPEzgC
# qQUOp8v3Qj/sd4anyupe5KoCkjABOP3yhSQ4W9Z+DrJnhM/rbsXC7oTv26cCAwEA
# AaOCAUkwggFFMB0GA1UdDgQWBBRSBblSxb5cYKYOwvd/VfoXOfu33jAfBgNVHSME
# GDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsG
# AQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEAXnSAkmX79Rc7lxS1wOozXJ7V0ou5DntVcOJplIkD
# jvEN8BIQph4U+gSOLZuVReP/z9YdUiUkcPwL1PM245/kEX1EegpxNc8HDA6hKCHg
# 0ALNEcuxnGOlgKLokXfUer1D5hiW8PABM9R+neiteTgPaaRlJFvGTYvotc0uqGiE
# S5hMQhL8RNFhpS9RcIWHtnQGEnrdOUvCAhs4FeViawcmLTKv+1870c/MeTHi0QDd
# eR+7/Wg4qhkJ2k1iEHJdmYf8rIV0NRBZcdRTTdHee35SXP5neNCfAkjDIuZycRud
# 6jzPLCNLiNYzGXBswzJygj4EeSORT7wMvaFuKeRAXoXC3wwYvgIsI1zn3DGY625Y
# +yZSi8UNSNHuri36Zv9a+Q4vJwDpYK36S0TB2pf7xLiiH32nk7YK73Rg98W6fZ2I
# NuzYzZ7Ghgvfffkj4EUXg1E0EffY1pEqkbpDTP7h/DBqtzoPXsyw2MUh+7yvWcq2
# BGZSuca6CY6X4ioMuc5PWpsmvOOli7ARNA7Ab8kKdCc2gNDLacglsweZEc9/VQB6
# hls/b6Kk32nkwuHExKlaeoSVrKB5U9xlp1+c8J/7GJj4Rw7AiQ8tcp+WmfyD8KxX
# 2QlKbDi4SUjnglv4617R8+a/cDWJyaMt8279Wn7f2yMedN7kfGIQ5SZj66RdhdlZ
# Oq8wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEB
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
# RNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCCAkEC
# AQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjoyRDFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIa
# AxUA5VHBr4h00EN7jUdQ33SE+qbk/8CggYMwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO2emXgwIhgPMjAyNjA1MDEw
# MzE2MDhaGA8yMDI2MDUwMjAzMTYwOFowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA
# 7Z6ZeAIBADAKAgEAAgITIwIB/zAHAgEAAgISVzAKAgUA7Z/q+AIBADA2BgorBgEE
# AYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYag
# MA0GCSqGSIb3DQEBCwUAA4IBAQA8n97u0uNVEX8Tbwc8w1DJuXKeLuGSxwjXdpwU
# oNqWaRB36s4UZ+Fj3HDfEeBox/v3k8sM1RYxv/j7uERIhbVZkdyfKlLq73fj8aVr
# 32sXAKZO2A4MY7xajcbBgnJL8AhC7fFP5Jz7tfCpB3ARI2rzOQ7Vqry1cGK4Yg/G
# BJJlvY2fDypXwtcUfr6W9zM88TQ0I26xbHBpGU2iEeYiHtQSE0ZMcoTSeGpQwB0R
# S6dlZ04wu+z9TowcehufQzs1ue6C+B23Qtkw0Tszmlnu/ebd3ndn9CIyKUK+nuKk
# s84vKpTdWHxI8Hk16lu31GY9fkaspdZQE8CLfIYGnhWdWJL2MYIEDTCCBAkCAQEw
# gZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIS0QgGPMoYT6oA
# AQAAAhIwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0B
# CRABBDAvBgkqhkiG9w0BCQQxIgQgqRBTJ4SfEJ4TxsQQfeAYIYWLwwQR9G2vKpVU
# 1x+UsQgwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBz+X5GvO7WngknH4BZ
# eYU+BzBL1Jy5oJ8wVlTNIxfYgzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwAhMzAAACEtEIBjzKGE+qAAEAAAISMCIEIMBFefwqpbu/5Ro1BM5a
# RoWgkHzWbay1376Llx48F125MA0GCSqGSIb3DQEBCwUABIICAFB0QK60E4Gn5JVM
# CkNz2I6i12QkrxaQFnNXEKbh3LVgtZN8SoEUhKzfI23ZLTB1kVWO/2VTDPiXvetG
# eiVulHZw2lXBrSFfpb+fGa0swMiaJgsESoRiBhIV8+pn3KA4Ym2MkStT4IGGjLeV
# zjlAINWzz+tKZXKytLLvKFBG4NwnnwqkpYvLJ6Z/6ESuUOzEN9gPyD8565iKvmGD
# 3SYwgaLIlW0oiSFdZ95/5+cmHtTNmTVjUD4orjSfwndsW6ZBLxDOZzcrvsMD8dTf
# Z5wJG7LktAVwAQ6hilV7wY0K3/m6MrVN0p+xVEbQMhQ+DRRTbTyzvKulPax1AyJh
# lVSLb/m3sdGAoqKzpFuQuuKmQoARe9eUOvxO9cWV8U82mZuBWaH7EjTNRvQaxm2F
# ZBpdiRDiJ67eFSiDxmiyVx2VQjVC1XwZddSNkpOugT2Zh5btlNlxJ8j3IwzrBuaD
# fvQh5jce3L/8DyLVD1krndD0ZN8ZyCQmVJEwq20SGLTlEVo4vhOgMxgYVDmSUdCT
# 4F8b967vuiv0G2oWk5Kja3P3ETUxEQOXPjxxXt9WcZfGCwMi46dHgoQzpW/oQYQg
# auEkcD4EysMMKoP5rbtdpkkhTn9c9XJ/41ZVv+itVz2Q6c31lafPSrMN2707PBMu
# BgzwIWzIM0frOvlJf1dSvkI7yA68
# SIG # End signature block
