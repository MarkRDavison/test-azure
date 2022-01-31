param (
    [string]$RESOURCE_GROUP = "dev-rg",
    [string]$SUBSCRIPTION_ID = $(throw "-SUBSCRIPTION_ID is required.")
)

az group delete `
    --name $RESOURCE_GROUP `
    --subscription $SUBSCRIPTION_ID `
    --yes `
    --verbose