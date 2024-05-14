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

@description('The index of the user')
param userIndex int

@description('Object Id of the Ville-user who needs privileges to Windows Admin Center')
param villeUserObjectId string

//VARIABLES
var rootDnsZoneName = split(rootDnsZoneId, '/')[8]
var rootDnsZoneResourceGroup = split(rootDnsZoneId, '/')[4]
var windowsAdminCenterRoleId = 'a6333a3e-0164-44c3-b281-7a577aff287f'

//RESOURCES

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: 'c${userIndex}.${rootDnsZoneName}'
  location: 'Global'
  tags: tags
}

resource roleAssignmentContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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

resource roleAssignmentRestrictedUAA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'roleAssignment', userObjectId, windowsAdminCenterRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
    ) //Role definition id for UAA
    principalId: userObjectId
    principalType: 'User'
    condition: '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${windowsAdminCenterRoleId}} AND @Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${villeUserObjectId}, ${userObjectId}})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${windowsAdminCenterRoleId}} AND @Resource[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${villeUserObjectId}, ${userObjectId}}) )'
    conditionVersion: '2.0'
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
