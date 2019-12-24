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

# try and get blob list for this container/storage acc
$xmlContent = ""
$utf8Bom = $false
$blobCount = -1
$status = [HttpStatusCode]::BadRequest

try{
    # assumes the MSI has been given blob permission on the storage acc (not contrib and owner are not enough)
    $resourceURI = "https://storage.azure.com/"
    $tokenAuthURI = $env:MSI_ENDPOINT + "?resource=$resourceURI&api-version=2017-09-01"
    $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$env:MSI_SECRET"} -Uri $tokenAuthURI
    $accessToken = $tokenResponse.access_token

    $headers = @{
        'x-ms-version'='2017-11-09'
        'Accept-Charset'='utf-8'
        'Authorization'='Bearer ' + $accessToken
    }
    $url = "https://$accName.blob.core.windows.net/$containerName" + "?restype=container&comp=list"
    Write-Host $url
    $xml=""
    $xmlcontent=Invoke-RestMethod -Uri $url -Method GET -Headers $headers 


} catch {
    $body = "An unexpected Error occured calling Blob storage service"

}

#check for bom
if ($xmlcontent -and $xmlcontent.Length -gt 3) {
    [byte]$char1 = [System.Convert]::ToByte([char]$xmlcontent.Substring(0,1))
    [byte]$char2 = [System.Convert]::ToByte([char]$xmlcontent.Substring(1,1))
    [byte]$char3 = [System.Convert]::ToByte([char]$xmlcontent.Substring(2,1))

    ## UTF8 BOM 239 187 191 - storage service appears to add an explicit utf8 bom 
    # ï»¿<?xml version="1.0" encoding="utf-8"?>
    if ( $char1 -eq 239 -and $char2 -eq 187 -and $char3 -eq 191 ){
        write-host "encoding is utf8"
        $utf8Bom = $true
    }
    # bom must be removed first to parse xml (afaik reason is the encoding is provided explicitly in the xml header)
    # eg. <?xml version="1.0" encoding="utf-8"?>
    if ( $utf8Bom -eq $true ) {
        write-host "strip bom"
        $xmlContent = $xmlContent.Substring(3,$xmlContent.Length-3)
    }
    try {
        $xdoc = New-Object -TypeName System.Xml.XmlDocument
        $xdoc.LoadXml($xmlContent)
        $blobCount=$xdoc.DocumentElement.Blobs.ChildNodes.Count
        write-host "blobs found $blobCount"

        $status = [HttpStatusCode]::OK
        $body = "$blobCount"
    }
    catch {
        $body = "An unexpected Error occured parsing Blob storage xml response1"
    }
}
else {
    $body = "No valid xml response from blob storage service for the input"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})

