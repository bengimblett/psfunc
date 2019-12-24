[CmdletBinding()]
Param(
  [Parameter(Mandatory=$False)]
  [string]$RG="begim-ps1func-demo-rg",

  [Parameter(Mandatory=$False)]
  [string]$ResourcesPrefix="begim1975"
)

#az login
$Location="westeurope"

# create RG
$rgExists = az group exists -n $RG
if ( $rgExists -eq $False ){
    Write-Output "Creating RG"
  az group create -n $RG -l $Location
}

$templateFile = "deploy.json"

az group deployment create -n "ps1-func-demo" -g $RG --template-file "$templateFile" --parameters resourcesPrefix=$ResourcesPrefix 

Write-Host "deployed resources, pushing function code"

## function 
$funcname = "$ResourcesPrefix" + "-demops1func"
remove-item "..\publish" -Force -Recurse
mkdir "..\publish"
$publishpath="..\publish\PSHttpTriggerDemo"
mkdir $publishpath
Copy-Item -path "..\PSHttpTriggerDemo\*.*" -destination $publishpath -Force
Copy-Item -path "..\host.json" -destination "..\publish\" -Force 
## publish, zip and deploy function via the cli - function name hard coded here could be output from template
$compress = @{
  Path= "..\publish\*"
  CompressionLevel = "Fastest"
  DestinationPath = "PSHttpTriggerDemo.zip"
}
Compress-Archive @compress -Force
az functionapp deployment source config-zip  -g $RG -n $funcname --src "PSHttpTriggerDemo.zip"

write-host "published function" -ForegroundColor Green


az functionapp identity assign --name $funcname --resource-group $RG
write-host "set sys identity (MSI) for func app"
write-host "create container and assign storage IAM permissions"


