// Standalone Route Server Deployment
// Run with: az deployment group create --resource-group rg-az700t4 --template-file infra/deploy-routeserver.bicep --parameters adminUsername=azadmin

targetScope = 'resourceGroup'

@description('Location for resources')
param location string = 'uksouth'

@description('Hub VNet name')
param hubVnetName string = 'hub-vnet'

@description('Admin username for NVA')
param adminUsername string

@description('SSH public key for NVA')
@secure()
param sshPublicKey string

// Reference existing hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVnetName
}

// Deploy Route Server
module routeServer 'modules/networking/routeServer.bicep' = {
  name: 'route-server-deployment'
  params: {
    location: location
    routeServerName: 'hub-route-server'
    vnetId: hubVnet.id
    routeServerSubnetId: '${hubVnet.id}/subnets/RouteServerSubnet'
    enableBranchToBranch: true
    bgpPeers: []  // Will add BGP peers after NVA is created
    tags: {
      environment: 'demo'
      projectName: 'az700'
      deployment: 'standalone'
    }
  }
}

// Deploy BGP NVA
module bgpNva 'modules/networking/bgpNva.bicep' = {
  name: 'bgp-nva-deployment'
  params: {
    location: location
    nvaName: 'hub-bgp-nva'
    vnetId: hubVnet.id
    subnetId: '${hubVnet.id}/subnets/hub-mgmt'
    nvaPrivateIp: '10.1.3.10'  // Static IP to avoid dependency issues
    vmSize: 'Standard_D2s_v3'
    adminUsername: adminUsername
    adminPublicKey: sshPublicKey
    routeServerIps: routeServer.outputs.routeServerIps
    routeServerAsn: routeServer.outputs.routeServerAsn
    nvaAsn: 65001
    advertisedRoutes: [
      '192.168.100.0/24'
      '192.168.200.0/24'
    ]
    tags: {
      environment: 'demo'
      projectName: 'az700'
      deployment: 'standalone'
    }
  }
  dependsOn: [
    routeServer
  ]
}

// Update Route Server with BGP peering (requires second deployment)
module routeServerPeering 'modules/networking/routeServer.bicep' = {
  name: 'route-server-peering-deployment'
  params: {
    location: location
    routeServerName: 'hub-route-server'
    vnetId: hubVnet.id
    routeServerSubnetId: '${hubVnet.id}/subnets/RouteServerSubnet'
    enableBranchToBranch: true
    bgpPeers: [
      {
        name: 'bgp-nva-peer'
        peerIp: bgpNva.outputs.nvaPrivateIp
        peerAsn: 65001
      }
    ]
    tags: {
      environment: 'demo'
      projectName: 'az700'
      deployment: 'standalone'
    }
  }
  dependsOn: [
    bgpNva
  ]
}

output routeServerName string = routeServer.outputs.routeServerName
output routeServerAsn int = routeServer.outputs.routeServerAsn
output routeServerIps array = routeServer.outputs.routeServerIps
output nvaName string = bgpNva.outputs.nvaName
output nvaPrivateIp string = bgpNva.outputs.nvaPrivateIp
output nvaAsn int = bgpNva.outputs.nvaAsn
