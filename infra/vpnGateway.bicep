// infra/vpnGateway.bicep
targetScope = 'resourceGroup'

@description('Azure region for the VPN gateway')
param location      string

@description('Name of the existing hub VNet')
param vnetName      string

@description('Name for the Public IP to associate with the VPN gateway')
param gatewayPip    string = 'hub-vpn-pip'

@description('Name of the VPN gateway')
param vpnGatewayName string = 'hub-vpn-gateway'

@description('Enable Point-to-Site VPN configuration')
param enableP2S bool = false

@description('Point-to-Site VPN client address pool (e.g., 172.16.201.0/24)')
param vpnClientAddressPool string = '172.16.201.0/24'

@description('Base64-encoded root certificate public key data for P2S authentication')
@secure()
param rootCertificateData string = ''

@description('Name for the root certificate')
param rootCertificateName string = 'P2SRootCert'

// 1️⃣ Create Public IPs for the VPN Gateway
// Active-active requires 2; active-active + P2S requires 3
resource publicIp1 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: gatewayPip
  location: location
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']
  properties: { publicIPAllocationMethod: 'Static' }
}

resource publicIp2 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${gatewayPip}2'
  location: location
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']
  properties: { publicIPAllocationMethod: 'Static' }
}

resource publicIp3 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (enableP2S) {
  name: '${gatewayPip}3'
  location: location
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']
  properties: { publicIPAllocationMethod: 'Static' }
}

// 2️⃣ Reference the existing VNet (must have a subnet called "GatewaySubnet")
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

// 3️⃣ Deploy the VPN Gateway
// Active-active + P2S requires exactly 3 IP configurations
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: vpnGatewayName
  location: location

  properties: {
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: true

    ipConfigurations: enableP2S ? [
      {
        name: 'vpngw-ipconfig1'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/GatewaySubnet' }
          publicIPAddress: { id: publicIp1.id }
        }
      }
      {
        name: 'vpngw-ipconfig2'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/GatewaySubnet' }
          publicIPAddress: { id: publicIp2.id }
        }
      }
      {
        name: 'vpngw-ipconfig3'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/GatewaySubnet' }
          publicIPAddress: { id: publicIp3!.id }
        }
      }
    ] : [
      {
        name: 'vpngw-ipconfig1'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/GatewaySubnet' }
          publicIPAddress: { id: publicIp1.id }
        }
      }
      {
        name: 'vpngw-ipconfig2'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/GatewaySubnet' }
          publicIPAddress: { id: publicIp2.id }
        }
      }
    ]

    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }

    vpnClientConfiguration: enableP2S ? {
      vpnClientAddressPool: {
        addressPrefixes: [ vpnClientAddressPool ]
      }
      vpnClientProtocols: [ 'IkeV2', 'OpenVPN' ]
      vpnAuthenticationTypes: [ 'Certificate' ]
      vpnClientRootCertificates: !empty(rootCertificateData) ? [
        {
          name: rootCertificateName
          properties: { publicCertData: rootCertificateData }
        }
      ] : []
    } : null
  }
}

@description('VPN Gateway resource ID')
output vpnGatewayId string = vpnGateway.id

@description('VPN Gateway name')
output vpnGatewayName string = vpnGateway.name

@description('VPN Gateway public IP address')
output vpnGatewayPublicIp string = publicIp1.properties.ipAddress

@description('VPN Gateway public IP address 2 (active-active)')
output vpnGatewayPublicIp2 string = publicIp2.properties.ipAddress

@description('P2S enabled status')
output p2sEnabled bool = enableP2S

@description('Active-active mode enabled')
output activeActive bool = true
