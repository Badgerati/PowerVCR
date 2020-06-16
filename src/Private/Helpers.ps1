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

    $body = $ErrorRecord.Exception.Message

    if ($body -imatch '(No such host is known|The remote name could not be resolved)') {
        $code = 404
        $desc = 'Not Found'
        $headers = $null
    }
    elseif ($body -imatch '(The operation was canceled|The operation has timed out)') {
        $code = 500
        $desc = 'Timeout'
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

function Test-VcrIsWindowsPwsh
{
    return ($PSVersionTable.PSVersion.Major -le 5)
}

function ConvertFrom-VcrJson
{
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]
        $InputObject
    )

    # PS5
    if (Test-VcrIsWindowsPwsh) {
        return ($InputObject | ConvertFrom-Json | ConvertTo-VcrHashtable)
    }

    # PS6+
    return ($InputObject | ConvertFrom-Json -AsHashtable)
}

function ConvertTo-VcrHashtable
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [psobject[]]
        $Value
    )

    if (($null -eq $Value) -or ($Value.Length -eq 0)) {
        return @{}
    }

    return @(@($Value) | ForEach-Object {
        $obj = $_
        $output = @{}

        $obj | Get-Member -MemberType *Property | Foreach-Object {
            $output[$_.Name] = $obj.($_.Name)
        }

        $output
    })
}