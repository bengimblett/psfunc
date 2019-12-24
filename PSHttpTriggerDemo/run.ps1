using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$accName = $Request.Query.AccName
if ($accName) {
}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a storage account name on the query string or in the request body."
}

$containerName = $Request.Query.ContainerName
if ($containerName) {
}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a container name on the query string or in the request body."
}


# assumes the MSI has been given blob permission on the storage acc (not contrib and owner are not enough)
$resourceURI = "https://storage.azure.com/"
$tokenAuthURI = $env:MSI_ENDPOINT + "?resource=$resourceURI&api-version=2017-09-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$env:MSI_SECRET"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token

#Write-Host "token $accessToken"

$headers = @{
    'x-ms-version'='2017-11-09'
    'Authorization'='Bearer ' + $accessToken
}
$url = "https://$accName.blob.core.windows.net/$containerName" +"?restype=container&comp=list"
$respXml=Invoke-RestMethod -Uri $url -Method GET -Headers $headers  | ConvertTo-Xml

$status = [HttpStatusCode]::OK
$body = "Storage response $resp"

Write-Host $resp

$info = $respXml.SelectNodes('/blobs').count

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = "Count of blobs $info"
})


<?xml version="1.0" encoding="utf-8"?>
<EnumerationResults ServiceEndpoint="https://begimreadfromdemo.blob.core.windows.net/" ContainerName="demo">
<Blobs><Blob><Name>deleteme.txt</Name><Properties><Creation-Time>Fri, 20 Dec 2019 17:14:15 GMT</Creation-Time><Last-Modified>Fri, 20 Dec 2019 17:14:15 GMT</Last-Modified><Etag>0x8D785700AC7E733</Etag><Content-Length>4</Content-Length><Content-Type>text/plain</Content-Type><Content-Encoding /><Content-Language /><Content-MD5 /><Cache-Control /><Content-Disposition /><BlobType>BlockBlob</BlobType><AccessTier>Hot</AccessTier><AccessTierInferred>true</AccessTierInferred><LeaseStatus>unlocked</LeaseStatus><LeaseState>available</LeaseState><ServerEncrypted>true</ServerEncrypted></Properties></Blob></Blobs><NextMarker /></EnumerationResults>
