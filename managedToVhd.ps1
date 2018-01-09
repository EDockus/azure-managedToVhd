function Convertfrom-Managed 
{
    param(
        [parameter(Mandatory=$True)]
        [String]$userName,

        [parameter(Mandatory=$True)]
        [String]$password,
        
        [parameter(Mandatory=$True)]
        [String]$VM,
        
        [parameter(Mandatory=$True)]
        [String]$rgName,

        [parameter(Mandatory=$True)]
        [String]$location,

        [parameter(Mandatory=$True)]
        [String]$storageAccountName,

        [parameter(Mandatory=$True)]
        [String]$sku,

        [parameter(Mandatory=$True)]
        [String]$container,

        [parameter(Mandatory=$True)]
        [String]$diskName,

        [parameter(Mandatory=$True)]
        [String]$diskNameDest   
    ) 
    
    try
    {
        $secpwd=ConvertTo-SecureString $password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($userName, $secpwd)    
        Login-AzureRmAccount -Credential $cred
    }
    catch
    {
        return "Unable to login to your Azure account. Exception details: $_.Exception"
    }
    
    ##Optional
    ##If you have more than one subscription associated with your account you would need to select the one you need with Select-AzureRMSubscription. You would need to pass the name or ID as a paremeter

    $state=$($(Get-AzureRmVM -Name $VM -ResourceGroupName $rgName -Status -ErrorAction Stop).Statuses | Where-Object {$_.Code -like "PowerState/*"}).DisplayStatus
    if($state -notlike "VM deallocated")
    {
        Get-AzureRmVM -Name $VM -ResourceGroupName $rgName | Stop-AzureRmVM -Force
    } 

    ## Creating a new storage account, associating a key with that storage account. Then creating a container where the VHD file will go to.
    try
    {
        New-AzureRmStorageAccount -Name $storageAccountName -Location $location -SkuName $sku -ResourceGroupName $rgName -ErrorAction Stop
        $saKey = Get-AzureRmStorageAccountKey -ResourceGroupName $rgName -Name $storageAccountName -ErrorAction Stop
        $storageContext = New-AzureStorageContext –StorageAccountName $storageAccountName -StorageAccountKey $saKey[0].Value -ErrorAction Stop
        New-AzureStorageContainer -Context $storageContext -Name $container -ErrorAction Stop
    }
    catch
    {
        Write-Error "Error preparing storage account. Exception details $_.Exception"
    }

    ## Granting access to the managed disk
    try
    {
        $sas = Grant-AzureRmDiskAccess -ResourceGroupName $rgName -DiskName $diskName -DurationInSecond 3600 -Access Read -ErrorAction Stop
    }
    catch
    {
        Write-Error "Error granting createing access key to the managed disk. Exception details $_.Exception"
    }

    ## Start the copy process
    try
    {
        Start-AzureStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer vhds -DestContext $storageContext -DestBlob $diskNameDest -ErrorAction Stop
    }
    catch
    {
        Write-Error "Error while creating a bloby cop job. Exception details $_.Exception"
    }
    

    ## Run below to get the status
    $status=Get-AzureStorageBlobCopyState -Context $storageContext -Blob $diskNameDest -Container vhds -ErrorAction Stop
    while($status.status -like "Pending")
    {        
        Write-Verbose "Copying $diskNameDest. Bytes copied: $status.BytesCopied. Remaining bytes to copy: $($status.TotalBytes - $status.BytesCopied)"
        Start-Sleep -Seconds 10
        $status=Get-AzureStorageBlobCopyState -Context $storageContext -Blob $diskNameDest -Container $container -ErrorAction Stop
    }
}
