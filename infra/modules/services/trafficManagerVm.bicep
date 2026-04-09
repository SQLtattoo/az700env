// Traffic Manager with VM/Load Balancer endpoints (no App Service quota needed)
targetScope = 'resourceGroup'

@description('Traffic Manager profile name')
param trafficManagerName string = 'az700-tm'

@description('Unique DNS name for Traffic Manager')
param uniqueDnsName string = 'az700tm-${uniqueString(resourceGroup().id)}'

@description('Traffic routing method')
@allowed(['Performance', 'Weighted', 'Priority', 'Geographic', 'Multivalue', 'Subnet'])
param routingMethod string = 'Performance'

@description('Primary endpoint name')
param primaryEndpointName string = 'uksouth-endpoint'

@description('Primary endpoint target (public IP address or FQDN)')
param primaryEndpointTarget string

@description('Primary endpoint location')
param primaryEndpointLocation string = 'UK South'

@description('Secondary endpoint name')
param secondaryEndpointName string = 'northeurope-endpoint'

@description('Secondary endpoint target (public IP address or FQDN)')
param secondaryEndpointTarget string

@description('Secondary endpoint location')
param secondaryEndpointLocation string = 'North Europe'

@description('Monitoring protocol')
@allowed(['HTTP', 'HTTPS', 'TCP'])
param monitorProtocol string = 'HTTP'

@description('Monitoring port')
param monitorPort int = 80

@description('Monitoring path')
param monitorPath string = '/'

@description('TTL in seconds')
param ttl int = 30

// Traffic Manager Profile
resource trafficManagerProfile 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: trafficManagerName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: routingMethod
    dnsConfig: {
      relativeName: uniqueDnsName
      ttl: ttl
    }
    monitorConfig: {
      protocol: monitorProtocol
      port: monitorPort
      path: monitorPath
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
    }
    endpoints: [
      {
        name: primaryEndpointName
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          target: primaryEndpointTarget
          endpointStatus: 'Enabled'
          endpointLocation: primaryEndpointLocation
          weight: 1
          priority: 1
        }
      }
      {
        name: secondaryEndpointName
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          target: secondaryEndpointTarget
          endpointStatus: 'Enabled'
          endpointLocation: secondaryEndpointLocation
          weight: 1
          priority: 2
        }
      }
    ]
  }
  tags: {
    purpose: 'global-load-balancing'
    environment: 'demo'
  }
}

// Outputs
output trafficManagerId string = trafficManagerProfile.id
output trafficManagerName string = trafficManagerProfile.name
output trafficManagerFqdn string = trafficManagerProfile.properties.dnsConfig.fqdn
output trafficManagerUrl string = 'http://${trafficManagerProfile.properties.dnsConfig.fqdn}'
