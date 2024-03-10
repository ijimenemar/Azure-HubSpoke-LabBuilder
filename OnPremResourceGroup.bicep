targetScope = 'subscription'

param location string
param AddressSpace string
param deployBastionInOnPrem bool
param bastionSku string
param adminUsername string
@secure()
param adminPassword string
param deployVMsInOnPrem bool
param deployGatewayInOnPrem bool
param OnPremRgName string
param vmSize string
param tagsByResource object
param osType string

param vpnGwEnebaleBgp bool
param vpnGwBgpAsn int

param diagnosticWorkspaceId string

param dcrID string

var vnetName = 'VNET-OnPrem'
var vmName = 'VM-OnPrem'
var nsgName = 'NSG-OnPrem'
var bastionName = 'Bastion-OnPrem'
var gatewayName = 'Gateway-OnPrem'

var defaultSubnetPrefix = cidrSubnet(AddressSpace, 26, 0)
var bastionSubnetPrefix = cidrSubnet(AddressSpace, 27, 4)
var gatewaySubnetPrefix = cidrSubnet(AddressSpace, 27, 5)

resource onpremrg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: OnPremRgName
  location: location
  tags: contains(tagsByResource, 'Microsoft.Resources/subscriptions/resourceGroups') ? tagsByResource['Microsoft.Resources/subscriptions/resourceGroups'] : {}
}

module vnet 'modules/vnet.bicep' = {
  scope: onpremrg
  name: vnetName
  params: {
    location: location
    vnetAddressSpcae: AddressSpace
    nsgID: nsg.outputs.nsgID
    vnetname: vnetName
    defaultSubnetPrefix: defaultSubnetPrefix
    bastionSubnetPrefix: deployBastionInOnPrem ? bastionSubnetPrefix : ''
    GatewaySubnetPrefix: gatewaySubnetPrefix
    deployBastionSubnet: deployBastionInOnPrem
    deployGatewaySubnet: true
    tagsByResource: tagsByResource
  }
}

module vm 'modules/vm.bicep' = if (deployVMsInOnPrem) {
  scope: onpremrg
  name: vmName
  params: {
    adminPassword: adminPassword
    adminUsername: adminUsername
    location: location
    subnetID: vnet.outputs.defaultSubnetID
    vmName: vmName
    vmSize: vmSize
    tagsByResource: tagsByResource
    osType: osType
    diagnosticWorkspaceId: diagnosticWorkspaceId
    dcrID: dcrID
  }
}

module nsg 'modules/nsg.bicep' = {
  scope: onpremrg
  name: nsgName
  params: {
    location: location
    nsgName: nsgName
    tagsByResource: tagsByResource
  }
}

module bastion 'modules/bastion.bicep' = if (deployBastionInOnPrem) {
  scope: onpremrg
  name: bastionName
  params: {
    location: location
    subnetID: deployBastionInOnPrem ? vnet.outputs.bastionSubnetID : ''
    bastionName: bastionName
    tagsByResource: tagsByResource
    bastionSku: bastionSku
  }
}

module vpngw 'modules/vpngateway.bicep' = if (deployGatewayInOnPrem) {
  scope: onpremrg
  name: gatewayName
  params: {
    location: location
    vpnGatewayName: gatewayName
    vpnGatewaySubnetID: deployGatewayInOnPrem ? vnet.outputs.gatewaySubnetID : ''
    tagsByResource: tagsByResource
    vpnGatewayBgpAsn: vpnGwEnebaleBgp ? vpnGwBgpAsn : 65515
    vpnGatewayEnableBgp: vpnGwEnebaleBgp
  }
}

output OnPremGatewayPublicIP string = deployGatewayInOnPrem ? vpngw.outputs.vpnGwPublicIP : 'none'
output OnPremGatewayID string = deployGatewayInOnPrem ? vpngw.outputs.vpnGwID : 'none'
output OnPremAddressSpace string = AddressSpace
output OnPremGwBgpPeeringAddress string = deployGatewayInOnPrem ? vpngw.outputs.vpnGwBgpPeeringAddress : 'none'
output OnPremGwBgpAsn int = deployGatewayInOnPrem && vpnGwEnebaleBgp ? vpngw.outputs.vpnGwAsn : 0
