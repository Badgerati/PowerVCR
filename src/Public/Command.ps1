function Invoke-VcrCommand
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Vcr,

        [Parameter()]
        [string]
        $ComputerName,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # make request hash
    $hash = New-VcrSHA256Hash -Value "$($ComputerName):$($ScriptBlock)"
    $filepath = (Join-Path $Vcr.Command.Path "$($hash).json")

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
            ScriptBlock = $ScriptBlock
            ErrorAction = 'Stop'
        }

        if (![string]::IsNullOrWhiteSpace($ComputerName)) {
            $params['ComputerName'] = $ComputerName
        }

        if (($null -ne $ArgumentList) -and ($ArgumentList.Length -gt 0)) {
            $params['ArgumentList'] = $ArgumentList
        }

        $result = Invoke-Command @params
    }
    catch {
        $success = $false
        $result = Read-VcrCommandExceptionDetails -ErrorRecord $_
    }

    # convert to the result to what we can save/jsonify
    if ($success) {
        $tape = [ordered]@{
            ErrorCode = 0
            StackTrace = [string]::Empty
            Content = $result
        }
    }
    else {
        $tape = [ordered]@{
            ErrorCode = [int]$result.ErrorCode
            StackTrace = [string]$result.StackTrace
            Content = [string]$result.Content
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

# function Set-VcrCommandConfig
# {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
#         [hashtable]
#         $Vcr,

#         [Parameter()]
#         [string[]]
#         $AllowedHeaders,

#         [switch]
#         $NoHeaders,

#         [switch]
#         $PassThru
#     )

#     $Vcr.Rest.NoHeaders = $NoHeaders
#     $Vcr.Rest.AllowedHeaders = $AllowedHeaders

#     if ($PassThru) {
#         return $Vcr
#     }
# }

function Add-VcrCommandFilter
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
        [ValidateSet('ComputerName', 'ScriptBlock')]
        [string]
        $Type,

        [switch]
        $PassThru
    )

    if ($null -eq $Vcr.Command.Filters[$Type]) {
        $Vcr.Command.Filters[$Type] = @()
    }

    $Vcr.Command.Filters[$Type] += @{
        Pattern = $Pattern
        Value = $Value
    }

    if ($PassThru) {
        return $Vcr
    }
}