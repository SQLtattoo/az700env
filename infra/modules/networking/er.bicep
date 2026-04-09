// ExpressRoute Circuit and Gateway deployment for demo purposes
targetScope = 'resourceGroup'

@description('Location for ExpressRoute resources')
param location string = 'uksouth'

@description('Name of the hub VNet for ExpressRoute Gateway')
param hubVnetName string = 'hub-vnet'

@description('ExpressRoute circuit name')
param circuitName string = 'er-circuit-demo'

@description('Service provider name - must be valid Azure ER provider')
param serviceProviderName string = 'Equinix'

@description('Peering location - must match provider offerings')
param peeringLocation string = 'London'

@description('Bandwidth tier for the circuit')
param bandwidthInMbps int = 50

@description('SKU tier for the circuit')
@allowed(['Local', 'Standard', 'Premium'])
param skuTier string = 'Standard'

@description('SKU family for the circuit')
@allowed(['MeteredData', 'UnlimitedData'])
param skuFamily string = 'MeteredData'

@description('ExpressRoute Gateway SKU')
@allowed(['Standard', 'HighPerformance', 'UltraPerformance', 'ErGw1Az', 'ErGw2Az', 'ErGw3Az'])
param gatewaySkuName string = 'Standard'

// Reference existing hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: hubVnetName
}

// Create public IP for ExpressRoute Gateway
resource erGatewayPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${circuitName}-gateway-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    environment: 'demo'
    purpose: 'expressroute-gateway'
  }
}

// Reference existing GatewaySubnet (created by network.bicep with address 10.1.2.0/27)
resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: hubVnet
  name: 'GatewaySubnet'
}

// Create ExpressRoute Virtual Network Gateway
resource erGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: '${circuitName}-gateway'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'gatewayIpConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnet.id
          }
          publicIPAddress: {
            id: erGatewayPip.id
          }
        }
      }
    ]
    gatewayType: 'ExpressRoute'
    sku: {
      name: gatewaySkuName
      tier: gatewaySkuName
    }
    // Note: ExpressRoute gateways use BGP inherently for route exchange with circuits
    // but don't support explicit enableBgp/bgpSettings like VPN gateways
  }
  tags: {
    environment: 'demo'
    purpose: 'expressroute-gateway'
  }
}

// Create ExpressRoute Circuit (placeholder - won't have actual connectivity)
resource expressRouteCircuit 'Microsoft.Network/expressRouteCircuits@2023-05-01' = {
  name: circuitName
  location: location
  sku: {
    name: '${skuTier}_${skuFamily}'
    tier: skuTier
    family: skuFamily
  }
  properties: {
    serviceProviderProperties: {
      serviceProviderName: serviceProviderName
      peeringLocation: peeringLocation
      bandwidthInMbps: bandwidthInMbps
    }
    allowClassicOperations: false
    expressRoutePort: null
    bandwidthInGbps: null
  }
  tags: {
    environment: 'demo'
    purpose: 'expressroute-circuit'
    note: 'placeholder-for-demo-only'
  }
}

// NOTE: Peerings and connections cannot be configured until service provider provisions the circuit
// The circuit will show as 'NotProvisioned' which is expected for demo purposes
// To demo peering configuration, show the Portal UI options without actually configuring

/*
// These would be configured AFTER provider provisions the circuit:

// Private Peering - for Azure VNet connectivity
resource privateAzurePeering 'Microsoft.Network/expressRouteCircuits/peerings@2023-05-01' = {
  parent: expressRouteCircuit
  name: 'AzurePrivatePeering'
  properties: {
    peeringType: 'AzurePrivatePeering'
    vlanId: 100
    primaryPeerAddressPrefix: '192.168.1.0/30'
    secondaryPeerAddressPrefix: '192.168.1.4/30'
    peerASN: 65001
  }
}

// Microsoft Peering - for Microsoft 365/Dynamics 365
resource microsoftPeering 'Microsoft.Network/expressRouteCircuits/peerings@2023-05-01' = {
  parent: expressRouteCircuit
  name: 'MicrosoftPeering'
  properties: {
    peeringType: 'MicrosoftPeering'
    vlanId: 200
    primaryPeerAddressPrefix: '192.168.2.0/30'
    secondaryPeerAddressPrefix: '192.168.2.4/30'
    peerASN: 65001
    microsoftPeeringConfig: {
      advertisedPublicPrefixes: ['203.0.113.0/24']
      routingRegistryName: 'ARIN'
    }
  }
}

// Connection to VNet Gateway
resource erConnection 'Microsoft.Network/connections@2023-05-01' = {
  name: '${circuitName}-connection'
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: { id: erGateway.id }
    peer: { id: expressRouteCircuit.id }
  }
}
*/

// Outputs for demo purposes
output expressRouteCircuitId string = expressRouteCircuit.id
output expressRouteCircuitName string = expressRouteCircuit.name
output expressRouteGatewayId string = erGateway.id
output expressRouteGatewayName string = erGateway.name
// Note: serviceKey only available after circuit is created
// circuitProvisioningState will be 'Enabled', serviceProviderProvisioningState will be 'NotProvisioned'
