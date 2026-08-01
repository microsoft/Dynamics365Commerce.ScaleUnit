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
# MIInQAYJKoZIhvcNAQcCoIInMTCCJy0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDX5hJmtLOvMpLs
# XkShtsJXkhwNGBeqRZeqk/6aiuQquaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KoZIhvcNAQkEMSIEIIFUeJ0JHGftJd8pWZZMi2XQ9hnh9j+yXwiGGvR7GjdeMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAwuNmqH3qndxbVR4x
# LpqRXnjFrLUAnalLRxDz/Xa4trm4sghCSSOpaIRfET8vzov/s6iTO/EQKH0JshJK
# ymxsxsuqTsHAOQ0ndOrHCbkjKvj79H4HVe6OdK/GKYgyKV2I3ruvSlathfmR4zFo
# 6I6KKk38DEtnKaciyzGV64n/A7i0OdqfGhTDo+Dhon+t/HQrKYcHt80HRmGhdprc
# d71UP54zuufzzoQ+fAsSOuuh2uMJidxEnXO/OxwTsclSPNNlgJTFqNxwLRYtmP7R
# bP7fX3lCnKt/qvgPdpkiSS1doefNvUjEEQQ+s8EwA7sCSLmUYGG7uZ9IFBF3IGBo
# 7qokl6GCF6wwgheoBgorBgEEAYI3AwMBMYIXmDCCF5QGCSqGSIb3DQEHAqCCF4Uw
# gheBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFE
# MIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAGSRh2t/LWRBHw
# JRTAx28rXFh45vidcKf7ObuWV9F2xAIGamNp0Pw8GBIyMDI2MDgwMTEwMDkzOS42
# OFowBIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQ
# oAMCAQICEzMAAAITsEM1Zs+vlegAAQAAAhMwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODE3WhcNMjYxMTEz
# MTg0ODE3WjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEt
# MCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzYwNS0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQD0mXrguhnEMg1IWDP70pLk7O/mbnjx49XNz1FdZ7hPj8ym
# V+Brh6rXZEZ2nlxW+eN17m/F+rZrH+Oe7u9Rbitk3iY5Sbm+H6RxixCVhDncXCAg
# HecSNxAeiasbeZl7+jOMVICvoluCUq0h4DJI/MBwXPIB6vmUs1QcES9AwzwE6MzJ
# qkK+HTGyDjEoVxUQlAsoR8IYF98xkj9qa60cVvcJRNntpWkbYocQVQ2VnW/Awq/F
# dM9EOdvA8bPLKoknOd+ws0dDi9e3a21LU94KgYjSE3U96rzIawhcz2ihzALToMY1
# Iz/gsDHa4q/CZSfo3AtzT62a+fLrDbytkt6OyRF+dVah8S/WZZjSMdScevBIYFLy
# BU/2BwGzo/mDQ6kk8x/F1SQddGRww89bSEg/w1tbxblK6nwe7CdIpuOnICUYFR0z
# 9XmtlvSxmaSfvXivpQsYr5wssA3pHcWFfo3SePrgXbstMrYFtLSkllpeOjR4M3PV
# BzF4gUtSAX5EGwtgOfwTxwKR7Erw2W3caL3Ml/nnDpR9Nn6TBMzEyoXGHv5N/Hv5
# oE5tn6fH3rUC2KoDLvNVXr2j8tZF0o9l29mf0RLIZtOc9+OQERG/bamtKUROVHDM
# /puYRU4pYtZXDG7CHttRZS5RvVyP3fO+21BgZBq3kT0Assk2aW8soKyQHutouwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFBOeEErH4WvKmFBYxGKkfj2wwUA6MB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQCCbFomsapDYPpQmFnpCXZJkU5o24ZtbcvMH4RL
# 6XYEHUwm0FFIV2L+FVjfc2nGwlCFDlMtWnQNdg6Qig9BzXusf4hWF6Y7yMK35Toj
# VMjDpxHtz60Sj8mOnoSoRTVzj+atoyOAeFD6toL85QCb3wDWvhsg8e2wGYtE4aZ4
# TlcsgVoEhlYe+HYI5chMo5tdV3nAa0nV1ll3BocAJcXnTqO1r66hR3LMB642VM8t
# OtnyfKHEbCT1WHp6INDsJAxZJJrwMlL09ReN6iL29N1Ltkxeq762/pDPfG2gEXn5
# gUri4T6aIaz3QXGbRUraVauYWGORGXnPKgc53Abuyk1iQOiYI81Yi51RCZBgqm38
# eyyl9xv7GmdYgNB0zOATymPW+nAuBYScfsu1Ph1kJ6gOj08rjRHEEPyQonvr2eCQ
# TB/AIPYRf8xCTv14i86GmcfXYa5UHK9opmTldm+q08403Cvyr+oDfzvsi5bBaCdp
# 5f6munDR1n9Au1sYZWuA/5NFCO37Z1xkDk/dfgvAA2GI+zLQ6XhcJ2Ps7EEsW87O
# wI8M9pWeSn518MUb404GKvtqpMnrzrbanKaDVX7qBz/VG/EL/CC9jIbTfd5wmq/Q
# 6fRlE1iv6L86TCADcc/VosPRoesSnDqW3TbreJGQK+tx1w5bzDeMLxMm5oZbILZL
# 2MSPODCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4D
# AhoDFQCYETxIKPGCNpybLz9UR2Ts3GlHpqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7hfK2DAiGA8yMDI2MDgw
# MTAxMzEwNFoYDzIwMjYwODAyMDEzMTA0WjB0MDoGCisGAQQBhFkKBAExLDAqMAoC
# BQDuF8rYAgEAMAcCAQACAgIWMAcCAQACAhKkMAoCBQDuGRxYAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBAAsdhDQs9shakvN3LP87WqSRkBh0E/Sm3v6s5BoY
# vse7hENioqFF+KJcXSQ/mcF+CNpMW3fg0KMvG/T4YBc9RnElt1vMdVXYWC8UdskH
# E7hJohi/gpzjvoJ5qpr6JNxA3e7Jnr6HsNoY3vSTLE//GddpQ0eb0Yiry0oCXIsS
# jqTlqA7FQ/upM67/qBReWMBdU30XTdXdc90Ddcpq5KCTGav0kkdQIfHH2h409Nz7
# aVMFRs4yLFcjl2dKrbcbPp9l36/GeLoCsZ+o535p6Yx0FRaDPZMY0VKCcnkCEkbH
# 3dEmJmRbMqUBo0h1e8ywJV6f2jbFVGi100PN+dBZw+x1/Z0xggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhOwQzVmz6+V6AAB
# AAACEzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCDFaA9qrEJFx3EEXQ+FYT3elH7r2Ol5zeJSctAC
# m2KvlTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIMzhCW0UhTPwngOMDM/i
# dWh1m9DFgaV5Qh+nzo5rnFhoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAITsEM1Zs+vlegAAQAAAhMwIgQgHG5rmLP4nfcWGZKgRa8u
# vlRKa/o5Xp/qcQ1J+O9T89swDQYJKoZIhvcNAQELBQAEggIAxIdHNvgDIhK+qAxb
# pqyvMqv8WkTg2PduafELORYe1OKnfPwwv7W3Vp8Z3kYPe1Q32n/Gp2VH2tIapqAr
# KliaXdqgS4h95XRz0CpFzcVT0nsaHqLd93/Dmr1zyQLWMUV0a5gwyzaXzyfFZkk8
# UHC6xsXno2tHicU+WAmloIoOLT3mxb9zOAp3TSwqZcY7nnQtzsYFVKDcHY34neNG
# u9wRceCzc39VJZ1qAs0K1yh5QzohzRSNctOSfI9piGMk2gUGAnQFMBscG9g1yfri
# PvEs28FEIIDgzFFfSd2kLcqwZPIfWSocJY2xUE3K9iC0ejGdH6dWH7CxOPBOq6dn
# eAxOHJTyslSUmXYNy0x7M+Cpg8QNgrSnPV5q8oDJWfeunF7EubiT3qtKm12rYTI7
# /+1lpGWXapad++dA91bmDWqOk8cpiInljLtS+3rEXUthwk4vApxjqvZUdrlZV7eV
# 6kxhtDvzNTI3KlfDqoJgxCh8Q4KR4nVFk0CAAvUENGJN2XChJ7lUXqbaxnZOU3q7
# y+68/1bAPkB48ILqk0EZix4QPz8BtskYK5/OwMwTMWrWF5QV6/7FFf2X7b7kWctw
# WqJb0WciVHc8HpT0btZUaCuE4TDZg6gS7iLhw0iOLyIcRWc29k5Z7pDqz1Tf7NqA
# MRgaqtwIGxvFR2R8SuJbSUOtDAA=
# SIG # End signature block
