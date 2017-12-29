# Application Gateway Monitoring Dashboard

More info in blog: <https://blogs.technet.microsoft.com/robdavies/2017/12/29/monitoring-application-gateway-with-azure-log-analytics/>

**PLEASE NOTE:** You must deploy this ARM template to the _Resource Group_ in which your Azure Log Analytics (OMS) workspace is located.

## Deploy Dashboard via Portal
Click the button!

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fiamrobdavies%2FMonitoringExamples%2Fmaster%2FApplicationGateway%2FDashboard%2FAppGWDashboard.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

## Deploy Dashboard via CLI
```
az group deployment create -g LogAnalyticsResourceGroupName --template-file AppGWDashboard.json --parameters '{"logAnalyticsWorkspaceName": {"value":"LogAnalyticsWorkspaceName"},"logAnalyticsWorkspaceResourceGroup":{"value":"LogAnalyticsResourceGroupName"}}' --verbose
```

## Deploy Dashboard via PowerShell
```
New-AzureRmResourceGroupDeployment -ResourceGroupName 'LogAnalyticsResourceGroupName' -TemplateFile .\AppGWDashboard.json -logAnalyticsWorkspaceName 'LogAnalyticsWorkspaceName' -logAnalyticsWorkspaceResourceGroup 'LogAnalyticsResourceGroupName' -Verbose
```

# Deploy Application Gateway with Diagnostic Logging Enabled

The file **AppGwWithDiagnosticsEnabled.json** is an example ARM template to deploy an Azure Applicaiton Gateway.

Using the APIs in *Microsoft.Insights/service*, the Application Gateway is created with the ApplicationGatewayAccessLog and ApplicationGatewayPerformanceLog diagnostic logs enabled.

The file **AppGwWithDiagnosticsEnabled.param.json** is an example of a parameter file, which can be used to deploy AppGwWithDiagnosticsEnabled.json sucessfully.


More info about Application Gateway Diagnostic Logging here: <https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-diagnostics>
