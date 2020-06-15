# PowerVCR

> This is in dev and experimental

PowerVCR is a PowerShell web request recorder and playback module.

Currently supported:

* `Invoke-VcrWebRequest`
* `Invoke-VcrRestMethod`

Planned:

* `Invoke-VcrCommand`

## Example

The following will create a new VCR in record mode. Calling `Invoke-VcrWebRequest` will record some of the details of the response to a JSON file:

```powershell
$result = (New-Vcr -Mode Record | Invoke-VcrWebRequest -Uri 'https://google.com')
```

Then, you can later re-use that recorded result in playback mode:

```powershell
$result = (New-Vcr -Mode Playback | Invoke-VcrWebRequest -Uri 'https://google.com')
```

Currently recorded are:

* StatusCode
* StatusDescription
* Content
* Headers

The file matching is done using a SHA256 hash of the request Method, URI, Body, and Header Keys.
