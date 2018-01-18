#Resource variables
$subscriptionID = $env:subscriptionID
$resourceGroupName = $env:resourceGroupName
$keyVaultName = $env:keyVaultName
$testSecretName = $env:testSecretName
$WorkspaceID = $env:WorkspaceID
$SharedKey = $env:SharedKey

# Custom Log Data type name for Log Analytics
$LogType = $env:LogTypeName

$armBaseUrl = "https://management.azure.com/subscriptions/$($subscriptionID)/resourceGroups/$($resourceGroupName)/providers/Microsoft.KeyVault/vaults/$($keyVaultName)/"
$armAPIVersion = "2016-10-01"

# Get Managed Service Identity info from Azure Functions Application Settings
$msiEndpoint = $env:MSI_ENDPOINT
$msiSecret = $env:MSI_SECRET

# Authenticate using MSI
$apiVersion = "2017-09-01"
$resourceURI = "https://management.azure.com/"
$tokenAuthURI = "$($msiEndpoint)?resource=$($resourceURI)&api-version=$($apiVersion)"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$msiSecret"} -Uri $tokenAuthURI

# Extract Access token from MSI
$accessToken = $tokenResponse.access_token

# Build Query to ARM REST API
$armUrl = "$($armBaseUrl)secrets/$($testSecretName)?api-version=$($armAPIVersion)"
$armHeader = @{"Authorization"="Bearer $accessToken"}

# Invoke ARM REST API

$resp = try {Invoke-WebRequest -Method Get -Uri $armUrl -Headers $armHeader -UseBasicParsing -ErrorAction SilentlyContinue} catch { $_.Exception.Response }
if($resp.StatusCode -eq "200"){
    $resourceId = (Convertfrom-Json $resp).id
    $json = @"
[{  "KeyVaultName": "$($keyVaultName)",
    "ResourceGroupName": "$($resourceGroupName)",
    "ResourceId" :  "$($resourceId)",
    "subscriptionID" : "$($subscriptionID)",
    "StatusCode": "$($resp.StatusCode)",
}]
"@
} else {
    $json = @"
[{  "KeyVaultName": "$($keyVaultName)",
    "ResourceGroupName": "$($resourceGroupName)",
    "subscriptionID" : "$($subscriptionID)",
    "StatusCode": "$($resp.StatusCode)",
}]
"@
}

# Create the function to create the authorization signature
Function Build-Signature ($WorkspaceID, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $WorkspaceID,$encodedHash
    return $authorization
}

# Create the function to create and post the request
Function Post-OMSData($WorkspaceID, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -WorkspaceID $WorkspaceID `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $WorkspaceID + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}

# Submit the data to the API endpoint
Post-OMSData -WorkspaceID $WorkspaceID -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
