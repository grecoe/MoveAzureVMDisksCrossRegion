Using module .\Modules\Configuration.psm1
Using module .\Modules\DiskUtil.psm1
Using module .\Modules\Utilities.psm1
Using module .\Modules\BlobCopy.psm1

Write-Host('********** CONFIGURATION')
$config = [MoveDiskConfiguration]::LoadConfiguration('.\MoveDisks.json')
Write-Host(($config | ConvertTo-Json))
Write-Host('')

foreach($diskName in $config.DiskName)
{
	Write-Host('********** SOURCE SUBSCRIPTION')
	Select-AzureRMSubscription -SubscriptionId $config.SubscriptionId

	Write-Host('********** EXISTING DISK')
	$info = [DiskUtils]::GetDiskInfo($config.ResourceGroupName, $diskName)
	$info.SubscriptionId = $config.SubscriptionId
	Write-Host(($info | ConvertTo-Json))
	Write-Host('')
	Write-Host('DONE')

	Write-Host('********** CREATE SNAPSHOT')
	$snapshot = CreateDiskSnapshot -diskInfo $info
    Write-Host('DONE')
    
	Write-Host('********** MOVE TO STORAGE')
	$snapshotBlobName = $snapshot.Name + ".vhd"
	$blobCopyDetails = MoveSnapshotToStorage -moveConfig $config -snapshotName $snapshot.Name -storageContainerName "vhd" -snapshotBlobName $snapshotBlobName
    Write-Host('DONE')

	Write-Host('********** REMOVE SNAPSHOT')
	Remove-AzureRMResource -ResourceId $snapshot.Id -Force
	Write-Host('DONE')

	Write-Host('********** CREATE DESTINATION RESOURCE GROUP')
	CreateDestinationResourceGroup -config $config
	Write-Host('DONE')

	Write-Host('********** CREATE DISK IN DESTINATION RESOURCE GROUP')
	[DiskCreationDetails] $diskCreate = [DiskCreationDetails]::new()
	$diskCreate.SubscriptionId = $config.SubscriptionId
	$diskCreate.ResourceGroup = $config.DestinationResourceGroup
	$diskCreate.Region = $config.DestinationRegion
	$diskCreate.OsType = $info.OsType
	$diskCreate.StorageIdentity = $blobCopyDetails.StorageAccountId
	$diskCreate.BlobUrl =  $blobCopyDetails.BlobUri
	$diskCreate.StorageType = $info.StorageType
	$diskCreate.DiskSizeGb = $info.DiskSizeGb
	$diskCreate.Name = $info.Name
	$dsk = CreateManagedDiskFromSnapshot -diskDetails $diskCreate
	Write-Host('DONE')
	
}

