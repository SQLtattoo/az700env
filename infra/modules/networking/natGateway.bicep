// NAT Gateway for outbound internet connectivity
targetScope = 'resourceGroup'

@description('Location for NAT Gateway resources')
param location string

@description('Name of the NAT Gateway')
param natGatewayName string = 'hub-nat-gateway'

@description('Name of the public IP for NAT Gateway')
param publicIpName string = 'hub-nat-pip'

@description('Idle timeout in minutes (4-120)')
@minValue(4)
@maxValue(120)
param idleTimeoutInMinutes int = 10

// Public IP for NAT Gateway
resource natPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    purpose: 'nat-gateway'
    environment: 'demo'
  }
}

// NAT Gateway
resource natGateway 'Microsoft.Network/natGateways@2023-05-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: idleTimeoutInMinutes
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
  tags: {
    purpose: 'outbound-connectivity'
    environment: 'demo'
  }
}

// Outputs
output natGatewayId string = natGateway.id
output natGatewayName string = natGateway.name
output publicIpAddress string = natPublicIp.properties.ipAddress
output publicIpId string = natPublicIp.id
