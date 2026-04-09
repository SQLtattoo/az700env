// Standalone Azure Front Door deployment
// Points to existing Application Gateway
targetScope = 'resourceGroup'

@description('Application Gateway FQDN as origin')
param appGatewayFqdn string

@description('Location (always global for AFD)')
param location string = 'global'

// Azure Front Door Profile (Premium tier - includes managed WAF rules)
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'fd-az700-${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  tags: {
    environment: 'demo'
    projectName: 'az700'
  }
}

// AFD Origin Group (points to App Gateway)
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoor
  name: 'appgateway-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 120
    }
    sessionAffinityState: 'Disabled'
  }
}

// AFD Origin (Application Gateway)
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: originGroup
  name: 'appgateway-origin'
  properties: {
    hostName: appGatewayFqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: appGatewayFqdn
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false  // App Gateway uses Azure-managed cert
  }
}

// AFD Endpoint
resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoor
  name: 'endpoint-${uniqueString(resourceGroup().id)}'
  location: location
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
    forwardingProtocol: 'HttpOnly'  // App Gateway handles HTTPS termination
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'  // Let App Gateway handle redirects
    enabledState: 'Enabled'
  }
  dependsOn: [
    origin
  ]
}

// WAF Policy for AFD (edge protection)
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: 'afdwaf${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
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
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

// Security Policy (attach WAF to endpoint)
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: frontDoor
  name: 'security-policy'
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

// Outputs
@description('Azure Front Door endpoint hostname')
output frontDoorHostName string = afdEndpoint.properties.hostName

@description('Azure Front Door endpoint URL')
output frontDoorUrl string = 'https://${afdEndpoint.properties.hostName}'

@description('Application Gateway origin')
output appGatewayOrigin string = appGatewayFqdn

@description('Front Door Profile Name')
output frontDoorProfileName string = frontDoor.name

@description('WAF Policy Name')
output wafPolicyName string = wafPolicy.name
