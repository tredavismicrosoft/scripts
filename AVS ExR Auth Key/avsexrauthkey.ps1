# Author: Trevor Davis
# Twitter: @vTrevorDavis


# Powershell 7 Is Required

# This script will ask the user to create a new virtual network or use an existing virtual network.  If new, will use the resource group define when creating the private cloud.

########## TESTING DELETE  #######################################

$sub = "3988f2d0-8066-42fa-84f2-5d72f80901da"
# Connect-AzAccount -Subscription $sub
$rgfordeployment = "Script"
$regionfordeployment = "australiaeast"
$pcname = "script"


########## Connect To Azure  #######################################

Clear-Host
# $sub = Read-Host -Prompt "What is the Subscription ID where the Private Cloud exists?"
# Connect-AzAccount -Subscription $sub

########## Define how the ExR Gateway will be accessed / create #################
Clear-Host
$vnetandexr = Read-Host -Prompt "Do you want to use an existing Azure virtual network for the ExpressRoute gateway, create a new Azure virtual network for the ExpressRoute gateway or do you already have an ExpressRoute Gateway you want to use?

1 = Create a New Azure Virtual Network and ExpressRoute Gateway
2 = Use an existing Azure Virtual Network and Create an ExpressRoute Gateway
3 = Use an existing ExpressRoute Gateway

Enter Your Reponse (1, 2 or 3)"

########## Option 1 Create a New Azure Virtual Network and ExpressRoute Gateway #################################

if ("1" -eq $vnetandexr) {

   $vnetname = Read-Host -Prompt "Provide a name for the Virtual network?"
   $vnetaddressprefix = Read-Host -Prompt "What is the address prefix for the Virtual network? (example 10.1.0.0/16)"
   
   $defaultsubnetprefix = Read-Host -Prompt "Define the default subnet for the virtual network? (example 10.1.1.0/24)"
   $defaultsubnetname = "default"
   
   $gwsubnetprefix = Read-Host -Prompt "Define the subnet to be used for the ExpressRoute Gateway (example 10.1.2.0/24)"
   $gwname = Read-Host -Prompt "Provide a name for the ExpressRoute gateway"
   $gwipName = "$gwname-ip"
   $gwipconfName = "$gwname-ipconf"
   $gatewaysubnetname = "GatewaySubnet"
   
   # CREATES THE VNET AND DEFAULT SUBNET  ################################
   
   New-AzVirtualNetwork -ResourceGroupName $rgfordeployment -Location $regionfordeployment -Name $vnetname -AddressPrefix $vnetaddressprefix 
   # $avsgatewaysubnetconfig = New-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -AddressPrefix $gwsubnetprefix
   New-AzVirtualNetworkSubnetConfig -Name $defaultsubnetname -AddressPrefix $defaultsubnetprefix
   $avsvnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgfordeployment
   # $avsgatewaysubnet = Add-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -VirtualNetwork $avsvnet -AddressPrefix $gwsubnetprefix
  Add-AzVirtualNetworkSubnetConfig -Name $defaultsubnetname -VirtualNetwork $avsvnet -AddressPrefix $defaultsubnetprefix
   $avsvnet | Set-AzVirtualNetwork
   
   # CREATES THE GATEWAY SUBNET AND EXR GATEWAY ################################
   
   $vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgfordeployment
   Add-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -VirtualNetwork $vnet -AddressPrefix $gwsubnetprefix
   $vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet
   $subnet = Get-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -VirtualNetwork $vnet
   $pip = New-AzPublicIpAddress -Name $gwipName  -ResourceGroupName $rgfordeployment -Location $regionfordeployment -AllocationMethod Dynamic
   $ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $gwipconfName -Subnet $subnet -PublicIpAddress $pip
   $deploymentkickofftime = get-date -format "hh:mm"
   
   New-AzVirtualNetworkGateway -Name $gwname -ResourceGroupName $rgfordeployment -Location $regionfordeployment -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob

   clear-host

   Write-Host -foregroundcolor Magenta "
   The Virtal Network Gateway $gwname deployment is underway and will take approximately 30 minutes
   
   The start time of the deployment was $deploymentkickofftime
   
   The status of the deployment will update every 2 minutes ... please wait ... 
   "
   
   Start-Sleep -Seconds 120
   
   # Checks Deployment Status ################################
   
   # $provisioningstate = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment
   # $currentprovisioningstate = $provisioningstate.ProvisioningState
   $currentprovisioningstate = "Started"
   $timeStamp = Get-Date -Format "hh:mm"
   
   while ("Succeeded" -ne $currentprovisioningstate)
   {
      $timeStamp = Get-Date -Format "hh:mm"
      "$timestamp - Current Status: $currentprovisioningstate "
      Start-Sleep -Seconds 120
      $provisioningstate = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment
      $currentprovisioningstate = $provisioningstate.ProvisioningState
   } 
   
   if ("Succeeded" -eq $currentprovisioningstate)
   {
   Write-host -ForegroundColor Green "$timestamp - Current Status: $currentprovisioningstate"
   
   $exrgwtouse = $gwname

  # Connects AVS to vNet ExR GW ################################

$myprivatecloud = Get-AzVMWarePrivateCloud -Name $pcname -ResourceGroupName $rgfordeployment
$peerid = $myprivatecloud.CircuitExpressRouteId
$pcname = $myprivatecloud.name 
Write-Host = "
Please Wait ... Generating Authorization Key"
$exrauthkey = New-AzVMWareAuthorization -Name "$pcname-authkey" -PrivateCloudName $pcname -ResourceGroupName $rgfordeployment 
$exrgwtouse = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment -Name $exrgwtouse
Write-Host = "
Please Wait ... Connecting Azure VMware Solution Private Cloud $pcname to Azure Virtual Network Gateway "$exrgwtouse.name" ... this may take a few minutes."
New-AzVirtualNetworkGatewayConnection -Name "$pcname-AVS-ExR-Connection" -ResourceGroupName $rgfordeployment -Location $regionfordeployment -VirtualNetworkGateway1 $exrgwtouse -PeerId $peerid -ConnectionType ExpressRoute -AuthorizationKey $exrauthkey.Key
 
# Checks Deployment Status ################################

$provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
$currentprovisioningstate = $provisioningstate.ProvisioningState
$timeStamp = Get-Date -Format "hh:mm"

while ("Succeeded" -ne $currentprovisioningstate)
{
  $timeStamp = Get-Date -Format "hh:mm"
  "$timestamp - Current Status: $currentprovisioningstate "
  Start-Sleep -Seconds 20
  $provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
  $currentprovisioningstate = $provisioningstate.ProvisioningState
} 

if ("Succeeded" -eq $currentprovisioningstate)
{
Write-host -ForegroundColor Green "
Success"

}
   
   }
}
########## Option 2 Use an existing Azure Virtual Network and Create an ExpressRoute Gateway ##################

