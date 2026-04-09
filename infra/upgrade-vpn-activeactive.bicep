// Upgrade VPN Gateway to Active-Active Mode
// Required for Route Server compatibility

targetScope = 'resourceGroup'

@description('Location for resources')
param location string = 'uksouth'

@description('VPN Gateway name')
param vpnGatewayName string = 'hub-vpn-gateway'

@description('Hub VNet name')
param hubVnetName string = 'hub-vnet'

// Create second public IP for active-active mode
resource vpnGatewayPip2 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'hub-vpn-pip2'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Reference existing resources
resource existingPip1 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'hub-vpn-pip'
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVnetName
}

// Update VPN Gateway to active-active with second IP
resource vpnGatewayActiveActive 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: vpnGatewayName
  location: location
  properties: {
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: true  // Enable active-active
    ipConfigurations: [
      {
        name: 'vpngw-ipconfig'  // Keep original name - cannot be removed!
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: existingPip1.id
          }
        }
      }
      {
        name: 'vpngw-ipconfig2'  // Add second IP config for active-active
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: vpnGatewayPip2.id
          }
        }
      }
    ]
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    // P2S configuration will be preserved if it exists
  }
}

output vpnGatewayName string = vpnGatewayActiveActive.name
output activeActive bool = vpnGatewayActiveActive.properties.activeActive
output publicIp1 string = existingPip1.properties.ipAddress
output publicIp2 string = vpnGatewayPip2.properties.ipAddress
