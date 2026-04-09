// Azure Route Server Module
// Deploys Route Server for dynamic BGP routing with NVAs

@description('Location for the Route Server')
param location string

@description('Name of the Route Server')
param routeServerName string

@description('Virtual Network resource ID where Route Server will be deployed')
param vnetId string

@description('Route Server subnet resource ID (must be named RouteServerSubnet)')
param routeServerSubnetId string

@description('Enable branch-to-branch traffic (route exchange between VPN Gateway, ExpressRoute, and NVAs)')
param enableBranchToBranch bool = false

@description('Tags to apply to Route Server resources')
param tags object = {}

@description('BGP peers to configure (NVA IP addresses and ASNs)')
param bgpPeers array = []

// Public IP for Route Server (required for GA SLA)
resource routeServerPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${routeServerName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Route Server
resource routeServer 'Microsoft.Network/virtualHubs@2023-11-01' = {
  name: routeServerName
  location: location
  tags: tags
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: enableBranchToBranch
  }
}

// Route Server IP Configuration
resource ipConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2023-11-01' = {
  name: 'ipconfig1'
  parent: routeServer
  properties: {
    subnet: {
      id: routeServerSubnetId
    }
    publicIPAddress: {
      id: routeServerPublicIp.id
    }
  }
}

// BGP Connections (Peerings with NVAs)
resource bgpConnections 'Microsoft.Network/virtualHubs/bgpConnections@2023-11-01' = [for peer in bgpPeers: {
  name: peer.name
  parent: routeServer
  dependsOn: [
    ipConfig
  ]
  properties: {
    peerIp: peer.peerIp
    peerAsn: peer.peerAsn
  }
}]

@description('Route Server resource ID')
output routeServerId string = routeServer.id

@description('Route Server name')
output routeServerName string = routeServer.name

@description('Route Server ASN')
output routeServerAsn int = routeServer.properties.virtualRouterAsn

@description('Route Server BGP peering IP addresses')
output routeServerIps array = routeServer.properties.virtualRouterIps

@description('Route Server public IP address')
output publicIpAddress string = routeServerPublicIp.properties.ipAddress

@description('Branch-to-branch status')
output branchToBranchEnabled bool = routeServer.properties.allowBranchToBranchTraffic
