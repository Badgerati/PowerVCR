function New-Vcr
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Record', 'Playback', 'Cache')]
        [string]
        $Mode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '.',

        [Parameter()]
        [int]
        $CasetteAge = 0
    )

    # set path
    $Path = Join-Path $Path 'casettes'

    # set age (0 = forever)
    if ($CasetteAge -lt 0) {
        $CasetteAge = 0
    }

    # base vcr
    return @{
        Mode = $Mode
        Path = $Path
        Age = $CasetteAge
        Web = @{
            Path = (Join-Path $Path 'web')
            NoHeaders = $false
            AllowedHeaders = @()
            Filters = @{}
        }
        Rest = @{
            Path = (Join-Path $Path 'rest')
            NoHeaders = $false
            AllowedHeaders = @()
            Filters = @{}
        }
        Command = @{
            Path = (Join-Path $Path 'command')
        }
    }
}
