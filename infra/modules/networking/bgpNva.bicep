// BGP Network Virtual Appliance Module
// Deploys Linux VM with FRRouting for BGP peering with Route Server

@description('Location for the NVA')
param location string

@description('Name of the NVA VM')
param nvaName string

@description('Virtual Network resource ID')
param vnetId string

@description('Subnet resource ID for NVA')
param subnetId string

@description('Private IP address for the NVA (optional, will use dynamic if not specified)')
param nvaPrivateIp string = ''

@description('VM size for the NVA')
param vmSize string = 'Standard_D2s_v3'

@description('Admin username for the NVA VM')
param adminUsername string

@description('SSH public key for admin user')
@secure()
param adminPublicKey string

@description('Route Server BGP peer IPs (for FRRouting configuration)')
param routeServerIps array

@description('Route Server ASN')
param routeServerAsn int

@description('NVA ASN for BGP peering')
param nvaAsn int = 65001

@description('Routes to advertise from NVA to Route Server')
param advertisedRoutes array = [
  '192.168.100.0/24'
  '192.168.200.0/24'
]

@description('Tags to apply to NVA resources')
param tags object = {}

// Network Interface for NVA
resource nvaNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${nvaName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: empty(nvaPrivateIp) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(nvaPrivateIp) ? null : nvaPrivateIp
        }
      }
    ]
    enableIPForwarding: true
  }
}

// Use provided IP or let FRRouting auto-detect (using 0.0.0.0 as placeholder)
var nvaIpForConfig = empty(nvaPrivateIp) ? '0.0.0.0' : nvaPrivateIp

// Cloud-init configuration for FRRouting
var cloudInitConfig = '''
#cloud-config
package_update: true
package_upgrade: true

packages:
  - frr

write_files:
  - path: /etc/frr/daemons
    content: |
      bgpd=yes
      ospfd=no
      ospf6d=no
      ripd=no
      ripngd=no
      isisd=no
      pimd=no
      ldpd=no
      nhrpd=no
      eigrpd=no
      babeld=no
      sharpd=no
      pbrd=no
      bfdd=no
      fabricd=no
      vrrpd=no
      
      vtysh_enable=yes
      zebra_options="  -A 127.0.0.1 -s 90000000"
      bgpd_options="   -A 127.0.0.1"
      
  - path: /etc/frr/frr.conf
    content: |
      frr version 8.1
      frr defaults traditional
      hostname {NVA_NAME}
      log syslog informational
      no ipv6 forwarding
      service integrated-vtysh-config
      !
      ! Static routes (required for BGP advertisement)
      ! BGP can only advertise routes that exist in the routing table
      ! Null0 routes create blackhole routes without physical interfaces
      {STATIC_ROUTES}
      !
      router bgp {NVA_ASN}
       bgp router-id {NVA_IP}
       neighbor {RS_IP1} remote-as {RS_ASN}
       neighbor {RS_IP1} ebgp-multihop 255
       neighbor {RS_IP2} remote-as {RS_ASN}
       neighbor {RS_IP2} ebgp-multihop 255
       !
       address-family ipv4 unicast
        {ADVERTISED_ROUTES}
        neighbor {RS_IP1} soft-reconfiguration inbound
        neighbor {RS_IP1} route-map rmap-bogon-asns in
        neighbor {RS_IP1} route-map rmap-azure-asns out
        neighbor {RS_IP2} soft-reconfiguration inbound
        neighbor {RS_IP2} route-map rmap-bogon-asns in
        neighbor {RS_IP2} route-map rmap-azure-asns out
       exit-address-family
      !
      bgp as-path access-list azure-asns seq 5 permit _12076_
      bgp as-path access-list azure-asns seq 10 permit _65515_
      bgp as-path access-list bogon-asns seq 5 permit _0_
      bgp as-path access-list bogon-asns seq 10 permit _23456_
      bgp as-path access-list bogon-asns seq 15 permit _1310[0-6][0-9]_|_13107[0-1]_
      !
      route-map rmap-bogon-asns deny 5
       match as-path bogon-asns
      route-map rmap-bogon-asns permit 10
      !
      route-map rmap-azure-asns deny 5
       match as-path azure-asns
      route-map rmap-azure-asns permit 10
      !
      line vty
      !

runcmd:
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  - sysctl -p
  - systemctl enable frr
  - systemctl restart frr
  - sleep 10
  - vtysh -c "show ip bgp summary" > /tmp/bgp-status.txt

final_message: "FRRouting NVA is ready for BGP peering with Azure Route Server"
'''

// Replace placeholders in cloud-init config
var advertisedRoutesConfig = join(map(advertisedRoutes, route => 'network ${route}'), '\n        ')
var staticRoutesConfig = join(map(advertisedRoutes, route => 'ip route ${route} Null0'), '\n      ')

var rsIp1 = length(routeServerIps) > 0 ? routeServerIps[0] : '0.0.0.0'
var rsIp2 = length(routeServerIps) > 1 ? routeServerIps[1] : '0.0.0.0'

var finalCloudInit = replace(replace(replace(replace(replace(replace(replace(cloudInitConfig, 
  '{NVA_NAME}', nvaName),
  '{NVA_ASN}', string(nvaAsn)),
  '{NVA_IP}', nvaIpForConfig),
  '{RS_ASN}', string(routeServerAsn)),
  '{RS_IP1}', rsIp1),
  '{RS_IP2}', rsIp2),
  '{STATIC_ROUTES}', staticRoutesConfig)
  
var finalCloudInitWithRoutes = replace(finalCloudInit, '{ADVERTISED_ROUTES}', advertisedRoutesConfig)

// NVA Virtual Machine
resource nvaVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: nvaName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: nvaName
      adminUsername: adminUsername
      customData: base64(finalCloudInitWithRoutes)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${nvaName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nvaNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

@description('NVA VM resource ID')
output nvaId string = nvaVm.id

@description('NVA VM name')
output nvaName string = nvaVm.name

@description('NVA private IP address')
output nvaPrivateIp string = empty(nvaPrivateIp) ? nvaNic.properties.ipConfigurations[0].properties.privateIPAddress : nvaPrivateIp

@description('NVA ASN')
output nvaAsn int = nvaAsn

@description('NVA NIC resource ID')
output nvanicId string = nvaNic.id
