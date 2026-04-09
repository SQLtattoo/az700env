// Azure Firewall deployment for hub VNet
targetScope = 'resourceGroup'

@description('Location for Azure Firewall resources')
param location string

@description('Name of the hub virtual network')
param hubVnetName string

@description('Name for the Azure Firewall')
param firewallName string = 'hub-azfw'

@description('Azure Firewall SKU')
@allowed(['Standard', 'Premium'])
param firewallSku string = 'Standard'

@description('Azure Firewall policy name')
param firewallPolicyName string = 'hub-azfw-policy'

// Reference existing hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: hubVnetName
}

// Create public IP for Azure Firewall
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${firewallName}-pip'
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
    purpose: 'azure-firewall'
  }
}

// Create Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    intrusionDetection: {
      mode: 'Alert'
    }
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
  tags: {
    environment: 'demo'
    purpose: 'azure-firewall-policy'
  }
}

// Create Network Rule Collection Group for basic connectivity
resource networkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowInternetAccess'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowHTTP'
            ipProtocols: ['TCP']
            sourceAddresses: ['10.18.0.0/16', '10.3.0.0/16', '10.4.0.0/16'] // Spoke networks
            destinationAddresses: ['*']
            destinationPorts: ['80', '443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowDNS'
            ipProtocols: ['UDP']
            sourceAddresses: ['10.0.0.0/8'] // All RFC1918 space
            destinationAddresses: ['*']
            destinationPorts: ['53']
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowNTP'
            ipProtocols: ['UDP']
            sourceAddresses: ['10.0.0.0/8']
            destinationAddresses: ['*']
            destinationPorts: ['123']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowSpokeToSpoke'
        priority: 110
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'SpokeToSpokeCommunication'
            ipProtocols: ['Any']
            sourceAddresses: ['10.18.0.0/16', '10.3.0.0/16', '10.4.0.0/16']
            destinationAddresses: ['10.18.0.0/16', '10.3.0.0/16', '10.4.0.0/16']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

// Create Application Rule Collection Group for web traffic
resource applicationRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowWebTraffic'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowMicrosoftServices'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: ['10.0.0.0/8']
            targetFqdns: [
              '*.microsoft.com'
              '*.microsoftonline.com'
              '*.windows.net'
              '*.azure.com'
              '*.microsoft.com'
              'download.microsoft.com'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AllowGeneralWeb'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: ['10.0.0.0/8']
            targetFqdns: [
              '*.google.com'
              '*.github.com'
              '*.stackoverflow.com'
              '*.ubuntu.com'
              '*.debian.org'
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    networkRuleCollectionGroup
  ]
}

// Create Azure Firewall
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          publicIPAddress: {
            id: firewallPip.id
          }
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  tags: {
    environment: 'demo'
    purpose: 'azure-firewall'
  }
  dependsOn: [
    applicationRuleCollectionGroup
  ]
}

// Outputs
output firewallId string = azureFirewall.id
output firewallName string = azureFirewall.name
output firewallPrivateIP string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIP string = firewallPip.properties.ipAddress
output firewallPolicyId string = firewallPolicy.id
