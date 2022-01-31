param (
    [string]$SUBSCRIPTION_ID = $(throw "-SUBSCRIPTION_ID is required."),
    [string]$RESOURCE_GROUP = "dev-rg",
    [string]$LOCATION = "australiaeast"
)
$sw = [Diagnostics.Stopwatch]::StartNew()
$randomNumber = (Get-Random -Minimum 10000 -Maximum 99999).ToString()
$storageName = "str$randomNumber"
$functionAppName = "fxn$randomNumber"
$appInsightsName = "funcsmsi$randomNumber"
$appConfigName = "appcon$randomNumber"
$keyVaultName = "kv$randomNumber"
$secretName = "secret$randomNumber"

$zipName = "publish.zip"
$publishFolder = "./TestFxnApp/TestFunctionApp/bin/Release/netcoreapp3.1/publish"

if (Test-path $zipName) {
    Remove-item $zipName
}

Add-Type -assembly "system.io.compression.filesystem"

Write-Host -ForegroundColor Yellow "Publishing function app"
dotnet publish -c Release .\TestFxnApp\TestFxnApp\TestFxnApp.sln

Write-Host -ForegroundColor Yellow "Zipping function app"
[io.compression.zipfile]::CreateFromDirectory($publishFolder, $zipName)

if (!(Test-path $zipName)) {
    EXIT
}

Write-Host -ForegroundColor Yellow "Creating resource group"
az group create `
    -n $RESOURCE_GROUP `
    -l $LOCATION `
    --verbose

Write-Host -ForegroundColor Yellow "Creating storage account"
az storage account create `
    --name $storageName `
    --location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --sku Standard_LRS `
    --verbose

Write-Host -ForegroundColor Yellow "Creating app insights"
az resource create `
    --name $appInsightsName `
    --resource-group $RESOURCE_GROUP `
    --resource-type "Microsoft.Insights/components" `
    --properties '{\"Application_Type\":\"web\"}'

Write-Host -ForegroundColor Yellow "Creating key vault"
az keyvault create `
    --name $keyVaultName `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --verbose

Write-Host -ForegroundColor Yellow "Creating secret"
az keyvault secret set `
    --name $secretName `
    --vault-name $keyVaultName `
    --value MySecretValue `
    --verbose

Write-Host -ForegroundColor Yellow "Listing secrets"
az keyvault secret list `
    --vault-name $keyVaultName `
    --subscription $SUBSCRIPTION_ID `
    --verbose

Write-Host -ForegroundColor Yellow "Creating app configuration"
az appconfig create `
    --name $appConfigName `
    --location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --sku free `
    --verbose

Write-Host -ForegroundColor Yellow "Creating app configuration kv"
az appconfig kv set `
    --name $appConfigName `
    --subscription $SUBSCRIPTION_ID `
    --key AppConfigKey `
    --value AppConfigValue `
    --yes `
    --verbose

Write-Host -ForegroundColor Yellow "Listing app configurations"
az appconfig kv list `
    --name $appConfigName `
    --subscription $SUBSCRIPTION_ID

Write-Host -ForegroundColor Yellow "Creating function app"
az functionapp create `
    --name $functionAppName `
    --storage-account $storageName `
    --consumption-plan-location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --app-insights $appInsightsName `
    --functions-version 3 `
    --verbose

Write-Host -ForegroundColor Yellow "Setting daily memory time quota"
az functionapp update `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --set dailyMemoryTimeQuota=5000

Write-Host -ForegroundColor Yellow "Deploying function app"
az functionapp deployment source config-zip `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --src $zipName `
    --verbose

Write-Host -ForegroundColor Yellow "Settings function app settings"
az functionapp config appsettings set `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --settings "MySetting1=Hello" "MySetting2=World" `
    --verbose

$sw.Stop()
Write-Host 'Command ran in' $sw.Elapsed.ToString("mm\:ss") -ForegroundColor Green