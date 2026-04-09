// P2S VPN with Entra ID (Azure AD) Authentication
// Redeploy P2S configuration with Entra ID auth after active-active upgrade

targetScope = 'resourceGroup'

@description('Location for resources')
param location string = 'uksouth'

@description('VPN Gateway name')
param vpnGatewayName string = 'hub-vpn-gateway'

@description('Hub VNet name')
param hubVnetName string = 'hub-vnet'

@description('Point-to-Site client address pool')
param vpnClientAddressPool string = '172.16.201.0/24'

@description('Azure AD Tenant ID (e.g., your-tenant-id.onmicrosoft.com)')
param aadTenant string

@description('Azure AD Audience (Azure VPN Client App ID)')
param aadAudience string = '41b23e61-6c1e-4545-b367-cd054e0ed4b4' // Default Azure VPN Client App ID

@description('Azure AD Issuer URL')
param aadIssuer string

// Reference existing resources
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVnetName
}

resource existingPip1 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'hub-vpn-pip'
}

resource existingPip2 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'hub-vpn-pip2'
}

// Create third public IP for P2S (required for active-active + P2S)
resource pip3 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'hub-vpn-pip3'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Update VPN Gateway with P2S Entra ID configuration
resource vpnGatewayP2S 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: vpnGatewayName
  location: location
  properties: {
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: true
    ipConfigurations: [
      {
        name: 'vpngw-ipconfig'
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
        name: 'vpngw-ipconfig2'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: existingPip2.id
          }
        }
      }
      {
        name: 'vpngw-ipconfig3'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: pip3.id
          }
        }
      }
    ]
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'  // Only OpenVPN supports Entra ID auth
      ]
      vpnAuthenticationTypes: [
        'AAD'  // Entra ID (Azure AD) authentication
      ]
      aadTenant: aadTenant
      aadAudience: aadAudience
      aadIssuer: aadIssuer
    }
  }
}

output vpnGatewayName string = vpnGatewayP2S.name
output p2sConfigured bool = true
output authType string = 'Entra ID (Azure AD)'
output clientAddressPool string = vpnClientAddressPool
output aadTenant string = aadTenant
