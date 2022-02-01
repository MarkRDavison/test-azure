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
$secretName = "KeyVaultSecretKey" # This is used in the function app

$zipName = "publish.zip"
$publishFolder = "./TestFxnApp/TestFunctionApp/bin/Release/netcoreapp3.1/publish"

if (Test-path $zipName) {
    Remove-item $zipName
}

Add-Type -assembly "system.io.compression.filesystem"

Write-Host -ForegroundColor Yellow "Publishing function app"
dotnet publish -c Release .\TestFxnApp\TestFunctionApp\TestFunctionApp.csproj

Write-Host -ForegroundColor Yellow "Zipping function app"
[io.compression.zipfile]::CreateFromDirectory($publishFolder, $zipName)

if (!(Test-path $zipName)) {
    Write-Host -ForegroundColor Red "Function app zip not created"
    EXIT
}

Write-Host -ForegroundColor Yellow "Creating resource group"
az group create `
    -n $RESOURCE_GROUP `
    -l $LOCATION

Write-Host -ForegroundColor Yellow "Creating storage account"
az storage account create `
    --name $storageName `
    --location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --sku Standard_LRS

Write-Host -ForegroundColor Yellow "Creating app insights"
az resource create `
    --name $appInsightsName `
    --resource-group $RESOURCE_GROUP `
    --resource-type "Microsoft.Insights/components" `
    --properties '{\"Application_Type\":\"web\"}'

Write-Host -ForegroundColor Yellow "Creating function app"
az functionapp create `
    --name $functionAppName `
    --storage-account $storageName `
    --consumption-plan-location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --app-insights $appInsightsName `
    --functions-version 3

Write-Host -ForegroundColor Yellow "Assigning Managed Identity to function app"
az functionapp identity assign `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP

Write-Host -ForegroundColor Yellow "Creating key vault"
az keyvault create `
    --name $keyVaultName `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --enable-rbac-authorization

Write-Host -ForegroundColor Yellow "Creating app configuration"
az appconfig create `
    --name $appConfigName `
    --location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --sku free

Write-Host -ForegroundColor Yellow "Creating app configuration entry"
az appconfig kv set `
    --name $appConfigName `
    --subscription $SUBSCRIPTION_ID `
    --key AppConfigKey `
    --value ThisIsComingFromAppConfiguration `
    --yes

Write-Host -ForegroundColor Yellow "Listing app configurations"
az appconfig kv list `
    --name $appConfigName `
    --subscription $SUBSCRIPTION_ID

Write-Host -ForegroundColor Yellow "Getting app configuration endpoint"
$AppConfigEndpoint=$( `
az appconfig show `
    --resource-group $RESOURCE_GROUP `
    --name $appConfigName `
    --query endpoint)
Write-Host $AppConfigEndpoint -ForegroundColor Green


Write-Host -ForegroundColor Yellow "Setting daily memory time quota"
az functionapp update `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --set dailyMemoryTimeQuota=5000

Write-Host -ForegroundColor Yellow "Settings function app settings"
az functionapp config appsettings set `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --settings "MySetting1=Hello" "MySetting2=World" "AppConfigEndpoint=$AppConfigEndpoint"

Write-Host -ForegroundColor Yellow "Fetching function app managed identity id"
$functionPrincipalId = az functionapp identity show -n $functionAppName -g $RESOURCE_GROUP --query principalId -o tsv

Write-Host -ForegroundColor Yellow "Fetching App Configuration Data Reader Role info"
$appConfigDataReaderRoleName = $(az role definition list --name "App Configuration Data Reader" --query [0].name -o tsv)
$appConfigScope = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.AppConfiguration/configurationStores/$appConfigName"

Write-Host -ForegroundColor Yellow "Creating Role Assignment for function app in App Configuration"
az role assignment create `
    --assignee-object-id $functionPrincipalId `
    --assignee-principal-type "ServicePrincipal" `
    --role $appConfigDataReaderRoleName `
    --scope $appConfigScope

Write-Host -ForegroundColor Yellow "Fetching Key Vault Secrets User Role info"
$keyVaultSecretsUserRoleName = az role definition list --name "Key Vault Secrets User" --query [0].name -o tsv
$keyVaultSecretsOfficerRoleName = az role definition list --name "Key Vault Secrets Officer" --query [0].name -o tsv
$kvScope = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$keyVaultName"

Write-Host -ForegroundColor Yellow "Creating Role Assignment for function app in Key Vault"
az role assignment create `
    --assignee-object-id $functionPrincipalId `
    --assignee-principal-type "ServicePrincipal" `
    --role $keyVaultSecretsUserRoleName `
    --scope $kvScope

Write-Host -ForegroundColor Yellow "Creating Role Assignment for current user in Key Vault"
$currentUserId = az ad signed-in-user show --query objectId -o tsv
az role assignment create `
    --assignee-object-id $currentUserId `
    --assignee-principal-type "User" `
    --role $keyVaultSecretsOfficerRoleName `
    --scope $kvScope

Write-Host -ForegroundColor Yellow "Waiting for Role Assignment to propogate (30s)"

Start-Sleep -Seconds 30

Write-Host -ForegroundColor Yellow "Creating secret"
az keyvault secret set `
    --name $secretName `
    --vault-name $keyVaultName `
    --value ThisIsComingFromKeyVault

Write-Host -ForegroundColor Yellow "Listing secrets"
az keyvault secret list `
    --vault-name $keyVaultName `
    --subscription $SUBSCRIPTION_ID

Write-Host -ForegroundColor Yellow "Getting key vault secret id"
$keyVaultSecretId = (az keyvault secret list `
    --vault-name $keyVaultName `
    --query "[?name=='$secretName'].id | [0]")
Write-Host $keyVaultSecretId -ForegroundColor Green

Write-Host -ForegroundColor Yellow "Setting keyvault secret in app config"
az appconfig kv set-keyvault `
    --name $appConfigName `
    --key $secretName `
    --secret-identifier $keyVaultSecretId `
    --yes

Write-Host -ForegroundColor Yellow "Deploying function app"
az functionapp deployment source config-zip `
    --name $functionAppName `
    --resource-group $RESOURCE_GROUP `
    --src $zipName

$sw.Stop()
Write-Host 'Script ran in' $sw.Elapsed.ToString("mm\:ss") -ForegroundColor Green