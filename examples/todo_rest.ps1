$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/PowerVCR.psm1" -Force -ErrorAction Stop


$tape = (New-Vcr -Mode Record | Invoke-VcrRestMethod -Uri 'https://jsonplaceholder.typicode.com/todos/1')
$tape | out-default


$tape = (New-Vcr -Mode Playback | Invoke-VcrRestMethod -Uri 'https://jsonplaceholder.typicode.com/todos/1')
$tape | out-default