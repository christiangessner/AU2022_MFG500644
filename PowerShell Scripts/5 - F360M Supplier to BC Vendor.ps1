if (-not $IAmRunningInCallbackAgent) {
    $Payload = @'
{
    "version" : "1.0",
    "resourceUrn" : "urn:adsk.plm:tenant.workspace.item:DEFAULTTRAIN61.14.14839",
    "hook" : {
        "hookId" : "00000000-0000-0000-0000-000000000000",
        "tenant" : "DEFAULTTRAIN61",
        "callbackUrl" : "https://powergate.online/api/callback?code=00000000-0000-0000-0000-000000000000&action=F360M%20Supplier%20to%20BC%20Vendor",
        "createdBy" : "200907170821730",
        "event" : "item.update",
        "createdDate" : "2022-08-28T10:08:22.865+00:00",
        "lastUpdatedDate" : "2022-08-28T10:08:22.680+00:00",
        "system" : "adsk.flc.production",
        "creatorType" : "O2User",
        "status" : "active",
        "scope" : {
            "workspace" : "urn:adsk.plm:tenant.workspace:DEFAULTTRAIN61.14"
        },
        "autoReactivateHook" : false,
        "urn" : "urn:adsk.webhooks:events.hook:00000000-0000-0000-0000-000000000000",
        "callbackWithEventPayloadOnly" : false,
        "__self__" : "/systems/adsk.flc.production/events/item.update/hooks/00000000-0000-0000-0000-000000000000"
    },
    "payload" : {
        "ItemUrn" : "urn:adsk.plm:tenant.workspace.item:DEFAULTTRAIN61.14.14839",
        "ItemDescription" : "COOLORANGE"
    }
}
'@
}

#region Settings
$flcClientId = ""
$flcClientSecret = ""
$flcEmail = ""
$flcTenant = ""

$companyName = "CRONUS IT"
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
    if (-not $obj.payload.ItemUrn -or -not $obj.hook.event) {
        throw "Not a valid Fusion 360 Manage Webhook"
    }

    $hookEvent = $obj.hook.event
    $urn = $obj.payload.ItemUrn
    $contents = [array]$urn.Split(':')
    $values = $contents[$contents.Length - 1].Split('.')
    $names = $contents[$contents.Length - 2].Split('.')
    $tenantName = $values[[array]::IndexOf($names, "tenant")]
    $workspaceId = $values[[array]::IndexOf($names, "workspace")]
    $itemId = $values[[array]::IndexOf($names, "item")]

    Write-Host "Webhook received for tenant '$($tenantName)', workspace #$($workspaceId), item #$($itemId)"

    Import-Module powerFLC
    $connected = Connect-FLC -ClientId $flcClientId -ClientSecret $flcClientSecret -UserId $flcEmail -Tenant $flcTenant
    if (-not $connected) {
        throw "Connection to Fusion 360 Manage failed! Error: `n $($connected.Error.Message)`n See '$($env:LOCALAPPDATA)\coolOrange\powerFLC\Logs\powerFLC.log' for details"
    }

    $workspace = $flcConnection.Workspaces[$workspaceId]
    $flcItems = Get-FLCItems -Workspace $workspace.Name -Filter "itemId=$($itemId)"

    if (-not $flcItems -or $flcItems.Count -ne 1) {
        throw "Item not found - should not happen"
    }

    $flcItem = $flcItems[0]
    Write-Host "Supplier '$($flcItem.Name)' -> $hookEvent"

    $oauth = Invoke-RestMethod -Method Post -Uri $("https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token") -Body @{
        grant_type = $grantType; scope = $scope; client_id = $clientID; client_secret = $clientSecret 
    }

    $companies = Invoke-RestMethod -Method Get -Uri $("$baseurl/api/v2.0/companies") -Headers @{Authorization = 'Bearer ' + $oauth.access_token }
    $company = $companies.value | Where-Object { $_.name -eq $companyName }

    $resource = "api/v2.0/companies($($company.id))/vendors?`$filter=displayName eq '$($flcItem.Name)'"
    $response = Invoke-RestMethod -Method Get -Uri $("$baseurl/$resource") -Headers @{Authorization = 'Bearer ' + $oauth.access_token }

    if ($response.value.Count -eq 1) {
        $vendor = $response.value
        $body = @{
            "addressLine1" = $flcItem.Street;
            "city"         = $flcItem.'City / Town';
            "state"        = $flcItem.'State / County';
            "country"      = $flcItem.Country.Substring(0,2).ToUpper();
            "postalCode"   = $flcItem.'Zip Code / Postal Code';
            "phoneNumber"  = $flcItem.'Main Phone';
            "email"        = $flcItem.'Email Sales';
            "website"      = $flcItem.URL
        } | ConvertTo-Json
        $resource = "api/v2.0/companies($($company.id))/vendors($($vendor.id))"
        $vendor = Invoke-RestMethod "$baseUrl/$resource" -Method Patch -Headers @{Authorization = 'Bearer ' + $oauth.access_token; "If-Match" = $vendor.'@odata.etag' } -Body $body -ContentType "application/json"
    }
}
catch {
    Write-Host $Error[0]
}