if ("2" -eq $vnetandexr) {

# Define vNet  #######################################

Clear-Host

$VNETs = Get-AzVirtualNetwork
$Count = 0

foreach ($vnet in $VNETs) {
   $VNETname = $vnet.Name
   Write-Host "$Count - $VNETname"
   $Count++
}

$vnetselection = Read-Host -Prompt "
Select the number which corresponds to the Virtual Network where the Virtual Network Gateway for the Azure VMware Solution Private Cloud Express Route will be deployed"
$vnettouse = $VNETs["$vnetselection"].Name

# CREATES THE GATEWAY SUBNET AND EXR GATEWAY ################################
 
$gwsubnetprefix = Read-Host -Prompt "Define the subnet to be used for the ExpressRoute Gateway (example 10.1.2.0/24)"
$gwname = Read-Host -Prompt "Provide a name for the ExpressRoute gateway"
$gwipName = "$gwname-ip"
$gwipconfName = "$gwname-ipconf"
$gatewaysubnetname = "GatewaySubnet"

$vnet = Get-AzVirtualNetwork -Name $vnettouse -ResourceGroupName $rgfordeployment
Add-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -VirtualNetwork $vnet -AddressPrefix $gwsubnetprefix
$vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $gatewaysubnetname -VirtualNetwork $vnet
$pip = New-AzPublicIpAddress -Name $gwipName  -ResourceGroupName $rgfordeployment -Location $regionfordeployment -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $gwipconfName -Subnet $subnet -PublicIpAddress $pip
$deploymentkickofftime = get-date -format "hh:mm"

New-AzVirtualNetworkGateway -Name $gwname -ResourceGroupName $rgfordeployment -Location $regionfordeployment -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard -AsJob

clear-host

Write-Host -foregroundcolor Magenta "
The Virtal Network Gateway $gwname deployment is underway and will take approximately 30 minutes

The start time of the deployment was $deploymentkickofftime

The status of the deployment will update every 2 minutes ... please wait ... 
"

Start-Sleep -Seconds 120

# Checks Deployment Status ################################

$provisioningstate = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment
$currentprovisioningstate = $provisioningstate.ProvisioningState
$timeStamp = Get-Date -Format "hh:mm"

while ("Succeeded" -ne $currentprovisioningstate)
{
  $timeStamp = Get-Date -Format "hh:mm"
  "$timestamp - Current Status: $currentprovisioningstate "
  Start-Sleep -Seconds 120
  $provisioningstate = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment
  $currentprovisioningstate = $provisioningstate.ProvisioningState
} 

if ("Succeeded" -eq $currentprovisioningstate)
{
Write-host -ForegroundColor Green "$timestamp - Current Status: $currentprovisioningstate"


$exrgwtouse = $gwname

# Connects AVS to vNet ExR GW ################################

$myprivatecloud = Get-AzVMWarePrivateCloud -Name $pcname -ResourceGroupName $rgfordeployment
$peerid = $myprivatecloud.CircuitExpressRouteId
$pcname = $myprivatecloud.name 
Write-Host = "
Please Wait ... Generating Authorization Key"
$exrauthkey = New-AzVMWareAuthorization -Name "$pcname-authkey" -PrivateCloudName $pcname -ResourceGroupName $rgfordeployment 
$exrgwtouse = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment -Name $exrgwtouse
Write-Host = "
Please Wait ... Connecting Azure VMware Solution Private Cloud $pcname to Azure Virtual Network Gateway "$exrgwtouse.name" ... this may take a few minutes."
New-AzVirtualNetworkGatewayConnection -Name "$pcname-AVS-ExR-Connection" -ResourceGroupName $rgfordeployment -Location $regionfordeployment -VirtualNetworkGateway1 $exrgwtouse -PeerId $peerid -ConnectionType ExpressRoute -AuthorizationKey $exrauthkey.Key
 
# Checks Deployment Status ################################

$provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
$currentprovisioningstate = $provisioningstate.ProvisioningState
$timeStamp = Get-Date -Format "hh:mm"

while ("Succeeded" -ne $currentprovisioningstate)
{
  $timeStamp = Get-Date -Format "hh:mm"
  "$timestamp - Current Status: $currentprovisioningstate "
  Start-Sleep -Seconds 20
  $provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
  $currentprovisioningstate = $provisioningstate.ProvisioningState
} 

if ("Succeeded" -eq $currentprovisioningstate)
{
Write-host -ForegroundColor Green "
Success"

}
}
}

