param name string = 'aksaz'
param location string = 'southeastasia'
param kubernetesVersion string = '1.20.7'
param systemVmSize string = 'Standard_B2s'
param systemNodeCount int = 1
param userVmSize string = 'Standard_D4s_v4'
param userNodeCount int = 2
param vnetSubnetID string = '/subscriptions/513df66c-64b0-4c0b-a13a-7f37bb384aff/resourceGroups/AKSAZ/providers/Microsoft.Network/virtualNetworks/aksaz-vnet/subnets/aksaz-kubenet-subnet'

resource aksaz 'Microsoft.ContainerService/managedClusters@2021-05-01' = {
  name: name
  location: location
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: name
    agentPoolProfiles: [
      {
        count: systemNodeCount
        vmSize: systemVmSize
        osDiskSizeGB: 32
        vnetSubnetID: vnetSubnetID
        maxPods: 110
        mode: 'System'
        upgradeSettings: {
          maxSurge: '1'
        }
        nodeLabels: {
          'nodepool': 'system'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        name: 'system'
      }
      {
        count: userNodeCount
        vmSize: userVmSize
        osDiskSizeGB: 64
        vnetSubnetID: vnetSubnetID
        maxPods: 110
        mode: 'User'
        enableAutoScaling: false
        scaleSetPriority: 'Spot'
        scaleSetEvictionPolicy: 'Delete'
        spotMaxPrice: any(-1)        
        upgradeSettings: {
          maxSurge: '1'
        }
        nodeLabels: {
          'nodepool': 'main'
        }
        name: 'main'
      }
    ]
    linuxProfile: {
      adminUsername: 'azadmin'
      ssh: {
        publicKeys: [
          {
            keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7AFV9EvTCX3IcG80V1TH9zT+dZEwpkYbltU5e61eL/Ht1QIqGNoDIbfSuYaRTTBWsHhFyugaXK6M7eJHOwmrTSIUa3abgSPrTygxG4mUF9qo65+zoPAwLniqQdzWMU2rEytfWJ9lw3HAKE6GPsMSptrL33Js5ymnNTDxZUH+RRwi0H3RgqZfGHRmOpMqeOd7eX3QrJUGkxL+6uwn7HblhcYyBQXKVgj7RgYusiTcOzsn0V9GevfxsHly5Xo/8eig69mNDoOs2PB2L2gJh1N6mJMETDErAenL4ySVOb1xkNA1TvXi0pam7Ox60C7ry8TtS1vM62KvNxdvSTLTyAi4B\n'
          }
        ]
      }
    }
    networkProfile: {
      networkPlugin: 'kubenet'
      networkPolicy: 'calico'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        '73236b89-2e56-47e8-b512-139419da5623'
      ]
      tenantID: '72f988bf-86f1-41af-91ab-2d7cd011db47'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }  
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
}
