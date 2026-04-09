/// Azure Virtual Network Manager (AVNM) Demonstration
/// This template demonstrates essential AVNM features for centralized network management

@description('Location for AVNM resources')
param location string = resourceGroup().location

@description('Unique identifier for resource naming')
param uniqueId string = uniqueString(resourceGroup().id)

@description('Subscription ID for network manager scope')
param subscriptionId string = subscription().subscriptionId

// Variables for demo scenario
var avnmName = 'avnm-${uniqueId}'
var networkGroupNames = {
  production: 'ng-production'
  development: 'ng-development'
  shared: 'ng-shared'
}

// Sample VNets for demonstration (representing different environments)
var demoVNets = [
  {
    name: 'vnet-prod-web-${uniqueId}'
    addressPrefix: '10.1.0.0/16'
    environment: 'production'
    location: location
  }
  {
    name: 'vnet-prod-db-${uniqueId}'
    addressPrefix: '10.18.0.0/16'
    environment: 'production'
    location: location
  }
  {
    name: 'vnet-dev-${uniqueId}'
    addressPrefix: '10.10.0.0/16'
    environment: 'development'
    location: location
  }
  {
    name: 'vnet-shared-services-${uniqueId}'
    addressPrefix: '10.100.0.0/16'
    environment: 'shared'
    location: location
  }
]

// Create demo VNets
resource demoVirtualNetworks 'Microsoft.Network/virtualNetworks@2023-04-01' = [for vnet in demoVNets: {
  name: vnet.name
  location: vnet.location
  tags: {
    Environment: vnet.environment
    ManagedBy: 'AVNM'
    Demo: 'true'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet.addressPrefix
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: cidrSubnet(vnet.addressPrefix, 24, 0)
        }
      }
    ]
  }
}]

// Azure Virtual Network Manager
resource networkManager 'Microsoft.Network/networkManagers@2023-04-01' = {
  name: avnmName
  location: location
  tags: {
    Purpose: 'Demo'
    Environment: 'All'
  }
  properties: {
    description: 'Azure Virtual Network Manager demonstration for centralized network management'
    networkManagerScopes: {
      subscriptions: [
        '/subscriptions/${subscriptionId}'
      ]
    }
    networkManagerScopeAccesses: [
      'Connectivity'
      'SecurityAdmin'
    ]
  }
}

// Network Groups for different environments
resource networkGroups 'Microsoft.Network/networkManagers/networkGroups@2023-04-01' = [for (groupName, index) in items(networkGroupNames): {
  parent: networkManager
  name: groupName.value
  properties: {
    description: 'Network group for ${groupName.key} environment'
  }
}]

// Static Members for Production Network Group (Web and DB VNets)
resource prodWebStaticMember 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-04-01' = {
  parent: networkGroups[1] // production group (index 1: alphabetical 'development'=0, 'production'=1, 'shared'=2)
  name: 'prod-web-member'
  properties: {
    resourceId: demoVirtualNetworks[0].id // vnet-prod-web (array index 0)
  }
}

resource prodDbStaticMember 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-04-01' = {
  parent: networkGroups[1] // production group (index 1: alphabetical 'development'=0, 'production'=1, 'shared'=2)  
  name: 'prod-db-member'
  properties: {
    resourceId: demoVirtualNetworks[1].id // vnet-prod-db (array index 1)
  }
}

// Static Member for Development Network Group
resource devStaticMember 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-04-01' = {
  parent: networkGroups[0] // development group (index 0: alphabetical 'development'=0, 'production'=1, 'shared'=2)
  name: 'dev-member'
  properties: {
    resourceId: demoVirtualNetworks[2].id // vnet-dev (array index 2)
  }
}

// Static Member for Shared Services Network Group
resource sharedStaticMember 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2023-04-01' = {
  parent: networkGroups[2] // shared group (index 2 after alphabetical sort)
  name: 'shared-member'
  properties: {
    resourceId: demoVirtualNetworks[3].id // vnet-shared-services
  }
}

// Connectivity Configuration - Hub and Spoke for Production
resource prodHubSpokeConfig 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-04-01' = {
  parent: networkManager
  name: 'prod-hub-spoke-config'
  properties: {
    description: 'Hub and spoke connectivity for production environment'
    connectivityTopology: 'HubAndSpoke'
    hubs: [
      {
        resourceId: demoVirtualNetworks[0].id // Production Web VNet as hub
        resourceType: 'Microsoft.Network/virtualNetworks'
      }
    ]
    appliesToGroups: [
      {
        networkGroupId: networkGroups[1].id // production group (index 1 after alphabetical sort)
        useHubGateway: 'False'
        isGlobal: 'False'
        groupConnectivity: 'None'
      }
    ]
    isGlobal: 'False'
    deleteExistingPeering: 'True'
  }
}

