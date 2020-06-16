function New-VcrSHA256Hash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA256]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Read-VcrWebExceptionDetails
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    $body = $_.ErrorDetails.Message

    if ($body -imatch '(No such host is known|The remote name could not be resolved)') {
        $code = 404
        $desc = 'Not Found'
        $headers = $null
    }
    else {
        switch ($ErrorRecord) {
            { $_.Exception -is [System.Net.WebException] } {
                $stream = $_.Exception.Response.GetResponseStream()
                $stream.Position = 0

                $body = [System.IO.StreamReader]::new($stream).ReadToEnd()
                $code = [int]$_.Exception.Response.StatusCode
                $desc = [string]$_.Exception.Response.StatusDescription
                $headers = $_.Exception.Response.Headers.ToString()
            }

            { $_.Exception -is [System.Net.Http.HttpRequestException] } {
                $code = [int]$_.Exception.Response.StatusCode
                $desc = [string]$_.Exception.Response.ReasonPhrase
                $headers = ($_.Exception.Response.Headers.ToString() + $_.Exception.Response.Content.Headers.ToString())
            }
        }
    }

    # if headers, parse them as hashtable
    $c_headers = $null
    if ($null -ne $headers) {
        $c_headers = [ordered]@{}

        ($headers -isplit [System.Environment]::NewLine) | ForEach-Object {
            $parts = ($_ -isplit ':')
            $key = $parts[0].Trim()
            $value = ($parts[1..($parts.Length - 1)] -join '').Trim()

            if (!$c_headers.ContainsKey($key)) {
                $c_headers.Add($key, @())
            }

            $c_headers[$key] += $value
        }
    }

    return [ordered]@{
        StatusCode = $code
        StatusDescription = $desc
        Content = $body
        Headers = $c_headers
    }
}

function ConvertFrom-VcrJson
{
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]
        $InputObject
    )

    # PS6+
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($InputObject | ConvertFrom-Json -AsHashtable)
    }

    # PS5
    return ($InputObject | ConvertFrom-Json)
}