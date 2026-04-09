// Standalone P2S VPN Configuration Update
// Run with: az deployment group create --resource-group rg-az700t4 --template-file infra/deploy-p2svpn.bicep

targetScope = 'resourceGroup'

@description('Location for resources')
param location string = 'uksouth'

@description('VPN Gateway name')
param vpnGatewayName string = 'hub-vpn-gateway'

@description('Point-to-Site client address pool')
param vpnClientAddressPool string = '172.16.201.0/24'

@description('Base64-encoded root certificate public key')
@secure()
param rootCertificateData string

@description('Root certificate name')
param rootCertificateName string = 'P2SRootCert'

// Reference existing VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' existing = {
  name: vpnGatewayName
}

// Get existing public IP
resource existingPip 'Microsoft.Network/publicIPAddresses@2023-11-01' existing = {
  name: 'hub-vpn-pip'
}

// Get existing VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: 'hub-vnet'
}

// Update VPN Gateway with P2S configuration
resource vpnGatewayUpdate 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: vpnGatewayName
  location: location
  properties: {
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
    ipConfigurations: [
      {
        name: 'vpngw-ipconfig'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: existingPip.id
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
        'IkeV2'
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'Certificate'
      ]
      vpnClientRootCertificates: [
        {
          name: rootCertificateName
          properties: {
            publicCertData: rootCertificateData
          }
        }
      ]
    }
  }
}

output vpnGatewayName string = vpnGatewayUpdate.name
output p2sConfigured bool = true
output clientAddressPool string = vpnClientAddressPool
