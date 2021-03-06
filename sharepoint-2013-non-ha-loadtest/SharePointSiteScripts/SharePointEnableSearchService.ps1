# Based on script at http://www.toddklindt.com/blog/Lists/Posts/Post.aspx?ID=378
param(
	[String] $searchServiceAppPoolName = "Search Service Pool",
	[String] $searchAppName = "SearchServApp",
	[String] $searchDBName = "Search_Serv_DB"	
)

Add-PSSnapin Microsoft.SharePoint.PowerShell
Import-Module LogToFile

# Create App Pool
LogToFile -Message "Creating the application pool for the search service"
$managedAccount = Get-SPManagedAccount | Select-Object -First 1
$searchServiceAppPool = Get-SPServiceApplicationPool -Identity $searchServiceAppPoolName -ErrorAction SilentlyContinue
if(-not($searchServiceAppPool))
{
	$searchServiceAppPool = New-SPServiceApplicationPool -Name $searchServiceAppPoolName -Account $managedAccount
}
LogToFile -Message "Done creating the application pool"

# Start services
LogToFile -Message "Starting the search service instance"
$searchServInstance = Get-SPEnterpriseSearchServiceInstance
if ($searchServInstance.Status -eq "Disabled")
{
	Start-SPEnterpriseSearchServiceInstance -Identity $searchServInstance
	if (-not($?))
	{ 
		LogToFile -Message "ERROR:Enterprise search service instance failed to start"
		throw [System.Exception] "Enterprise search service instance failed to start" 
	}
}
$retryCount = 0
while (-not($searchServInstance.Status -eq "Online"))
{
	if($retryCount -ge 60)
	{
		LogToFile -Message "ERROR:Starting search service has timed out"
		throw [System.Exception] "Starting search service has timed out" 
	}
	$searchServInstance = Get-SPEnterpriseSearchServiceInstance
	Start-Sleep -Seconds 5
	$retryCount++
}
LogToFile -Message "Search service has started"

LogToFile -Message "Starting the search query and sites settings service"
$searchQuerySettingsServInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $searchServInstance.Server.Name
if ($searchQuerySettingsServInstance.Status -eq "Disabled")
{
	Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $searchServInstance.Server.Name
	if (-not($?))
	{ 
		LogToFile -Message "ERROR:Enterprise search query and site settings service instance failed to start"
		throw [System.Exception] "Enterprise search query and site settings service instance failed to start" 
	}
}
$retryCount = 0
while (-not($searchQuerySettingsServInstance.Status -eq "Online"))
{
	if($retryCount -ge 60)
	{
		LogToFile -Message "ERROR:Starting search query and site settings service has timed out"
		throw [System.Exception] "Starting search query and site settings service has timed out" 
	}
	$searchQuerySettingsServInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $searchServInstance.Server.Name
	Start-Sleep -Seconds 5
	$retryCount++
}
LogToFile -Message "Search query and site settings service has started"

# create application and proxy
LogToFile -Message "Creating the service application for the search service"
$searchServiceApp = Get-SPEnterpriseSearchServiceApplication -Identity $searchAppName -ErrorAction SilentlyContinue
if(-not($searchServiceApp))
{
	$searchServiceApp = New-SPEnterpriseSearchServiceApplication -Name $searchAppName -ApplicationPool $searchServiceAppPool -DatabaseName $searchDBName
	New-SPEnterpriseSearchServiceApplicationProxy -Name "$($searchAppName) Proxy" -SearchApplication $searchServiceApp
	# set the topology
	$defaultTopology = $searchserviceApp.ActiveTopology.Clone()
	$searchServInstance = Get-SPEnterpriseSearchServiceInstance
	New-SPEnterpriseSearchAdminComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	New-SPEnterpriseSearchCrawlComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	New-SPEnterpriseSearchIndexComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $defaultTopology -SearchServiceInstance $searchServInstance
	$defaultTopology.Activate()
}
LogToFile -Message "Done creating the service application"
