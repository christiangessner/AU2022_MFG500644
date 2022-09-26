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
$targetFolderPath = "$/Designs/Projects"
$categoryName = "Project"
#endregion

try {
    $obj = ConvertFrom-Json -InputObject $Payload
    if (-not $obj.payload.ItemUrn -or -not $obj.hook.event) {
        throw "Not a valid Fusion 360 Manage Webhook"
    }

    $urn = $obj.payload.ItemUrn
    $contents = [array]$urn.Split(':')
    $values = $contents[$contents.Length - 1].Split('.')
    $names = $contents[$contents.Length - 2].Split('.')
    $tenantName = $values[[array]::IndexOf($names, "tenant")]
    $workspaceId = $values[[array]::IndexOf($names, "workspace")]
    $itemId = $values[[array]::IndexOf($names, "item")]

    Write-Host "Webhook received for tenant '$($tenantName)', workspace #$($workspaceId), item #$($itemId)"

    Import-Module powerVault
    Import-Module powerFLC

    Open-VaultConnection
    $connected = Connect-FLC -UseSystemUserEmail
    if (-not $connected) {
        throw "Connection to Fusion 360 Manage failed! Error: `n $($connected.Error.Message)`n See '$($env:LOCALAPPDATA)\coolOrange\powerFLC\Logs\powerFLC.log' for details"
    }

    $workspace = $flcConnection.Workspaces[$workspaceId]
    $flcItems = Get-FLCItems -Workspace $workspace.Name -Filter "itemId=$($itemId)"

    if (-not $flcItems -or $flcItems.Count -ne 1) {
        throw "Item not found - should not happen"
    }

    $flcItem = $flcItems[0]
    Write-Host "$($flcItem.Number) has been changed. Update Vault entity..."

    Write-Host "Create or update folder in Vault"
    $targetFolder = $vault.DocumentService.GetFoldersByPaths(@($targetFolderPath))[0]
    $folders = $vault.DocumentService.GetFoldersByParentId($targetFolder.Id, $false)
    $propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FLDR")
    $cats = $vault.CategoryService.GetCategoriesByEntityClassId("FLDR", $true)
    $cat = $cats | Where-Object { $_.Name -eq $categoryName }
    $folderName = $flcItem.Number
    $folder = $folders | Where-Object { $_.Name -eq $folderName }
    if (-not $folder) {
        Write-Host "Create folder '$($folderName)'..."  
        $folder = $vault.DocumentServiceExtensions.AddFolderWithCategory($folderName, $targetFolder.Id, $false, $cat.Id)
    }
  
    $properties = @{
        "Description"    = [System.Net.WebUtility]::HtmlDecode($flcItem.Description) -replace '<[^>]+>', '';
        "Title"          = $flcItem.Title
        "Project Number" = $flcItem.Number
    }

    $propInstParamArray = New-Object Autodesk.Connectivity.WebServices.PropInstParamArray
    $propInstParams = @()
    foreach ($prop in $properties.GetEnumerator()) {
        $propDef = $propDefs | Where-Object { $_.DispName -eq $prop.Name }
        $propInstParam = New-Object Autodesk.Connectivity.WebServices.PropInstParam
        $propInstParam.PropDefId = $propDef.Id
        $propInstParam.Val = $prop.Value
        $propInstParams += $propInstParam
    }
    $propInstParamArray.Items = $propInstParams

    Write-Host "Update folder properties for folder '$($folder.FullName)'..."
    $vault.DocumentServiceExtensions.UpdateFolderProperties(@($folder.Id), @($propInstParamArray))
}
catch {
    Write-Host $Error[0]
}