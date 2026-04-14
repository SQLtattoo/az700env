targetScope = 'resourceGroup'

@description('Location for hub vnet resources')
param hubLocation string = 'ukSouth'

@description('Location for spoke1 vnet resources')
param spoke1Location string = 'ukSouth'

@description('Location for spoke2 vnet resources (cross-region spoke — enter a different region from hub, e.g. northeurope)')
param spoke2Location string

@description('Location for workload vnet resources')
param workloadLocation string = 'uksouth'

@description('Administrator username for virtual machines')
param adminUsername string

@description('Administrator password for virtual machines')
@secure()
param adminPassword string

@description('VM size for all virtual machines')
param vmSize string = 'Standard_D2s_v3'

// Add parameter to control Bastion deployment
@description('Whether to deploy Bastion Host')
param deployBastion bool = false  // Controlled via main.parameters.json

// Add parameter to control VPN deployment
@description('Whether to deploy VPN Gateway')
param deployVpnGateway bool = false  // Controlled via main.parameters.json

// Add parameter to control ExpressRoute deployment
@description('Whether to deploy ExpressRoute Circuit and Gateway (demo only)')
param deployExpressRoute bool = true

// Add parameter to control Azure Firewall deployment
@description('Whether to deploy Azure Firewall in hub VNet')
param deployFirewall bool = true

// Add parameter to control NAT Gateway deployment
@description('Whether to deploy NAT Gateway for outbound connectivity')
param deployNatGateway bool = true

// Add parameter to control Traffic Manager deployment
@description('Whether to deploy Traffic Manager with App Services')
param deployTrafficManager bool = true

// Add parameter to control Route Server deployment
@description('Whether to deploy Azure Route Server with BGP NVA for dynamic routing demos')
param deployRouteServer bool = false  // Controlled via main.parameters.json

@description('SSH public key for NVA admin user (required if deployRouteServer is true)')
param nvaSshPublicKey string = ''

@description('Whether to deploy Azure Virtual Network Manager with demo VNets')
param deployAVNM bool = true

// Point-to-Site VPN parameters
@description('Enable Point-to-Site VPN on VPN Gateway')
param enableP2S bool = false  // Controlled via main.parameters.json

@description('Point-to-Site client address pool')
param vpnClientAddressPool string = '172.16.201.0/24'

@description('Base64-encoded root certificate public key for P2S authentication')
@secure()
param p2sRootCertData string = ''

@description('Name for the P2S root certificate')
param p2sRootCertName string = 'P2SRootCert'

// Add parameters for Key Vault and CMK
@description('Whether to deploy Key Vault for customer-managed keys demos')
param deployKeyVault bool = true 

@description('Object ID of the admin for Key Vault access')
param adminObjectId string = ''

@description('Whether to enable Customer-Managed Keys for storage encryption')
param enableCmkForStorage bool = false

param publicDnsZoneBase  string = 'contoso.com'
param privateDnsZoneBase string = 'contoso.local'
param vaultName          string = 'contoso-rsv'
param storageAccountPrefix string = 'staz700'

var hubVnetName = 'hub-vnet'
var spoke1VnetName = 'spoke1-vnet'
var spoke2VnetName = 'spoke2-vnet'
var workloadVnetName = 'workload-vnet'


module network 'network.bicep' = {
  name: 'vnets'
  params: {
    hublocation: hubLocation
    spoke1location: spoke1Location
    spoke2location: spoke2Location
    workloadlocation: workloadLocation
    hubVnetName: hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
    workloadVnetName: workloadVnetName
  }
}

module bastion 'bastion.bicep' = if (deployBastion) {
  name: 'bastion'
  params: {
    location:      hubLocation
    vnetName:      hubVnetName
    bastionName:   'hub-bastion'
    pipName:       'hub-bastion-pip'
  }
  dependsOn: [
    network 
  ]
}

module firewall 'modules/networking/firewall.bicep' = if (deployFirewall) {
  name: 'azure-firewall'
  params: {
    location: hubLocation
    hubVnetName: hubVnetName
    firewallName: 'hub-azfw'
    firewallSku: 'Premium'
    firewallPolicyName: 'hub-azfw-policy'
  }
  dependsOn: [
    network
  ]
}

module vpnGateway 'vpnGateway.bicep' = if (deployVpnGateway) {
  name: 'vpn'
  params: {
    location: hubLocation
    vnetName: hubVnetName
    gatewayPip: 'hub-vpn-pip'
    vpnGatewayName: 'hub-vpn-gateway'
    enableP2S: enableP2S
    vpnClientAddressPool: vpnClientAddressPool
    rootCertificateData: p2sRootCertData
    rootCertificateName: p2sRootCertName
  }
  dependsOn: [
    network  
  ]
} 

 module enableGatewayTransit 'enableGatewayTransit.bicep' = if (deployVpnGateway) {
  name: 'enableGatewayTransit'
  params: {
    hubVnetName:    hubVnetName
    spoke1VnetName: spoke1VnetName
    spoke2VnetName: spoke2VnetName
  }
  dependsOn: [
    vpnGateway 
  ]
}

