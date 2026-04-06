// ============================================================
// modules/network.bicep
// Virtual Network with standard subnet layout
// ============================================================

@description('VNet name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('VNet address space, e.g. 10.0.0.0/16')
param addressPrefix string = '10.0.0.0/16'

// ── Subnets ───────────────────────────────────────────────────
// /24 subnets carved from the address space.
// Service endpoints are pre-expanded as objects (nested for-loops not allowed in Bicep).
var subnets = [
  {
    name: 'snet-app'
    addressPrefix: replace(addressPrefix, '0.0/16', '1.0/24')
    serviceEndpoints: [
      { service: 'Microsoft.Storage' }
      { service: 'Microsoft.KeyVault' }
    ]
    delegations: []
  }
  {
    name: 'snet-data'
    addressPrefix: replace(addressPrefix, '0.0/16', '2.0/24')
    serviceEndpoints: [
      { service: 'Microsoft.Storage' }
      { service: 'Microsoft.Sql' }
    ]
    delegations: []
  }
  {
    name: 'snet-mgmt'
    addressPrefix: replace(addressPrefix, '0.0/16', '3.0/24')
    serviceEndpoints: []
    delegations: []
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        serviceEndpoints: subnet.serviceEndpoints
        delegations: subnet.delegations
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = {
  app: vnet.properties.subnets[0].id
  data: vnet.properties.subnets[1].id
  mgmt: vnet.properties.subnets[2].id
}
