function Invoke-VcrWebRequest
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
        $ContentType
    )

    # make request hash
    $_headers = @()
    if (($null -ne $Headers) -and ($Headers.Count -gt 0)) {
        $_headers = ($Headers.Keys | Sort-Object).ToLowerInvariant()
    }

    $_method = "$($Method)".ToLowerInvariant()
    $hash = New-VcrSHA256Hash -Value "$($_method):$($Uri):$($Body):$($_headers -join ',')"
    $filepath = (Join-Path $Vcr.Web.Path "$($hash).json")

    # playback/cache, see if we have a file
    if (@('playback', 'cache') -icontains $Vcr.Mode) {
        $tape = $null
        if (Test-Path $filepath) {
            $tape = (Get-Content $filepath -Raw -Force) | ConvertFrom-Json -AsHashtable
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
        $result = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -Body $Body -ContentType $ContentType -ErrorAction Stop
    }
    catch {
        $result = Read-VcrWebExceptionDetails -ErrorRecord $_
    }

    # convert to the result to what we can save/jsonify
    $tape = [ordered]@{
        StatusCode = [int]$result.StatusCode
        StatusDescription = [string]$result.StatusDescription
        Content = [string]$result.Content
        Headers = [hashtable]$result.Headers
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

function Set-VcrWebConfig
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

    $Vcr.Web.NoHeaders = $NoHeaders
    $Vcr.Web.AllowedHeaders = $AllowedHeaders

    if ($PassThru) {
        return $Vcr
    }
}

function Add-VcrWebFilter
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

    if ($null -eq $Vcr.Web.Filters[$Type]) {
        $Vcr.Web.Filters[$Type] = @()
    }

    $Vcr.Web.Filters[$Type] += @{
        Pattern = $Pattern
        Value = $Value
    }

    if ($PassThru) {
        return $Vcr
    }
}