########## Option 3 Use an existing ExpressRoute Gateway ################

    if ("3" -eq $vnetandexr) {

# Pick the ExR Gateway to use ###############################

    $exrgws = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment
    $Count = 0
    
     foreach ($exrgw in $exrgws) {
        $exrgwlist = $exrgw.Name
        Write-Host "
        $Count - $exrgwlist"
        $Count++
     }
     
    $exrgwselection = Read-Host -Prompt "
Select the number which corresponds to the ExpressRoute Gateway which will be use to connect your Azure VMware Solution ExpressRoute to"
    $exrgwtouse = $exrgws["$exrgwselection"].Name

# Connects AVS to vNet ExR GW ################################

    $myprivatecloud = Get-AzVMWarePrivateCloud -Name $pcname -ResourceGroupName $rgfordeployment
$peerid = $myprivatecloud.CircuitExpressRouteId
$pcname = $myprivatecloud.name 
Write-Host = "
Please Wait ... Generating Authorization Key"
$exrauthkey = New-AzVMWareAuthorization -Name "$pcname-authkey" -PrivateCloudName $pcname -ResourceGroupName $rgfordeployment 
$exrgwtouse = Get-AzVirtualNetworkGateway -ResourceGroupName $rgfordeployment -Name $exrgwtouse
Write-Host = "
Please Wait ... Connecting Azure VMware Solution Private Cloud $pcname to Azure Virtual Network Gateway "$exrgwtouse.name" ... this may take a few minutes."
New-AzVirtualNetworkGatewayConnection -Name "$pcname-AVS-ExR-Connection" -ResourceGroupName $rgfordeployment -Location $regionfordeployment -VirtualNetworkGateway1 $exrgwtouse -PeerId $peerid -ConnectionType ExpressRoute -AuthorizationKey $exrauthkey.Key
 
# Checks Deployment Status ################################

$provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
$currentprovisioningstate = $provisioningstate.ProvisioningState
$timeStamp = Get-Date -Format "hh:mm"

while ("Succeeded" -ne $currentprovisioningstate)
{
  $timeStamp = Get-Date -Format "hh:mm"
  "$timestamp - Current Status: $currentprovisioningstate "
  Start-Sleep -Seconds 20
  $provisioningstate = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgfordeployment
  $currentprovisioningstate = $provisioningstate.ProvisioningState
} 

if ("Succeeded" -eq $currentprovisioningstate)
{
Write-host -ForegroundColor Green "
Success"

}
    }


        