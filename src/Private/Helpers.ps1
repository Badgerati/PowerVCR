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

    # this assumes HttpRequestException
    $body = $_.ErrorDetails.Message

    if ($body -ieq 'No such host is known') {
        $code = 404
        $desc = 'Not Found'
        $headers = $null
    }
    else {
        $code = [int]$_.Exception.Response.StatusCode
        $desc = [string]$_.Exception.Response.ReasonPhrase
        $headers = ($_.Exception.Response.Headers.ToString() + $_.Exception.Response.Content.Headers.ToString())
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