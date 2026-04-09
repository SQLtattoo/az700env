// Standalone Azure Front Door Deployment
// Run with: az deployment group create --resource-group rg-az700t4 --template-file infra/deploy-afd.bicep

targetScope = 'resourceGroup'

@description('App Service Plan SKU')
param appServicePlanSku string = 'B1'

@description('Web App base name')
param webAppName string = 'az700-demo'

module afd 'modules/services/afd.bicep' = {
  name: 'azure-front-door'
  params: {
    appServicePlanSku: appServicePlanSku
    webAppName: webAppName
  }
}

output frontDoorUrl string = afd.outputs.frontDoorEndpointUrl
output frontDoorHostName string = afd.outputs.frontDoorEndpointHostName
output uksouthWebAppUrl string = afd.outputs.uksouthWebAppUrl
output westeuropeWebAppUrl string = afd.outputs.westeuropeWebAppUrl
output frontDoorProfileName string = afd.outputs.frontDoorProfileName
output wafPolicyName string = afd.outputs.wafPolicyName
