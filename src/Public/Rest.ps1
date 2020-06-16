function Invoke-VcrRestMethod
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Vcr,

        [Parameter()]
        [Microsoft.PowerShell.Commands.WebRequestMethod]
        $Method = 'GET',

        [Parameter(Mandatory=$true)]
        [uri]
        $Uri,

        [Parameter()]
        [System.Collections.IDictionary]
        $Headers,

        [Parameter()]
        [object]
        $Body,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [int]
        $TimeoutSec = 30
    )

    # make request hash
    $_headers = @()
    if (($null -ne $Headers) -and ($Headers.Count -gt 0)) {
        $_headers = ($Headers.Keys | Sort-Object).ToLowerInvariant()
    }

    $_method = "$($Method)".ToLowerInvariant()
    $hash = New-VcrSHA256Hash -Value "$($_method):$($Uri):$($Body):$($_headers -join ',')"
    $filepath = (Join-Path $Vcr.Rest.Path "$($hash).json")

    # playback/cache, see if we have a file
    if (@('playback', 'cache') -icontains $Vcr.Mode) {
        $tape = $null
        if (Test-Path $filepath) {
            $tape = (Get-Content $filepath -Raw -Force) | ConvertFrom-VcrJson
        }
    }

    # if playback and no tape, fail
    if (($null -eq $tape) -and ($Vcr.Mode -ieq 'playback')) {
        throw 'There is no tape available for the request to be played back'
    }

    # if playback/cache, return the tape
    if (($null -ne $tape) -and (@('playback', 'cache') -icontains $Vcr.Mode)) {
        return $tape
    }

    # if we get here, we're either recording (or cache-recording) - run the request and save it
    try {
        $success = $true
        $params = @{
            Uri = $Uri
            Method = $Method
            Body = $Body
            Headers = $Headers
            ContentType = $ContentType
            TimeoutSec = $TimeoutSec
            ErrorAction = 'Stop'
        }

        if (Test-VcrIsWindowsPwsh) {
            $params['UseBasicParsing'] = $true
        }
        else {
            $VcrResponseHeaders = $null
            $params['ResponseHeadersVariable'] = 'VcrResponseHeaders'
        }

        $result = Invoke-RestMethod @params
    }
    catch {
        $success = $false
        $result = Read-VcrWebExceptionDetails -ErrorRecord $_
    }

    # convert to the result to what we can save/jsonify
    if ($success) {
        $tape = [ordered]@{
            StatusCode = 200
            StatusDescription = 'OK'
            Content = $result
            Headers = [hashtable]$VcrResponseHeaders
        }
    }
    else {
        $tape = [ordered]@{
            StatusCode = [int]$result.StatusCode
            StatusDescription = [string]$result.StatusDescription
            Content = [string]$result.Content
            Headers = [hashtable]$result.Headers
        }
    }

    # save the converted tape
    $parentPath = Split-Path -Parent -Path $filepath
    if (!(Test-Path $parentPath)) {
        New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
    }

    $tape | ConvertTo-Json | Out-File -FilePath $filepath -Force -ErrorAction Stop
    if (!$?) {
        throw "Failed to save the request to: $($filepath)"
    }

    # return the tape
    return $tape
}

function Set-VcrRestConfig
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Vcr,

        [Parameter()]
        [string[]]
        $AllowedHeaders,

        [switch]
        $NoHeaders,

        [switch]
        $PassThru
    )

    $Vcr.Rest.NoHeaders = $NoHeaders
    $Vcr.Rest.AllowedHeaders = $AllowedHeaders

    if ($PassThru) {
        return $Vcr
    }
}

function Add-VcrRestFilter
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Vcr,

        [Parameter(Mandatory=$true)]
        [string]
        $Pattern,

        [Parameter(Mandatory=$true)]
        [string]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Method', 'Uri', 'Headers', 'Body', 'ContentType')]
        [string]
        $Type,

        [switch]
        $PassThru
    )

    if ($null -eq $Vcr.Rest.Filters[$Type]) {
        $Vcr.Rest.Filters[$Type] = @()
    }

    $Vcr.Rest.Filters[$Type] += @{
        Pattern = $Pattern
        Value = $Value
    }

    if ($PassThru) {
        return $Vcr
    }
}