// Connectivity Configuration - Mesh for Development (simpler topology)
resource devMeshConfig 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-04-01' = {
  parent: networkManager
  name: 'dev-mesh-config'
  properties: {
    description: 'Mesh connectivity for development environment'
    connectivityTopology: 'Mesh'
    appliesToGroups: [
      {
        networkGroupId: networkGroups[0].id // development group (index 0 after alphabetical sort)
        useHubGateway: 'False'
        isGlobal: 'False'
        groupConnectivity: 'DirectlyConnected'
      }
      {
        networkGroupId: networkGroups[2].id // shared services group (index 2 after alphabetical sort)
        useHubGateway: 'False'
        isGlobal: 'False'
        groupConnectivity: 'DirectlyConnected'
      }
    ]
    isGlobal: 'False'
    deleteExistingPeering: 'True'
  }
}

// Security Admin Configuration
resource securityAdminConfig 'Microsoft.Network/networkManagers/securityAdminConfigurations@2023-04-01' = {
  parent: networkManager
  name: 'security-admin-config'
  properties: {
    description: 'Security admin configuration for network-level security policies'
    applyOnNetworkIntentPolicyBasedServices: [
      'None'
    ]
  }
}

// Security Admin Rule Collection for Production
resource prodSecurityRuleCollection 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections@2023-04-01' = {
  parent: securityAdminConfig
  name: 'prod-security-rules'
  properties: {
    description: 'Security rules for production environment'
    appliesToGroups: [
      {
        networkGroupId: networkGroups[1].id // production group (index 1 after alphabetical sort)
      }
    ]
  }
}

// Security Admin Rules for Production
resource allowHttpsRule 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections/rules@2023-04-01' = {
  parent: prodSecurityRuleCollection
  name: 'AllowHTTPS'
  kind: 'Custom'
  properties: {
    description: 'Allow HTTPS traffic'
    protocol: 'Tcp'
    direction: 'Inbound'
    sources: [
      {
        addressPrefix: 'Internet'
        addressPrefixType: 'ServiceTag'
      }
    ]
    destinations: [
      {
        addressPrefix: '10.1.0.0/16'
        addressPrefixType: 'IPPrefix'
      }
    ]
    sourcePortRanges: [
      '0-65535'
    ]
    destinationPortRanges: [
      '443'
    ]
    access: 'Allow'
    priority: 100
  }
}

resource denyInternetRule 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections/rules@2023-04-01' = {
  parent: prodSecurityRuleCollection
  name: 'DenyInternet'
  kind: 'Custom'
  properties: {
    description: 'Deny direct internet access from database subnet'
    protocol: 'Any'
    direction: 'Outbound'
    sources: [
      {
        addressPrefix: '10.18.0.0/16'
        addressPrefixType: 'IPPrefix'
      }
    ]
    destinations: [
      {
        addressPrefix: 'Internet'
        addressPrefixType: 'ServiceTag'
      }
    ]
    sourcePortRanges: [
      '0-65535'
    ]
    destinationPortRanges: [
      '0-65535'
    ]
    access: 'Deny'
    priority: 200
  }
}

// Security Admin Rule Collection for Development (more permissive)
resource devSecurityRuleCollection 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections@2023-04-01' = {
  parent: securityAdminConfig
  name: 'dev-security-rules'
  properties: {
    description: 'Security rules for development environment (more permissive)'
    appliesToGroups: [
      {
        networkGroupId: networkGroups[0].id // development group (index 0 after alphabetical sort)
      }
    ]
  }
}

resource allowDevAccessRule 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections/rules@2023-04-01' = {
  parent: devSecurityRuleCollection
  name: 'AllowDevAccess'
  kind: 'Custom'
  properties: {
    description: 'Allow broader access for development'
    protocol: 'Any'
    direction: 'Inbound'
    sources: [
      {
        addressPrefix: '10.0.0.0/8'
        addressPrefixType: 'IPPrefix'
      }
    ]
    destinations: [
      {
        addressPrefix: '10.10.0.0/16'
        addressPrefixType: 'IPPrefix'
      }
    ]
    sourcePortRanges: [
      '0-65535'
    ]
    destinationPortRanges: [
      '22'
      '80'
      '443'
      '3389'
    ]
    access: 'Allow'
    priority: 300
  }
}

// Outputs for demonstration and verification
output networkManagerId string = networkManager.id
output networkManagerName string = networkManager.name
output networkGroups array = [for (groupName, index) in items(networkGroupNames): {
  name: networkGroups[index].name
  id: networkGroups[index].id
  environment: groupName.key
}]
output connectivityConfigurations array = [
  {
    name: prodHubSpokeConfig.name
    id: prodHubSpokeConfig.id
    topology: 'HubAndSpoke'
    environment: 'Production'
  }
  {
    name: devMeshConfig.name
    id: devMeshConfig.id
    topology: 'Mesh'
    environment: 'Development'
  }
]
output securityAdminConfigId string = securityAdminConfig.id
output demoVNets array = [for (vnet, index) in demoVNets: {
  name: demoVirtualNetworks[index].name
  id: demoVirtualNetworks[index].id
  environment: vnet.environment
  addressPrefix: vnet.addressPrefix
}]
output deploymentInstructions string = 'After deployment, go to Azure Portal > Network Manager > ${networkManager.name} > Deployments to deploy connectivity and security configurations to target regions.'
