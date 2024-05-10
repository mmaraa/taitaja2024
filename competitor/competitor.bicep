targetScope = 'subscription'

// PARAMETERS
@description('The user principal name of the user')
param userPrincipalName string

@description('User objectId')
param userObjectId string

@description('The location of the resource group')
param deplLocation string = 'swedencentral'

@description('Competition name')
param competitionName string

@description('The name of the root DNS zone')
param rootDnsZoneId string

@description('Tags for resources')
param tags object = {
  competitionName: competitionName
  sourceRepository: 'https://github.com/mmaraa/taitaja2024'
}

//VARIABLES
var userPrefix = split(userPrincipalName, '@')[0]

//RESOURCES
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${userPrefix}-${competitionName}-prod-001'
  location: deplLocation
  tags: tags
}

module competitorInfra 'competitor-infra.bicep' = {
  scope: rg
  name: 'competitor-infra'
  params: {
    competitionName: competitionName
    rootDnsZoneId: rootDnsZoneId
    userPrincipalName: userPrincipalName
    userObjectId: userObjectId
    tags: tags
  }
}
