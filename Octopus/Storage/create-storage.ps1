$rgName = "storage"
$location = "westeurope"
$accountName = "infrastorm"

az group create --name $rgName --location $location

az storage account create --name $accountName --resource-group $rgName --location $location --sku "Standard_LRS" --encryption "blob"
