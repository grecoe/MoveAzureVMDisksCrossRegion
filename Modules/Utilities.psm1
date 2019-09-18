<#	
	Copyright  Microsoft Corporation ("Microsoft").
	
	Microsoft grants you the right to use this software in accordance with your subscription agreement, if any, to use software 
	provided for use with Microsoft Azure ("Subscription Agreement").  All software is licensed, not sold.  
	
	If you do not have a Subscription Agreement, or at your option if you so choose, Microsoft grants you a nonexclusive, perpetual, 
	royalty-free right to use and modify this software solely for your internal business purposes in connection with Microsoft Azure 
	and other Microsoft products, including but not limited to, Microsoft R Open, Microsoft R Server, and Microsoft SQL Server.  
	
	Unless otherwise stated in your Subscription Agreement, the following applies.  THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT 
	WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL MICROSOFT OR ITS LICENSORS BE LIABLE 
	FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
	HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE SAMPLE CODE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
#>

<#
	This file contains a group of helper functions to create new resources allowing the main script to not be so cluttered.

	Problematic call: Start-AzureStorageBlobCopy
	https://blogs.msdn.microsoft.com/maheshk/2017/04/17/azure-powershell-how-to-improve-the-blob-copy-operation-in-powershell-by-placing-net-code/
#>

using module .\DiskUtil.psm1
using module .\Configuration.psm1
using module .\BlobCopy.psm1


<#
	CreateDiskSnapshot
	
	Creates a snapshot of the OS disk attached to an existing virtual machine.
	
	Parameters:
		diskInfo - Information about the disk
		
	Returns:
		PSSnapshot
#>
function CreateDiskSnapshot{
	Param([DiskInformation] $diskInfo)

	$snapshotName = $diskInfo.Name.ToLower() + "_ss"
	$snapshotConfig = New-AzureRmSnapshotConfig -SourceUri $diskInfo.Id -CreateOption Copy -Location $diskInfo.Region
	$snapshot= New-AzureRmSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $diskInfo.ResourceGroup

	$snapshot
}

<#
	Move a snapshot to storage, returns the URI in the storage account. 
#>
function MoveSnapshotToStorage{
	Param([MoveDiskConfiguration]$moveConfig, [string]$snapshotName, [string]$storageContainerName, [string]$snapshotBlobName)

	#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600.
	#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
	$sasExpiryDuration = "9600"

	#Generate the SAS for the snapshot 
	$sas = Grant-AzureRMSnapshotAccess -ResourceGroupName $moveConfig.ResourceGroupName -SnapshotName $snapshotName  -DurationInSecond $sasExpiryDuration -Access Read

	#Create the context for the storage account which will be used to copy snapshot to the storage account 
	$destinationContext = New-AzureStorageContext -StorageAccountName $moveConfig.InterimStorageAccount -StorageAccountKey $moveConfig.InterimStorageKey

	#Create container if not exists
	$result = Get-AzureRmStorageContainer -ResourceGroupName  $moveConfig.ResourceGroupName -StorageAccountName $moveConfig.InterimStorageAccount -Name $storageContainerName -ErrorAction SilentlyContinue
	if(-not $result)
	{
		New-AzureStorageContainer -Context $destinationContext -Name $storageContainerName -Permission Blob 
	}

	$start = Get-Date
	Write-Host("Starting copy - " + $start)
	#Copy the snapshot to the storage account and wait for it to complete
	Start-AzureStorageBlobCopy -Force -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $snapshotBlobName
	$copyResult = Get-AzureStorageBlobCopyState -WaitForComplete -Context $destinationContext -Blob $snapshotBlobName -Container $storageContainerName

	$end = Get-Date
	Write-Host("Finished  copy - " + $end)

	Write-Host($copyResult | ConvertTo-Json)

	#Revoke access to the snapshot so it can be deleted
	Revoke-AzureRMSnapshotAccess -ResourceGroupName $moveConfig.ResourceGroupName -SnapshotName $snapshotName

	# Collect blob and account details.
	[BlobCopyDetails] $returnInfo = [BlobCopyDetails]::new()
	$blobFindResult = Get-AzureStorageBlob -Container $storageContainerName -Blob $snapshotBlobName -Context $destinationContext
	$returnInfo.BlobUri = $blobFindResult.ICloudBlob.Uri

	$account = Get-AzureRmStorageAccount -ResourceGroupName $moveConfig.ResourceGroupName -Name $moveConfig.InterimStorageAccount
	$returnInfo.StorageAccountId = $account.Id

	$returnInfo
}


<#
	CreateManagedDiskFromSnapshot
	
	Creates a managed disk from a snapshot object
	
	Parameters:
		vmInfo - Information about the Virtual MachineName
		storageType - Type of Azure storage 
		snapshotId - Azure ResourceID of a snapshot object
		
	Returns:
		PSDisk
#>
function CreateManagedDiskFromSnapshot {
	Param([DiskCreationDetails] $diskDetails)

	$result = Select-AzureRMSubscription -SubscriptionId $diskDetails.SubscriptionId

	$diskConfig = New-AzureRMDiskConfig -AccountType $diskDetails.StorageType -OsType $diskDetails.OsType -DiskSizeGb $diskDetails.DiskSizeGb -Location $diskDetails.Region -CreateOption Import -StorageAccountId $diskDetails.StorageIdentity -SourceUri $diskDetails.BlobUrl
	$newOSDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $diskDetails.ResourceGroup -DiskName $diskDetails.Name

	$newOSDisk
}


<#
	CreateDestinationResourceGroup
	
	Checks in the destination subscription for a resource group with the name provided in teh 
	configuration. If not there it is created.
	
	Subscription is switched to the destination subscription on entry and switched back to the 
	source subscription on return.
	
	Parameters:
		config - Script configuration object
		vmInfo - Information about the Virtual MachineName
		
	Returns:
		Nothing
#>
function CreateDestinationResourceGroup{
	Param([MoveDiskConfiguration] $config )

	# have to set context to the destination sub
	$result = Select-AzureRMSubscription -SubscriptionId $config.DestinationSubscriptionId
	$result = $null
	
	$result = Get-AzureRMResourceGroup -Name $config.DestinationResourceGroup -ErrorAction SilentlyContinue
	if(-not $result)
	{
		Write-Host("Creating Destination Resource Group")
		$autoTags = @{}
		$autoTags.Add("CopyFromSub", $config.SubscriptionId)
		$autoTags.Add("CopyFromRg", $config.ResourceGroupName)
		$result = New-AzureRmResourceGroup -Name $config.DestinationResourceGroup -Location $config.DestinationRegion -Tag $autoTags 
	}
}



