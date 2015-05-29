#Flat file parsing demo in Logic Apps

##Overview
This script helps you setup and get started to try out a simple flat file parsing demo in Logic Apps. To know more about logic apps, click [here][1]

##Flat file parsing scenario

![Flat file parsing demo scenario][2]

As part of the demo, the logic app will pick files from a FTP share, transform its data and then create a new record in SQL Azure database.

##Understanding what the script does
The demo script not only creates the API Apps involved in the flow, but it also creates and configures FTP as well as SQL Azure end points.

The script makes use of Azure Resource Manager templates and does the following

- External dependencies
	- Creates an Azure Website which can be used as a FTP server in the demo
	- Creates a SQL Azure database
	- Creates a SQL table that can be used for the demo
- Provisions API Apps
	- Creates a FTP Connector and configures it with the FTP information from the website created above
	- Creates a Microsoft SQL Connector and configures it with the SQL database information from the database created above
	- Creates a BizTalk Flat File Encoder API App
	- Creates a BizTalk Transforms Service API App
		
			Note: FTP and SQL connector API apps are both provisioned and configured, so that you dont have to spend time and configure the settings manually
- Logic App
	- Creates an empty logic app where you can compose the end-end flow
	- Creates a feeder logic app which auto populates the FTP share with input data 

			Note: Feeder logic app is created as past of the script so that you dont have to create input data manually

##Pre-requisites

- Azure subscription - If you dont already have one, you can sign up for a free trial [here][3]
- [Azure Powershell][4]
- Powershell tools from [SQL Server 2014 feature pack][5]

##Things to note before getting started
The script and template code is available in github. This is intended for demo use only. Be aware of the SKU usage in the script and template as it might impact your Azure Billing.

##Get started
- Download the zip file, clone or fork the [logic-apps-scripting-demo][6] github repository.
- Navigate to */FlatFileParsing* subfolder in your powershell
- *FlatFileParsing.ps1* contains the script which sets up the demo resources
		
		Note: Modify the parameters like resource group name, database name, etc. to match your requirements, or leave it as default
- Before executing the script, make sure
	- You have added an azure account in powershell through `Add-AzureAccount` if you haven't done it already
	- Switch the Azure context to use the new Azure Resource Manager
		
		`Switch-AzureMode AzureResourceManager`
- Execute the *FlatFileParsing.ps1* script
- As soon as the script starts execution, it will prompt for username and password for SQL database. This is the sql credential that will be used while creating the SQL Azure database

	![SQL credential prompt][7]
- Once the script is executed, you are all set to compose the end-end flow

	![Script completion][8]

		Note: The details about the FTP folder are provided in the 
- Launch [Azure Portal][9]
- Browse to the resource group created as part of the script
	
		Note: If you havent made any changes to the script, the default resource group name is flatfiledemo. Resource group name is also displayed as part of the script execution's output.
- Notice that all the resources are already created as part of the flow, including a website and a SQL Azure database

	![Demo Resource Group][10]

Lets take a look at the API Apps

###Microsoft SQL Connector
- Click on *microsoftsqlconnector* API App and then click on *API definition*

	![SQL Connector API definition][11]
- The SQL connector is already configured to use the table created as part of the script!

###FTP Connector
- Close the SQL Connector. Click on *ftpconnector* and then click on *API definition*
	
	![FTP Connector API Definition][12]
- FTP connector is already configured and ready to use!

###Flat File Encoder
- Close the FTP connector. Click on *FlatFileEncoder* API App and then click on *Schemas*
- Click on *Add New* option from the command bar at the top
- You can upload an existing schema, generate a schema from a json instance or a flat file instance. In this case, we are going to upload a schema.
- Choose upload schema. Browse to the folder where the script is located.
- Schema is located in the following sub folder path
	`Setup\SchemasAndMaps`

	![Upload schema][13]
- Select the schema `FlatFileOrder`, change the Name of the schema to *FlatFileOrder* instead of the default *schema1* and upload it

	![Schema uploaded][14]
- Once the schema is uploaded, it shows up in the schema blade.

###Transform Service
- Close the Flat File Encoder. Click on *TransformsService* and then click on *Maps*
- Click on *Add* option from the command bar at the top
- You can upload an existing map from the file system.
- Click on file. Browse to the folder where the script is located
- Map is located in the following sub folde rpath
	`Setup\SchemasAndMaps`

	![Upload transform][15]
