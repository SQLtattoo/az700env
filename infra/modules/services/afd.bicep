/// Azure Front Door Module with Multi-Region App Services
param appServicePlanSku string = 'S1'
param webAppName string = 'az700-webapp'

// Variables for regions and naming
var regions = [
  {
    name: 'uksouth'
    location: 'uksouth'
    appServicePlanName: 'asp-uksouth-afd-${uniqueString(resourceGroup().id)}'
    webAppName: '${webAppName}-uksouth-afd-${uniqueString(resourceGroup().id)}'
  }
  {
    name: 'westeurope'
    location: 'westeurope'
    appServicePlanName: 'asp-westeurope-afd-${uniqueString(resourceGroup().id)}'
    webAppName: '${webAppName}-westeurope-afd-${uniqueString(resourceGroup().id)}'
  }
]

// App Service Plans
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = [for region in regions: {
  name: region.appServicePlanName
  location: region.location
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  properties: {
    reserved: false
  }
}]

// App Services (Web Apps)
resource webApp 'Microsoft.Web/sites@2023-01-01' = [for (region, i) in regions: {
  name: region.webAppName
  location: region.location
  properties: {
    serverFarmId: appServicePlan[i].id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '18-lts'
        }
        {
          name: 'REGION_NAME'
          value: region.location
        }
      ]
    }
  }
}]

// Azure Front Door Profile
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'fd-${uniqueString(resourceGroup().id, subscription().id)}'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

// AFD Origin Group
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoor
  name: 'webapp-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
    sessionAffinityState: 'Disabled'
  }
}

// AFD Origins (App Services)
resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = [for (region, i) in regions: {
  parent: originGroup
  name: '${region.name}-origin'
  properties: {
    hostName: webApp[i].properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: webApp[i].properties.defaultHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}]

// AFD Endpoint
resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoor
  name: 'endpoint-${uniqueString(resourceGroup().id, subscription().id)}'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// AFD Route
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: afdEndpoint
  name: 'default-route'
  properties: {
    customDomains: []
    originGroup: {
      id: originGroup.id
    }
    originPath: '/'
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    origins
  ]
}

// Security Policy (WAF)
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: frontDoor
  name: 'webapp-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: afdEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// WAF Policy
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: 'az700afdwafv2${uniqueString(resourceGroup().id)}'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      redirectUrl: 'https://www.microsoft.com'
      customBlockResponseStatusCode: 403
      customBlockResponseBody: 'PGh0bWw+CjxoZWFkPgo8dGl0bGU+QmxvY2tlZDwvdGl0bGU+CjwvaGVhZD4KPGJ5ZHk+CjxoMT5CbG9ja2VkIGJ5IEF6dXJlIEZyb250IERvb3I8L2gxPgo8L2JvZHk+CjwvaHRtbD4='
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: [
        {
          name: 'RateLimitRule'
          enabledState: 'Enabled'
          priority: 1
          ruleType: 'RateLimitRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '0.0.0.0/0'
              ]
            }
          ]
          action: 'Block'
        }
      ]
    }
  }
}

// Outputs
output frontDoorEndpointHostName string = afdEndpoint.properties.hostName
output frontDoorEndpointUrl string = 'https://${afdEndpoint.properties.hostName}'
output uksouthWebAppUrl string = 'https://${webApp[0].properties.defaultHostName}'
output westeuropeWebAppUrl string = 'https://${webApp[1].properties.defaultHostName}'
output uksouthWebAppName string = webApp[0].name
output westeuropeWebAppName string = webApp[1].name
output frontDoorProfileName string = frontDoor.name
output wafPolicyName string = wafPolicy.name  
