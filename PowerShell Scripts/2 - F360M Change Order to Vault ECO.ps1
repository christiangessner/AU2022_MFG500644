if (-not $IAmRunningInCallbackAgent) {
    $Payload = @'
{
  "descriptor": "CO-000034 - Hobbyist CNC Parts Kit - Wheels",
  "number": "CO-000034",
  "title": "Hobbyist CNC Parts Kit - Wheels",
  "description": "&lt;p&gt;Wheels need to be replaced by more solid and more accurate linear rails&lt;/p&gt;",
  "owner": "christian.gessner@coolorange.com",
  "workspace": 84,
  "dmsID": 14263
}
'@
}

try {
    $obj = ConvertFrom-Json -InputObject $Payload
    $number = $obj.number
    $title = $obj.title
    $description = $obj.description 
    if (-not $number) {
        throw "Not a valid Fusion 360 Manage Webhook"
    }

    Import-Module powerVault
    Open-VaultConnection

    $co = Get-VaultChangeOrder -Number $number
    if (-not $co) {
        $co = Add-VaultChangeOrder -Number $number
    }

    $description = [System.Net.WebUtility]::HtmlDecode($description) -replace '<[^>]+>', ''
    $co = Update-VaultChangeOrder -Number $co._Number -Title $title -Description description
    Write-Host "$($co._Number) has been created/updated."
}
catch {
    Write-Host $Error[0]
}