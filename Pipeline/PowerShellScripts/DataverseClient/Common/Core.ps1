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
# MIInJwYJKoZIhvcNAQcCoIInGDCCJxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnDMIIZvwIBATBuMFcxCzAJBgNVBAYTAlVT
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
# 7qokl6GCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2ww
# ghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8
# MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAGSRh2t/LWRBHw
# JRTAx28rXFh45vidcKf7ObuWV9F2xAIGaoVYFWhEGBIyMDI2MDgyMTEwMTEwNC4x
# MlowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
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
# AQELBQACBQDuMnkrMCIYDzIwMjYwODIxMDcxMzQ3WhgPMjAyNjA4MjIwNzEzNDda
# MHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAO4yeSsCAQAwBwIBAAICCwwwBwIBAAIC
# EwEwCgIFAO4zyqsCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAYtTy7/Ic
# 4QvTjo3PK1yMZVyGpUDfH818v1XBmQOZ9OqDiYath7PdBZk16mYazHlf8iD3euD+
# Kk1eYO8eoKziHE0IjPcFMb0YR5r1EgygPs2NQUBmg1LXy7KFjgDVBocEUYebgsKK
# 3dyWbfiSeVP9n43jHitF0YHg6sAOh7WtWLxX7BUOYQBOa8lmL38UBqPvVWb25W57
# FH8R2NpCghuAiyyDlQsoFGgOuLQBecWX9txFq9tuckFqn6OgZ0Ex39MXiEn5+ApS
# OO3EPJINN2JeY8SZcMC6ZjVuOxR23moNFf6huIvQOrSO+ts4VBCr7MnSapeWF89X
# nDlgYjucrlhjPDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACJjW0PmdDk/YfAAEAAAImMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIP7vx9sG
# 5IxKyKdjIPuJ2ukDvGSSFRHItwDP/Cdug+DaMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgzDJcYWdM2xlEGuzoY38FtXSiRo0/dUFiosWNSwWduCowgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiY1tD5nQ5P2HwAB
# AAACJjAiBCBSl6+WkkyGNYLSkg/TwfejhhxylW4JlrJe+Ztx1cjvwjANBgkqhkiG
# 9w0BAQsFAASCAgC52UcYWZJPwDDc/Lg2YGRpLlnTROyBXlcqIUbqi9rbRAxQWUFv
# mSNHUTXdIbVRUL0sHw6L6tM7NhrMzS0/A57QHZKH5l8KrzqfaQEnbHlbPRT8YcVe
# uflo+u9HIuzIfPnVZQzwxL9aSWzN8FmZEyleqAslyZKmdIYNeagnYMn7g2KMhNQc
# hJO6u9ZSNU+8f/7Ujxq833EARMPZHji+mBRpmE/J0K4MyyQxPB3ovsdJeXUqK8mM
# xD0vs/R+I9WBrPip+n663CLCFd3GMqbakTLmgNgAzQHapdD6wvELlmXcgQgnH7r5
# yMsGRda1A0R9Phqnkkknzz1TtNYLdtoVrunb36/+tdM8TW0HEUY/20mkKmwF+zUQ
# SKVPphuGhl5ZKu3qZnfhQUobw/f4v0Epj8GoHctTz1bxXPwJZbL0QlfRhSppdio4
# ohN6ZRAMjTw4zY1mdDkABX8xjMNcTrTlhNjjnVQeXvx8MxbA4NyaaPGa7CIcYrm7
# wH2hWikHPa4IJMpp+5J/JS9STZUCDt/pfQ1jzYr8vAb6bDDZfmOqKABJM+2XBbfM
# nVfXPZk9xjhEGLZB6SvetckqerQDcD+brRyeEXXjZA63ixDyGrCHxElsH6EKa1KV
# X0ruCQfNCa2IsNAl4AwooyB3OjmBJ+UGsbZUIk9BbNsVafEeGjQhBxCmmw==
# SIG # End signature block
