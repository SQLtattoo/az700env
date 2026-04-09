// Network Monitoring with Traffic Analytics
targetScope = 'resourceGroup'

@description('Location for monitoring resources')
param location string

@description('Name prefix for monitoring resources')
param namePrefix string = 'az700'

@description('NSG resource IDs to enable flow logs')
param nsgResourceIds array

@description('Retention days for flow logs')
param retentionDays int = 7

@description('Traffic Analytics interval in minutes')
@allowed([10, 60])
param trafficAnalyticsInterval int = 10

// Create Log Analytics Workspace for Traffic Analytics
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 5 // Limit daily ingestion to control costs
    }
  }
  tags: {
    purpose: 'network-monitoring'
    environment: 'demo'
  }
}

// Create Storage Account for VNet Flow Logs - Primary region
var storageNameRaw = '${namePrefix}flow${uniqueString(resourceGroup().id)}'
var storageName = length(storageNameRaw) > 24 ? substring(storageNameRaw, 0, 24) : storageNameRaw

resource flowLogStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
  tags: {
    purpose: 'vnet-flow-logs'
    environment: 'demo'
  }
}

// Create Storage Account for VNet Flow Logs - Secondary region
var storageNameNE = '${namePrefix}flne${uniqueString(resourceGroup().id)}'
var storageNameNorthEurope = length(storageNameNE) > 24 ? substring(storageNameNE, 0, 24) : storageNameNE

@description('Secondary location for flow logs storage (for multi-region VNets)')
param secondaryLocation string = 'northeurope'

resource flowLogStorageAccountNE 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageNameNorthEurope
  location: secondaryLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  tags: {
    purpose: 'vnet-flow-logs-secondary'
    environment: 'demo'
  }
}

// Note: VNet Flow Logs are deployed post-deployment via PowerShell script
// az network watcher flow-log create --vnet <vnet-id> --storage-account <storage-id> --workspace <workspace-id>

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output storageAccountId string = flowLogStorageAccount.id
output storageAccountName string = flowLogStorageAccount.name
output storageAccountIdNorthEurope string = flowLogStorageAccountNE.id
output storageAccountNameNorthEurope string = flowLogStorageAccountNE.name

// Useful queries for Traffic Analytics
output sampleQueries object = {
  topTalkersQuery: '''
    AzureNetworkAnalytics_CL
    | where SubType_s == "FlowLog"
    | where TimeGenerated > ago(1h)
    | summarize TotalBytes = sum(AllowedInFlows_d + AllowedOutFlows_d) by SrcIP_s
    | top 10 by TotalBytes desc
  '''
  blockedTrafficQuery: '''
    AzureNetworkAnalytics_CL
    | where SubType_s == "FlowLog"
    | where FlowStatus_s == "D" // Denied
    | where TimeGenerated > ago(1h)
    | summarize BlockedFlows = count() by SrcIP_s, DestIP_s, DestPort_d
    | top 10 by BlockedFlows desc
  '''
  maliciousFlowsQuery: '''
    AzureNetworkAnalytics_CL
    | where SubType_s == "FlowLog"
    | where MaliciousFlow_b == true
    | where TimeGenerated > ago(24h)
    | project TimeGenerated, SrcIP_s, DestIP_s, DestPort_d, FlowStatus_s
    | order by TimeGenerated desc
  '''
  trafficByProtocolQuery: '''
    AzureNetworkAnalytics_CL
    | where SubType_s == "FlowLog"
    | where TimeGenerated > ago(1h)
    | summarize TotalFlows = count() by L7Protocol_s
    | render piechart
  '''
  geographicTrafficQuery: '''
    AzureNetworkAnalytics_CL
    | where SubType_s == "FlowLog"
    | where isnotempty(SrcGeo_s)
    | where TimeGenerated > ago(24h)
    | summarize FlowCount = count() by SrcGeo_s, DestGeo_s
    | top 20 by FlowCount desc
  '''
}
