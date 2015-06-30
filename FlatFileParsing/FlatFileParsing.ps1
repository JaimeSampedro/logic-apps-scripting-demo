#Function - MakeDirectory
function CreateFTPDirectory{
    Param(
        $ftpHost
        ,$ftpUserName
        ,$ftpUserPasword
        ,$relativeFolderPath
    )
    Process
    {
        $newFolder = $ftpHost + "/" + $relativeFolderPath;
        $createFolder = [System.Net.WebRequest]::Create($newFolder);
        $createFolder.Credentials = New-Object System.Net.NetworkCredential($ftpUserName,$ftpUserPasword);
        $createFolder.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
        $createFolder.GetResponse();
    }
}

#region Init Parameters
$baseName = [guid]::NewGuid().Guid.Replace("-","")
$resourceGroupName = "flatfiledemo$baseName"
$resourceGroupLocation = "West US"
$serverName = $resourceGroupName + "sql"
$databaseName = "ordersdb"
$siteName = $resourceGroupName + "site"
$hostingPlanName = $resourceGroupName + "hp"
$sku = "Free"
$workerSize = "0"
$gatewayName = $baseName
$logicAppName = "flatfiledemo"
$sqlCredentail = Get-Credential -Message "Enter the user name and password for SQL database"
$sqlUserName = $sqlCredentail.UserName
$sqlPassword = $sqlCredentail.Password
$deploymentName = "FTPSQLDemoDeployment"
$ftpConnectorName = "ftpconnector"
$ftpRootFolder = "/demo/flatfile"

$templateFileLocation = "./templates/DeploySqlAndWebSite.json"
$apiAppsTemplateLocation = "./templates/DeployApiApp.json"
$inputLogicAppTemplateLocation = "./templates/DeployInputGenLogicApp.json"
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
$result = New-AzureResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -TemplateFile $templateFileLocation -DeploymentName $deploymentName -serverName $serverName -administratorLogin $sqlUserName -administratorPassword $sqlPassword -databaseName $databaseName -siteName $siteName -hostingPlanName $hostingPlanName -sku $sku -workerSize 0 -startIp "0.0.0.0" -endIp "0.0.0.0"
Write-Host "Successfully created SQL Azure database and Azure Website"
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

CreateFTPDirectory $ftpEndPoint $ftpUserName $ftpUserPasword "demo"
CreateFTPDirectory $ftpEndPoint $ftpUserName $ftpUserPasword "demo/flatfile"
CreateFTPDirectory $ftpEndPoint $ftpUserName $ftpUserPasword "demo/flatfile/in"

Write-Host "FTP Credentials are provided below"
Write-Host "FTP hostname: $ftpEndPoint"
Write-Host "FTP Username: $ftpUserName"
Write-Host "FTP UserPassword: $ftpUserPasword"
Write-Host "FTP root location for demo: $ftpRootFolder"

#Create a firewall rule 
New-AzureSqlServerFirewallRule -FirewallRuleName $firewallRuleName -StartIpAddress $startIpAddress -EndIpAddress $endIpAddress -ServerName $serverName -ResourceGroupName $resourceGroupName

#Create the API Apps and the Logic Apps required for the demo
$apiAppsTemplateResult = New-AzureResourceGroup -Name $resourceGroupName -Force -Location $resourceGroupLocation -TemplateFile $apiAppsTemplateLocation -hostingPlanName $hostingPlanName -sku $sku -gatewayName $gatewayName -logicAppName $logicAppName -ftpServerAddress $ftpPubProfile.PublishUrl.Replace("/site/wwwroot","").Replace("ftp://","") -ftpUserName $ftpUserName -ftpPassword $ftpUserPasword -sqlServerName $serverinstance -sqlUserName $sqlUserName -sqlPassword $sqlCredentail.GetNetworkCredential().Password -sqlDatabase $databaseName -sqlTables $sqlTable
Write-Host "Successfully created API Apps and Logic Apps"

$transformFileName = ".\setup\SchemasAndMaps\FlatFileOrderMap.trfm"
$schemaFileName = ".\setup\SchemasAndMaps\FlatFileOrder.xsd"
$transformContent = Get-Content $transformFileName | Out-String
$currentLocation = Get-Location
$customDllLocation =  Join-Path $currentLocation "setup\Assembly\Newtonsoft.Json.dll"
[Reflection.Assembly]::LoadFile($customDllLocation)
$jsonTransformContent = "{ `"mapContent`" : " + [Newtonsoft.Json.JsonConvert]::ToString($transformContent) + "}"
$mapContentFileName = ".\setup\SchemasAndMaps\FlatFileOrderMapContent.json"
$jsonTransformContent | Out-File $mapContentFileName
$subscriptionId = (Get-AzureSubscription -Current).SubscriptionId
$flatfileSchemaName = "IncomingOrder.xsd"
$flatfileSchemaFriendlyName = "IncomingOrder"
$mapContentFileName = ".\setup\SchemasAndMaps\FlatFileOrderMapContent.json"
$jsonTransformContent | Out-File $mapContentFileName

$flatFileEncoderName = "FlatFileEncoder"
$transformConnectorName = "TransformService"
$transformName = "Orders"
$schemaUpload = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$flatFileEncoderName$gatewayName/extensions/$flatFileEncoderName/api/Schema/$flatfileSchemaName/$flatfileSchemaFriendlyName" + "?api-version=1.1"
$transformUpload = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$transformConnectorName$gatewayName/extensions/$transformConnectorName/api/Map/$transformName" + "?api-version=1.1"
ARMClient.exe POST $schemaUpload `@$schemaFileName
Write-Host "Successfully uploaded schema"
ARMClient.exe put $transformUpload `@$mapContentFileName
Write-Host "Successfully uploaded map"

#Create logic app that generates input data
$apiAppsTemplateResult = New-AzureResourceGroup -Name $resourceGroupName -Force -Location $resourceGroupLocation -TemplateFile $inputLogicAppTemplateLocation -hostingPlanName $hostingPlanName -sku $sku -gatewayName $gatewayName -logicAppName $logicAppName
Write-Host "Successfully created logic app that generates input data"

#Create the database objects required for the demo
Invoke-Sqlcmd -ServerInstance $serverinstance -Database $databaseName -Username $sqlUserName -Password $sqlCredentail.GetNetworkCredential().Password -InputFile $sqlScriptLocation
Write-Host "Script execution completed."


}
else
{
    Write-Host "Error in creating the demo deployment"
}
#endregion