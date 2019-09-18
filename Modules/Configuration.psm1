
<#
	Class that encapsulates the configuration needed to move a disk.
#>
class MoveDiskConfiguration {
	$SubscriptionId 
	$ResourceGroupName 
	$DiskName 

	$DestinationSubscriptionId 
    $DestinationResourceGroup 
    $DestinationRegion
    $InterimStorageAccount
    $InterimStorageKey

	<#
		LoadConfiguration
		
		Loads up the data from the local configuration json file.
		
		Parameters:
			configurationFile - The path of a local file containing the configuration 
								options.
								
		Returns:
			Instance of MoveConfiguration
	#>
	static [MoveDiskConfiguration] LoadConfiguration([string]$configurationFile)
	{
        $configurationObject = Get-Content -Path $configurationFile -raw | ConvertFrom-Json

		$configuration = @{}
		$configurationObject.psobject.properties | Foreach { $configuration[$_.Name] = $_.Value }
		
		[MoveDiskConfiguration]$returnConfig = [MoveDiskConfiguration]::new()
		$returnConfig.SubscriptionId = $configuration['SubscriptionId']
		$returnConfig.ResourceGroupName = $configuration['ResourceGroup']
		$returnConfig.DiskName = $configuration['DiskName']

		$returnConfig.DestinationSubscriptionId = $configuration['DestinationSubscriptionId']
		$returnConfig.DestinationResourceGroup = $configuration['DestinationResourceGroup']
        $returnConfig.DestinationRegion = $configuration['DestinationRegion']
        $returnConfig.InterimStorageAccount = $configuration['InterimStorageAccount']
        $returnConfig.InterimStorageKey = $configuration['InterimStorageKey']
    
		return $returnConfig
	}		
}