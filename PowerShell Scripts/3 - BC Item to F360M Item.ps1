if (-not $IAmRunningInCallbackAgent) {
    $Payload = @'
{
  "value": [
    {
      "subscriptionId": "9a78e8a3cb5d46aba636824af8cc7a8c",
      "clientState": "powerGate.online",
      "expirationDateTime": "2022-06-26T16:26:05Z",
      "resource": "api/v2.0/companies(00000000-0000-0000-0000-000000000000)/items(00000000-0000-0000-0000-000000000000)",
      "changeType": "updated",
      "lastModifiedDateTime": "2022-06-23T21:29:48.293Z"
    }
  ]
}
'@
}

#region Settings
$flcClientId = ""
$flcClientSecret = ""
$flcEmail = ""
$flcTenant = ""

$tenantId = ""
$environment = "sandbox" #"production"
$grantType = "client_credentials"
$scope = "https://api.businesscentral.dynamics.com/.default"
$clientID = ""
$clientSecret = ""
$baseUrl = "https://api.businesscentral.dynamics.com/v2.0/$environment"
#endregion

try {
    $obj = ConvertFrom-Json -InputObject $Payload
    $resource = $obj.value.resource
    $changeType = $obj.value.changeType
    if (-not $resource -or -not $changeType) {
        throw "Not a valid Business Central Webhook"
    }

    $oauth = Invoke-RestMethod -Method Post -Uri $("https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token") -Body @{
        grant_type = $grantType; scope = $scope; client_id = $clientId; client_secret = $clientSecret 
    }

    $item = Invoke-RestMethod -Method Get -Uri $("$baseurl/$resource") -Headers @{Authorization = 'Bearer ' + $oauth.access_token }
    $picture = Invoke-RestMethod -Method Get -Uri $("$baseurl/$resource/picture") -ContentType "image/jpg" -Headers @{Authorization = 'Bearer ' + $oauth.access_token }
    if ($picture) {
        $response = Invoke-WebRequest -Method Get -Uri $($picture.'pictureContent@odata.mediaReadLink') -ContentType $picture.contentType -Headers @{Authorization = 'Bearer ' + $oauth.access_token }
        $imageBytes = $response.Content
    }
    else {
        $imageBytes = $null
    }

    Import-Module powerFLC
    $connected = Connect-FLC -ClientId $flcClientId -ClientSecret $flcClientSecret -UserId $flcEmail -Tenant $flcTenant
    if (-not $connected) {
        throw "Connection to Fusion 360 Manage failed! Error: `n $($connected.Error.Message)`n See '$($env:LOCALAPPDATA)\coolOrange\powerFLC\Logs\powerFLC.log' for details"
    }

    $workspace = $flcConnection.Workspaces.Find("Vault Items and BOMs")

    $properties = @{
        "Description" = $item.displayName;
        "Title"       = $item.displayName;
        "Category"    = $item.itemCategoryCode;
        "Number"      = $item.number;
        "Thumbnail"   = $imageBytes;
    }

    $flcItem = (Get-FLCItems -Workspace $workspace.Name -Filter ('ITEM_DETAILS:NUMBER="{0}"' -f $item.number))[0]
    if (-not $flcItem) {
        Write-Host "Create item $($item.number)..."
        $flcItem = Add-FLCItem -Workspace $workspace.Name -Properties $properties -ErrorAction Stop
    }
    else {
        Write-Host "Update item $($item.number)..."
        $flcItem = Update-FLCItem -Workspace $flcItem.Workspace -ItemId $flcItem.Id -Properties $properties -ErrorAction Stop
    }

    Write-Host "Fusion 360 Manage item $($flcItem.Number) has been created/updated."
}
catch {
    Write-Host $Error[0]
}