# PowerVCR

> This is in dev and experimental

PowerVCR is a PowerShell web request/command recorder and playback module.

Currently supported:

* `Invoke-VcrWebRequest`
* `Invoke-VcrRestMethod`
* `Invoke-VcrCommand`

Under the hood PowerVCR calls the main functions. Most of the original parameters are supported for basic requests; more will be added over time.

PowerVCR is useful if you have tests that need to make external calls, but on the testing server these external endpoints aren't accesible - or another person's computer is offline.

You can run the initial, for example, Pester tests on your local and record the responses. You can then change to Playback and commit the responses. Your test server, or another person can then run the tests in Playback without worrying about not having access to the endpoint.

## Modes

There are 3 modes you can run PowerVCR in:

* `Record`: records the response of requests, overwriting any existing records.
* `Playback`: returns a saved response for the request. This will error is a response can't be found.
* `Cache`: if a saved response is found, it's returned. Otherwise, it will make the request and save it.

## Examples

### WebRequest

The following will create a new VCR in record mode. Calling `Invoke-VcrWebRequest` will record some of the details of the response to a JSON file:

```powershell
$result = (New-Vcr -Mode Record | Invoke-VcrWebRequest -Uri 'https://google.com')
```

Then, you can later re-use that recorded result in playback mode:

```powershell
$result = (New-Vcr -Mode Playback | Invoke-VcrWebRequest -Uri 'https://google.com')
```

Currently recorded and returned are:

* StatusCode
* StatusDescription
* Content
* Headers

The file matching is done using a SHA256 hash of the request Method, URI, Body, and Header Keys.

### RestMethod

The following will create a new VCR in record mode. Calling `Invoke-VcrRestMethod` will record some of the details of the response to a JSON file:

```powershell
$result = (New-Vcr -Mode Record | Invoke-VcrRestMethod -Uri 'https://jsonplaceholder.typicode.com/todos/1')
$result.Content
```

Then, you can later re-use that recorded result in playback mode:

```powershell
$result = (New-Vcr -Mode Playback | Invoke-VcrWebRequest -Uri 'https://jsonplaceholder.typicode.com/todos/1')
$result.Content
```

Currently recorded and returned are:

* StatusCode
* StatusDescription
* Content
* Headers

The file matching is done using a SHA256 hash of the request Method, URI, Body, and Header Keys.

### Command

The following will create a new VCR in record mode. Calling `Invoke-VcrCommand` will record some of the details of the response to a JSON file:

```powershell
$result = (New-Vcr -Mode Record | Invoke-VcrCommand -ScriptBlock { Get-ChildItem })
$result.Content.FullName
```

Then, you can later re-use that recorded result in playback mode:

```powershell
$result = (New-Vcr -Mode Playback | Invoke-VcrCommand -ScriptBlock { Get-ChildItem })
$result.Content.FullName
```

Currently recorded and returned are:

* ErrorCode
* StackTrace
* Content

The file matching is done using a SHA256 hash of the request ComputerName, and ScriptBlock.
