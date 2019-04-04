$rgName = "network"
$location = "westeurope"

az group create --name $rgName --location $location

az group deployment create --name "Network-Resource-Group" --resource-group $rgName --template-file "network.json"