// Deploy ExpressRoute Circuit and Gateway (demo only - circuit stays NotProvisioned)
module expressRoute 'modules/networking/er.bicep' = if (deployExpressRoute) {
  name: 'expressroute-demo'
  params: {
    location: hubLocation
    hubVnetName: hubVnetName
    circuitName: 'er-circuit-az700-demo'
    serviceProviderName: 'Equinix'  // Valid provider - circuit stays NotProvisioned for demo
    peeringLocation: 'London'
    bandwidthInMbps: 50
    skuTier: 'Standard'
    skuFamily: 'MeteredData'
    gatewaySkuName: 'Standard'
  }
  dependsOn: [
    network
    vpnGateway // ExpressRoute Gateway must wait for VPN Gateway to finish (both use GatewaySubnet)
  ]
}

// Web Tier - UK South (Primary)
module webTier 'tiers/webTier.bicep' = {
  name: 'webTier'
  params: {
    location:       spoke1Location
    vnetName:       spoke1VnetName
    lbName:         'web-lb'
    vmNames:        [
      'web1-vm'
      'web2-vm'
    ]
    subnetName:     'default'
    adminUsername:  adminUsername
    adminPassword:  adminPassword
    vmSize:         vmSize
  }
  dependsOn: [
    network 
  ]
}

// Web Tier - North Europe (Secondary for Traffic Manager)
module webTierNE 'tiers/webTier.bicep' = {
  name: 'webTierNorthEurope'
  params: {
    location:       spoke2Location
    vnetName:       spoke2VnetName
    lbName:         'web-lb-ne'
    vmNames:        [
      'web3-vm'
      'web4-vm'
    ]
    subnetName:     'default'
    adminUsername:  adminUsername
    adminPassword:  adminPassword
    vmSize:         vmSize
  }
  dependsOn: [
    network
  ]
}

module appTier 'tiers/appTier.bicep' = {
  name: 'appTier'
  params: {
    location: spoke2Location 
    vnetName: spoke2VnetName
    appGwName: 'app-gateway'
    vmNames: [
      'vm1'
    ]
    vmSubnetName: 'default'
    appGwSubnetName: 'AppGwSubnet' // Make sure this subnet exists in the spoke2-vnet
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
  }
  dependsOn: [
    network 
  ]
}

module workloadTier 'tiers/workloadTier.bicep' = {
  name: 'workloadTier'
  params: {
    location: workloadLocation 
    vnetName: workloadVnetName
    lbName: 'workload-lb'
    vmName: 'workload1-vm'
    subnetName: 'default'
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
  }
  dependsOn: [
    network 
  ]
}

module consumerPe 'consumerPE.bicep' = {
  name: 'consumerPE'
  params: {
    location:           spoke2Location
    vnetName:           spoke2VnetName
    consumerSubnetName: 'default'
    peName:             'workload-pe'
    plsName:            'workload-pls'
  }
  dependsOn: [
    workloadTier
  ]
}

module shared 'sharedServices.bicep' = {
  name: 'sharedServices'
  params: {
    location: hubLocation
    publicDnsZoneBase: publicDnsZoneBase
    privateDnsZoneBase: privateDnsZoneBase
    vaultName: vaultName
    storageAccountPrefix: storageAccountPrefix
    deployKeyVault: deployKeyVault
    adminObjectId: adminObjectId
    enableCmkForStorage: enableCmkForStorage
  }
  dependsOn: [
    workloadTier
  ]
}

module dnsLinks 'dnsLinks.bicep' = {
  name: 'dnsLinks'
  params: {
    privateDnsZoneName:   shared.outputs.privateDnsZoneName
    hubVnetName:          hubVnetName
    spoke1VnetName:       spoke1VnetName
    spoke2VnetName:       spoke2VnetName
  }
  dependsOn: [
    network 
  ]
}

// Traffic Manager with multi-region web tiers (no App Service quota needed)
module trafficManager 'modules/services/trafficManagerVm.bicep' = if (deployTrafficManager) {
  name: 'trafficManager'
  params: {
    trafficManagerName: 'az700-tm'
    routingMethod: 'Performance'
    primaryEndpointName: 'uksouth-web'
    primaryEndpointTarget: webTier.outputs.loadBalancerPublicIp
    primaryEndpointLocation: 'UK South'
    secondaryEndpointName: 'northeurope-web'
    secondaryEndpointTarget: webTierNE.outputs.loadBalancerPublicIp
    secondaryEndpointLocation: 'North Europe'
    monitorProtocol: 'HTTP'
    monitorPort: 80
    monitorPath: '/'
  }
}

