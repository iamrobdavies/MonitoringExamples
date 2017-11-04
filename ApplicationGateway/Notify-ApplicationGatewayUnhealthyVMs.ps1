param([object]$WebhookData)

#====================START OF CONNECTION SETUP======================
$Conn = Get-AutomationConnection -Name "AzureRunAsConnection"
Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
-ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
Get-AzureRmSubscription
#====================END OF CONNECTION SETUP=======================

$convertedRequestBody = ConvertFrom-Json -InputObject $webhookData.RequestBody
$actionWebhookURI = Get-AutomationVariable -Name 'SendAppGatewayAlertEmailWebhook'

foreach($resultRow in $convertedRequestBody.SearchResult.tables.rows){
    #parse out the appGW & Resource Group from alert results
    $appGWName = $resultRow[0]
    $appGWRG = $resultRow[1]
    Write-Output "AppGW is: $($appGWName) and RG is: $($appGWRG)"

    #get the backend health status for the impacted app gw
    $backendHealth = Get-AzureRmApplicationGatewayBackendHealth -Name $appGWName -ResourceGroupName $appGWRG
    
    #Loop through all of the backend pools to look for unhealthy VMs
    foreach($backendPool in $backendHealth.BackendAddressPools){
        $vmList = @()
        
        #Display name of the pool is last part of the ID
        $poolName = ($backendPool.backendaddresspool.id).Split("/")
        $poolName = $($poolName[$poolName.Length-1])
        Write-output "Pool Name: $($poolName)"

        foreach ($backendRefState in $backendPool.BackendHttpSettingsCollection.Servers){
            if($backendRefState.Health -ne "Healthy"){
                $nic = $null

                #VM added by NIC reference:
                if ($backendRefState.IpConfiguration -ne $null){
                    #parse out the NIC name and resource group from the long form ID
                    #Doing this because doesnt accept Resource ID as a param
                    $nicRGName = ($backendRefState.IpConfiguration.Id).split("/")[4]
                    $nicName = ($backendRefState.IpConfiguration.Id).split("/")[8]

                    $nic = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $nicRGName
                    if($nic -ne $null){
                        $vmref = Get-AzureRmResource -ResourceId $nic.VirtualMachine.Id
                        $vm = Get-AzureRmVM -ResourceGroupName $vmref.ResourceGroupName -Name $vmref.Name
                        Write-output "Unhealthy VM Name: $($vm.Name) in RG: $($vm.ResourceGroupName)"
                        $vmList += $vm
                    }
                #VM added by IP Address:
                } else {
                    #Find which NIC the IP address is attached to
                    #Potential issue: if there are multiple VNets in the Subscription with the same address space, this could return >1 NIC
                    $nic = Get-AzureRmNetworkInterface | ?{$_.IpConfigurations.PrivateIpAddress -eq $backendRefState.Address}
                    if($nic -ne $null){
                        $vmref = Get-AzureRmResource -ResourceId $nic.VirtualMachine.Id
                        $vm = Get-AzureRmVM -ResourceGroupName $vmref.ResourceGroupName -Name $vmref.Name
                        Write-output "Unhealthy VM Name: $($vm.Name) in RG: $($vm.ResourceGroupName)"
                        $vmList += $vm
                    }
                }
            }
        }       
        #add captured data to a json formatted list
        $listForWebHook = @{ApplicationGatewayName = $appGWName; 
                ApplicationGatewayResourceGroup = $appGWRG;
                BackendPoolName = $poolName;
                vms = @($vmList | select Name, ResourceGroupName)}    
        $listForWebHookjson = $listForWebHook | ConvertTo-Json

        #trigger webhook
        Invoke-RestMethod -Method Post -Uri $actionWebhookURI -Body $listForWebHookjson -ContentType 'application/json'
    }
}
