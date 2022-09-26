if (-not $IAmRunningInCallbackAgent) {
    $Payload = @'
{
    "ecrId":61477,
    "ecrNumber":"CR18250-10001",
    "projectId":9152,
    "eventType":"ecr.status.updated",
    "triggeredAt":"2022-08-16T12:00:23Z",
    "triggeredBy":"christian.gessner@coolorange.com",
    "statusOld":"WorkInProgress",
    "statusNew":"Completed"
}
'@
}

#region Settings
$companyName = ""
$username = ""
$password = ""
$clientId = ""
$clientSecret = ""
$baseUrl = "https://live.upchain.net"
#endregion

try {
    $obj = ConvertFrom-Json -InputObject $Payload
    $ecrId = $obj.ecrId
    if (-not $ecrId) {
        throw "Not a valid Upchain Webhook"
    }

    $oauth = Invoke-RestMethod -Method Post -Uri $("https://live-sso.upchain.net/auth/realms/upchain/protocol/openid-connect/token") -Body @{
        grant_type = "password"; username = $username; password = $password; client_id = $clientId; client_secret = $clientSecret 
    }

    $companies = Invoke-RestMethod -Method Get -Uri $("$baseurl/api/auth/v1/companies") -Headers @{Authorization = 'Bearer ' + $oauth.access_token }
    $company = $companies | Where-Object { $_.name -eq $companyName }
    
    $items = New-Object System.Collections.Generic.List[PsObject]
    $itemNumbers = @(Invoke-RestMethod -Method Get -Uri $("$baseurl/api/workflow/v1/ecr/$ecrId/items") -Headers @{Authorization = 'Bearer ' + $oauth.access_token; "Upc-Selected-Company" = $company.Id })
    foreach ($itemNumber in $itemNumbers) {
        $item = Invoke-RestMethod -Method Get -Uri $("$baseurl/api/item/v1/partVersion/$itemNumber") -Headers @{Authorization = 'Bearer ' + $oauth.access_token; "Upc-Selected-Company" = $company.Id }
        $items.Add($item)
    }

    $items | Out-File -FilePath "C:\Temp\$($obj.ecrNumber).txt"

    foreach ($item in $items) {
        # TODO: Update other systems with item information...
    }
}
catch {
    Write-Host $Error[0]
}