// NAT Gateway for outbound connectivity demos
module natGateway 'modules/networking/natGateway.bicep' = if (deployNatGateway) {
  name: 'natGateway'
  params: {
    location: hubLocation
    natGatewayName: 'hub-nat-gateway'
    publicIpName: 'hub-nat-pip'
  }
}

// DISABLED: Azure Front Door with App Services (requires quota for Basic/Standard App Service Plans)
// Use deploy-afd-simple.bicep separately if you need AFD in front of App Gateway
/*
module azureFrontDoor 'modules/services/afd.bicep' = {
  name: 'azureFrontDoor'
  params: {
    appServicePlanSku: 'S1'
    webAppName: 'az700-demo'
  }
}
*/

module avnm 'modules/networking/avnm.bicep' = if (deployAVNM) {
  name: 'azureVirtualNetworkManager'
  params: {
    location: hubLocation
  }
}

// Azure Route Server with BGP NVA for dynamic routing demos
module routeServer 'modules/networking/routeServer.bicep' = if (deployRouteServer) {
  name: 'route-server'
  params: {
    location: hubLocation
    routeServerName: 'hub-route-server'
    vnetId: network.outputs.hubVnetId
    routeServerSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'RouteServerSubnet')
    enableBranchToBranch: true
    bgpPeers: []
    tags: {
      environment: 'demo'
      projectName: 'az700'
    }
  }
}

// BGP Network Virtual Appliance (FRRouting) for Route Server demos
module bgpNva 'modules/networking/bgpNva.bicep' = if (deployRouteServer) {
  name: 'bgp-nva'
  params: {
    location: hubLocation
    nvaName: 'hub-bgp-nva'
    vnetId: network.outputs.hubVnetId
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'hub-mgmt')
    vmSize: vmSize
    adminUsername: adminUsername
    adminPublicKey: nvaSshPublicKey
    routeServerIps: routeServer!.outputs.routeServerIps
    routeServerAsn: routeServer!.outputs.routeServerAsn
    nvaAsn: 65001
    advertisedRoutes: [
      '192.168.100.0/24'
      '192.168.200.0/24'
    ]
    tags: {
      environment: 'demo'
      projectName: 'az700'
    }
  }
}

// Update Route Server with BGP peering after NVA is deployed
module routeServerPeering 'modules/networking/routeServer.bicep' = if (deployRouteServer) {
  name: 'route-server-peering'
  params: {
    location: hubLocation
    routeServerName: 'hub-route-server'
    vnetId: network.outputs.hubVnetId
    routeServerSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'RouteServerSubnet')
    enableBranchToBranch: true
    bgpPeers: [
      {
        name: 'bgp-nva-peer'
        peerIp: bgpNva!.outputs.nvaPrivateIp
        peerAsn: 65001
      }
    ]
    tags: {
      environment: 'demo'
      projectName: 'az700'
    }
  }
}

// Network Monitoring with Traffic Analytics
@description('Whether to deploy Network Watcher with Traffic Analytics')
param deployNetworkMonitoring bool = true

module networkMonitoring 'modules/monitoring/networkMonitoring.bicep' = if (deployNetworkMonitoring) {
  name: 'network-monitoring'
  params: {
    location: hubLocation
    secondaryLocation: spoke2Location  // For multi-region VNet flow logs storage
    namePrefix: 'az700'
    nsgResourceIds: [
      network.outputs.spoke1NsgId
      network.outputs.spoke2NsgId
      network.outputs.workloadNsgId
      network.outputs.appGwNsgId
    ]
    retentionDays: 7
    trafficAnalyticsInterval: 10
  }
}

// ==================== OUTPUTS ====================

// DISABLED: Azure Front Door outputs (module commented out above)
/*
@description('Azure Front Door endpoint URL')
output frontDoorUrl string = azureFrontDoor.outputs.frontDoorEndpointUrl

@description('Azure Front Door endpoint hostname')
output frontDoorHostName string = azureFrontDoor.outputs.frontDoorEndpointHostName

@description('UK South App Service URL')
output uksouthWebAppUrl string = azureFrontDoor.outputs.uksouthWebAppUrl

@description('West Europe App Service URL')
output westeuropeWebAppUrl string = azureFrontDoor.outputs.westeuropeWebAppUrl

@description('Azure Front Door Profile Name')
output frontDoorProfileName string = azureFrontDoor.outputs.frontDoorProfileName

@description('WAF Policy Name')
output wafPolicyName string = azureFrontDoor.outputs.wafPolicyName
*/
