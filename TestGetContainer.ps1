
Using module .\Modules\Configuration.psm1
Using module .\Modules\DiskUtil.psm1
Using module .\Modules\Utilities.psm1
Using module .\Modules\BlobCopy.psm1

Write-Host('********** CONFIGURATION')
$config = [MoveDiskConfiguration]::LoadConfiguration('.\MoveDisks.json')
Write-Host(($config | ConvertTo-Json))
Write-Host('')

Write-Host('********** SOURCE SUBSCRIPTION')
Select-AzureRMSubscription -SubscriptionId $config.SubscriptionId

<# Get account information......
$destinationContext = New-AzureStorageContext -StorageAccountName $config.InterimStorageAccount -StorageAccountKey $config.InterimStorageKey

$account = Get-AzureRmStorageAccount -ResourceGroupName $config.ResourceGroupName -Name $config.InterimStorageAccount
Write-Host($account.Id)

$blobFindResult = Get-AzureStorageBlob -Container "vhd" -Blob "devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk_ss.vhd" -Context $destinationContext
Write-Host($blobFindResult.ICloudBlob.Uri)
#>


#
# /subscriptions/edf507a2-6235-46c5-b560-fd463ba2e771/resourceGroups/dangmovedtest/providers/Microsoft.Storage/storageAccounts/dangstoragetest
# https://dangstoragetest.blob.core.windows.net/vhd/devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk_ss.vhd

#
# DO ALL OTHER WORK TO GET IT INTO STORAGE
# 

<# #>
[DiskCreationDetails] $diskCreate = [DiskCreationDetails]::new()
$diskCreate.SubscriptionId = $config.SubscriptionId
$diskCreate.ResourceGroup = $config.DestinationResourceGroup
$diskCreate.Region = $config.DestinationRegion

$diskCreate.OsType = "Windows"
$diskCreate.StorageIdentity = "/subscriptions/edf507a2-6235-46c5-b560-fd463ba2e771/resourceGroups/dangmovedtest/providers/Microsoft.Storage/storageAccounts/dangssaccount"
$diskCreate.BlobUrl =  "https://dangssaccount.blob.core.windows.net/vhd/devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk_ss.vhd"
$diskCreate.StorageType = "Premium_LRS"
$diskCreate.DiskSizeGb = "127"
$diskCreate.Name = "n_devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk"

$dsk = CreateManagedDiskFromSnapshot -diskDetails $diskCreate
Write-Host($dsk | ConvertTo-Json)

<#
$storageAccountId = "/subscriptions/edf507a2-6235-46c5-b560-fd463ba2e771/resourceGroups/dangmovedtest/providers/Microsoft.Storage/storageAccounts/dangssaccount"
$blobUri = "https://dangssaccount.blob.core.windows.net/vhd/devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk_ss.vhd"
$storageType = "Premium_LRS"
$diskName = "y_devopseastjump_osdisk_1_a6634d51291c4e69bed54f3f4da4b36f_dsk"
$diskSize = "127"

# Changes things over to new old sub
CreateDestinationResourceGroup -config $config

$diskConfig = New-AzureRMDiskConfig -AccountType $storageType -DiskSizeGb $diskSize -Location $config.DestinationRegion -CreateOption Import -StorageAccountId $storageAccountId -SourceUri $blobUri

New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $config.DestinationResourceGroup -DiskName $diskName

#$result = Select-AzureRMSubscription -SubscriptionId $config.SubscriptionId
#$result = az account set -s $config.SubscriptionId
#>