- Select the map *FlatFileOrderMap* and then click *Ok* to upload it.

	![Transform uploaded][16]
- Once the map is uploaded, it shows up in the maps blade.

###OrdersDb

Notice that a SQL Azure database named *OrdersDB* is already created as part of the resource group. Firewall rule is also set and you can open it up from a local Visual Studio instance or a SQL Server Management Studio!

###FTP Server
The FTP credentials are provided as part of the script's output. You can use any FTP client to log into the server. By default, the file pick up location is */demo/flatfile*.

Create the following folders in the root directory of the FTP server
-demo
-demo/flatfile
-demo/flatfile/in

![FTP folder structure][17]

Note: The feeder logic app depends on this folder structure to be present, and will keep failing until then.

##Compose the flow
- Click on *flatfiledemo* logic app
- Click on *Triggers and actions*
- An empty logic app designer shows up

![Flat File Demo Logic App][18]
- Note that the API Apps that are required for the demo show up in the right hand pane automatically. You can find it under *In flatfiledemo resource group*
- Compose the flow structure by clicking on
	- FTP Connector (this will make it a trigger)
	- BizTalk Flat File Encoder
	- BizTalk Transforms Service
	- Microsoft SQL Connector

![Unconfigured Flow][19]

###FTP Connector
- Choose *File Available(Read then Delete)* as trigger
- Set the frequency to one minute
- In the folder path, input *in*
- Click on the tick mark

###BizTalk Flat File Encoder
- Click on the tick mark
- Choose *Flat file to Xml* action
- Set the following input values
	- Flat file - Content of the FTP connector
	- Schema Name - *FlatFileOrder*
	- Root Name - *Order*
		Note: Schema and Root name reflect the details of the flat file schema that was uploaded earlier.
- Click on the tick mark

###BizTalk Transform Service
- Click on the tick mark
- Choose *Transform* action
- Set the Input Xml to the output of flat file encoder

###Microsoft SQL Connector
- Click on ... in the list of actions
- Click on *Insert into Orders (XML)*
- Set the input xml to the output of transforms

Click on Save. The flow is now configured end-end

##Test the flow
- Click on *flatfiledemoinputgeneration* logic app in the resource group blade
- Click on *Triggers and action*
- Note that the frequency of the recurrence is set to 1 minute.
- Close the designer
- After a minute and every minute then a new test file will be placed in the FTP share. You can check if those runs were successful by checking the *Operations* part of the logic app blade

![InputData generation][21]

- This will in turn trigger the demo flow
- The demo flow will pick up the flat file, parse it and then place a new record in the SQL database. Its run can be tracked as part of the *Operation* part too.

![Demo Flow Successful][22]


**Note**: The flows are intended for demo purposes only. Once the flow is verified, change the trigger frequency to an hour or a day to stop sending messages every minute to SQL Azure database.

Hopefully this helped you in getting started with logic apps and some of the BizTalk API Apps.

<!-- References -->
[1]: https://azure.microsoft.com/en-gb/documentation/articles/app-service-logic-what-are-logic-apps/
[2]: ./images/FlatFileParsingDemoScenario.PNG
[3]: https://azure.microsoft.com/en-gb/pricing/free-trial/
[4]: https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
[5]: https://www.microsoft.com/en-us/download/details.aspx?id=42295
[6]: https://github.com/rajeshramabathiran/logic-apps-scripting-demo/
[7]: ./images/SQLCredentialPrompt.PNG
[8]: ./images/ScriptCompleted.PNG
[9]: http://portal.azure.com
[10]: ./images/DemoResourceGroup.PNG
[11]: ./images/SQLConnectorAPIDefinition.PNG
[12]: ./images/FTPConnectorAPIDefinition.PNG
[13]: ./images/UploadSchema.PNG
[14]: ./images/SchemaUploaded.PNG
[15]: ./images/UploadTransform.PNG
[16]: ./images/TransformUploaded.PNG
[17]: ./images/FTPFolderStructure.PNG
[18]: ./images/flatfiledemoLogicApp.PNG
[19]: ./images/flatfiledemoLogicAppFlowUnconfigured.PNG
[20]: ./images/flatfiledemoLogicAppFlowConfigured.PNG
[21]: ./images/flatfiledemoLogicAppFlowInputDataGeneration.PNG
[22]: ./images/flatfiledemoLogicAppFlowDemoFlowSuccessful.PNG
[23]: ./images/flatfiledemoLogicAppFlowSQLEntries.PNG
