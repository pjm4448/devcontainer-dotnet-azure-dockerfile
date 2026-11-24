targetScope = 'resourceGroup'

@description('The region for this example storage account.')
param location string = resourceGroup().location

@description('A globally unique storage account name, if this template were deployed.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'learn${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: {
    purpose: 'devcontainer-learning'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
  }
}

output exampleStorageAccountName string = storageAccount.name
