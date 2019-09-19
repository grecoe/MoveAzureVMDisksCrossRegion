# MoveAzureVMDisksCrossRegion
In the original repo that moved a VM and a VM disk, it assumed you would be able to move them into either the same subscription or a different subscription but into the same region. 

This code can be found [here](https://github.com/grecoe/MoveAzureVirtualMachine)

However, there are times when you need to move the machine to a different region. This requires considerable more consideration as it is not widely supported and requires many more steps. Those are:

1. Create a snapshot of the disk
2. Copy the snapshot to a storage account WITHIN the region you want to re-constitute the machine.
3. Initiate a VM disk using the storage account blob of the snapshot. 
4. Manually create a VM from the restored images in the new location.

## Information you will need:

- Source subscription ID containing the VM to move
- Source resource group name of the VM to move
- A list of disk associated with the subscription
- A destination region.
- A NEW storage account in the source resource group but created in the desired destination region.
  - For example, if you want to move the disk to South Central US, create the new storage account in South Central US.  
- Destination subscription ID where the VM will move to, this can be the same as the source subscription ID.
- Destination resource group name, this MUST be different than the source resource group name if moving to the same subscription, but can be the same if the destination subscription is different.

## Populate MoveDisks.json


## Execute MoveDisks.ps1
This is going to take a while, and it's suggested that you run this on a VM somewhere in Azure so that you are SURE the machine will NOT got to sleep. Using Start-AzureStorageBlobCopy is a painfully long executing task, particularly when you are moving a 100GB+ file. 

Be patient :) 

Interestingly, using the [Azure Upload Tool](http://www.azurespeed.com/Azure/Upload) shows that moving data between regions runs about 373kbs and I experienced around 339kbs for the regions I was coming from/to. 

## Create VM
Go to the new subscription where you copied the disks. Click on the OS disk of the VM and you should see the CreateVM button available.
- Click CreateVM
- During the configuration process you can attach other disks before creating the VM.
- Open whatever ports you need, or do it later after creation.
- Once created, in the portal, change your user password to the VM
- Log in

