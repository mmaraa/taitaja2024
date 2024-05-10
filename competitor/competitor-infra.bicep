// PARAMETERS
@description('The user principal name of the user')
param userPrincipalName string

@description('Competition name')
param competitionName string

@description('User objectId')
param userObjectId string

@description('The name of the root DNS zone')
param rootDnsZoneId string

@description('Tags for resources')
param tags object = {
  competitionName: competitionName
  sourceRepository: 'https://github.com/mmaraa/taitaja2024'
}

//VARIABLES
var userPrefix = split(userPrincipalName, '@')[0]
var userIndex = split(userPrefix, '-')[1]
var rootDnsZoneName = split(rootDnsZoneId, '/')[8]
var rootDnsZoneResourceGroup = split(rootDnsZoneId, '/')[4]

//RESOURCES

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: '${userIndex}.${rootDnsZoneName}'
  location: 'Global'
  tags: tags
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'roleAssignment', userObjectId)
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c'
    ) //Role definition id for Contributor
    principalId: userObjectId
    principalType: 'User'
  }
}

module nsRecords 'ns-record-to-root.bicep' = {
  name: 'ns-record-to-root'
  scope: resourceGroup(rootDnsZoneResourceGroup)
  params: {
    ns1: dnsZone.properties.nameServers[0]
    ns2: dnsZone.properties.nameServers[1]
    ns3: dnsZone.properties.nameServers[2]
    ns4: dnsZone.properties.nameServers[3]
    rootDnsZoneId: rootDnsZoneId
    userPrincipalName: userPrincipalName
  }
}
