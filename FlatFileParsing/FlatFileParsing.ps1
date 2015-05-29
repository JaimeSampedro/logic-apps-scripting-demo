#region Init Parameters
$resourceGroupName = "flatfiledemo"
$resourceGroupLocation = "West US"
$serverName = "flatfiledemosql"
$databaseName = "ordersdb"
$siteName = "flatfiledemo"
$hostingPlanName = "flatfiledemohp"
$sku = "Standard"
$workerSize = "0"
$gatewayName = "flatfiledemogateway"
$logicAppName = "flatfiledemo"
$sqlCredentail = Get-Credential -Message "Enter the user name and password for SQL database"
$sqlUserName = $sqlCredentail.UserName
$sqlPassword = $sqlCredentail.Password
$deploymentName = "FTPSQLDemoDeployment"
$ftpConnectorName = "ftpconnector"
$ftpRootFolder = "/demo/flatfile"

$templateFileLocation = "./templates/DeploySqlAndWebSite.json"
$apiAppsTemplateLocation = "./templates/DeployApiApp.json"
$sqlScriptLocation = "./setup/sqlscript/dbo.Orders.sql"

#Set the IP Address of the machine from which you are executing the script
$startIpAddress = "0.0.0.0"
$endIpAddress = "255.255.255.255"
$firewallRuleName = "CurrentIpRange"

$serverinstance = "$serverName.database.windows.net"
$sqlTable = "Orders"
#endregion

#region SQL+WebSite
#Deploy an instance of SQL Azure database and a website. This website will be used as a FTP server in the demo. 
$result = New-AzureResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -TemplateFile $templateFileLocation -DeploymentName $deploymentName -serverName $serverName -administratorLogin $sqlUserName -administratorPassword $sqlPassword -databaseName $databaseName -siteName $siteName -hostingPlanName $hostingPlanName -sku Standard -workerSize 0 -startIp "0.0.0.0" -endIp "0.0.0.0"
#endregion

#region API Apps + Logic Apps
if($result.ProvisioningState -eq "Succeeded")
{

#Obtain the FTP credentials from the website created from previous step execution
$pubprofile = Get-AzureWebAppPublishingProfile -ResourceGroupName $resourceGroupName -Name $siteName | Select-Object {$_.PublishProfiles}
$ftpPubProfile = $pubprofile.'$_.PublishProfiles' | Where-Object {$_.PublishMethod -eq "FTP"}
$ftpUserName = $ftpPubProfile.UserName
$ftpUserPasword = $ftpPubProfile.UserPassword
$ftpEndPoint = $ftpPubProfile.PublishUrl.Replace("/site/wwwroot","")

#Create a firewall rule 
New-AzureSqlServerFirewallRule -FirewallRuleName $firewallRuleName -StartIpAddress $startIpAddress -EndIpAddress $endIpAddress -ServerName $serverName -ResourceGroupName $resourceGroupName

#Create the API Apps and the Logic Apps required for the demo
$apiAppsTemplateResult = New-AzureResourceGroup -Name $resourceGroupName -Force -Location $resourceGroupLocation -TemplateFile $apiAppsTemplateLocation -hostingPlanName $hostingPlanName -sku Standard -gatewayName $gatewayName -logicAppName $logicAppName -ftpServerAddress $ftpPubProfile.PublishUrl.Replace("/site/wwwroot","").Replace("ftp://","") -ftpUserName $ftpUserName -ftpPassword $ftpUserPasword -sqlServerName $serverinstance -sqlUserName $sqlUserName -sqlPassword $sqlCredentail.GetNetworkCredential().Password -sqlDatabase $databaseName -sqlTables $sqlTable

#Create the database objects required for the demo
Invoke-Sqlcmd -ServerInstance $serverinstance -Database $databaseName -Username $sqlUserName -Password $sqlCredentail.GetNetworkCredential().Password -InputFile $sqlScriptLocation

Write-Host "FTP Credentials are provided below"
Write-Host "FTP hostname: $ftpEndPoint"
Write-Host "FTP Username: $ftpUserName"
Write-Host "FTP UserPassword: $ftpUserPasword"
Write-Host "FTP root location for demo: $ftpRootFolder"
}
else
{
    Write-Host "Error in creating the demo deployment"
}
#endregion