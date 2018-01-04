# azure-managedToVhd

managedToVhd.ps1 <- a simple function that converts a managed disk to a VHD file. It takes the following parameters:

$userName <= Username that you will use to access your Azure subscription
$password <= Password for the account above
$VM <= Name of the virtual machine that has the managed disk assigned
$rgName <= Resource group name
$location <= Location, for example 'North Europe'
$storageAccountName <= Name of the storage account that will host the VHD file. Note - account should not exist, it will be created.
$sku <= Store account SKU, for example 'Premium_LRS'
$container <= How to call the container where VHD file will be stored?
$diskName <= Name of the managed disk
$diskNameDest <= How to call the destination VHD file?

# Using the script

Run the function with relevant parameters. It will then display the copy status every 10 seconds. At that point it is safe to stop the script as the actual blob copy job will continue to run. If you have multiple subscriptions then make sure to add the code to select the right one.