# Demo: Route Server (BGP) vs User Defined Routes (UDR) Priority
# This script demonstrates Azure route precedence: UDR > BGP > System Routes

param(
    [string]$ResourceGroup = "rg-az700t4",
    [string]$RouteServerName = "hub-route-server",
    [string]$TestVmName = "web1-vm",  # Spoke1 VM for testing
    [string]$RouteTableName = "spoke1-override-udr"
)

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  Route Server vs UDR Priority Demo" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Step 1: Show Route Server BGP peering status
Write-Host "`n[Step 1] Checking Route Server BGP Peering Status..." -ForegroundColor Yellow
Write-Host "Command: az network routeserver peering list" -ForegroundColor Gray

$peeringStatus = az network routeserver peering list `
    --routeserver $RouteServerName `
    --resource-group $ResourceGroup `
    --output table

Write-Host $peeringStatus
Start-Sleep -Seconds 2

# Step 2: Show routes learned by Route Server from BGP NVA
Write-Host "`n[Step 2] Routes Learned by Route Server from BGP NVA..." -ForegroundColor Yellow
Write-Host "Command: az network routeserver peering list-learned-routes" -ForegroundColor Gray

try {
    $learnedRoutes = az network routeserver peering list-learned-routes `
        --name "bgp-nva-peer" `
        --routeserver $RouteServerName `
        --resource-group $ResourceGroup `
        --output json | ConvertFrom-Json
    
    Write-Host "`n📥 Routes learned from NVA (ASN 65001):" -ForegroundColor Green
    $learnedRoutes.value | ForEach-Object {
        Write-Host "  • $($_.network) → Next Hop: $($_.nextHop) | Origin: $($_.origin)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ⚠️  Could not retrieve learned routes. BGP peering may still be establishing." -ForegroundColor Yellow
}
Start-Sleep -Seconds 2

# Step 3: Get VM NIC ID
Write-Host "`n[Step 3] Getting effective routes on VM BEFORE UDR..." -ForegroundColor Yellow
Write-Host "Command: az vm show + az network nic show-effective-route-table" -ForegroundColor Gray

$nicId = az vm show `
    --name $TestVmName `
    --resource-group $ResourceGroup `
    --query "networkProfile.networkInterfaces[0].id" `
    -o tsv

if (-not $nicId) {
    Write-Host "❌ VM '$TestVmName' not found. Adjust -TestVmName parameter." -ForegroundColor Red
    exit 1
}

$effectiveRoutes = az network nic show-effective-route-table `
    --ids $nicId `
    --output table

Write-Host "`n📊 Effective Routes (BEFORE UDR):" -ForegroundColor Green
Write-Host $effectiveRoutes

# Highlight BGP routes
Write-Host "`n🔍 Look for routes with Source = 'VirtualNetworkGateway' (from Route Server)" -ForegroundColor Magenta
Write-Host "    These are the BGP-learned routes: 192.168.100.0/24, 192.168.200.0/24" -ForegroundColor Magenta
Start-Sleep -Seconds 3

# Step 4: Create Route Table with UDR to override BGP route
Write-Host "`n[Step 4] Creating Route Table with UDR to OVERRIDE BGP route..." -ForegroundColor Yellow
Write-Host "We'll create UDR for 192.168.100.0/24 pointing to Azure Firewall instead of NVA" -ForegroundColor Gray

$routeTableExists = az network route-table show `
    --name $RouteTableName `
    --resource-group $ResourceGroup `
    --query "id" -o tsv 2>$null

if (-not $routeTableExists) {
    Write-Host "`nCreating route table: $RouteTableName" -ForegroundColor Cyan
    az network route-table create `
        --name $RouteTableName `
        --resource-group $ResourceGroup `
        --location uksouth `
        --disable-bgp-route-propagation false `
        --output none
    
    Write-Host "✅ Route table created" -ForegroundColor Green
} else {
    Write-Host "Route table already exists: $RouteTableName" -ForegroundColor Cyan
}

# Create UDR that overrides BGP route
Write-Host "`nAdding UDR: 192.168.100.0/24 → Azure Firewall (10.1.4.4)" -ForegroundColor Cyan
az network route-table route create `
    --name "override-bgp-route-to-192-168-100" `
    --route-table-name $RouteTableName `
    --resource-group $ResourceGroup `
    --address-prefix "192.168.100.0/24" `
    --next-hop-type VirtualAppliance `
    --next-hop-ip-address "10.1.4.4" `
    --output none

Write-Host "✅ UDR created for 192.168.100.0/24" -ForegroundColor Green
Start-Sleep -Seconds 2

# Step 5: Associate route table with spoke1 subnet
Write-Host "`n[Step 5] Associating route table with spoke1 subnet..." -ForegroundColor Yellow

$spoke1SubnetId = az network vnet subnet show `
    --vnet-name "spoke1-vnet" `
    --name "default" `
    --resource-group $ResourceGroup `
    --query "id" -o tsv

if ($spoke1SubnetId) {
    az network vnet subnet update `
        --ids $spoke1SubnetId `
        --route-table $RouteTableName `
        --output none
    
    Write-Host "✅ Route table associated with spoke1-vnet/default subnet" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not find spoke1-vnet/default subnet" -ForegroundColor Yellow
}

# Wait for route propagation
Write-Host "`n⏳ Waiting 30 seconds for route propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Step 6: Check effective routes AFTER UDR
Write-Host "`n[Step 6] Getting effective routes on VM AFTER UDR..." -ForegroundColor Yellow

$effectiveRoutesAfter = az network nic show-effective-route-table `
    --ids $nicId `
    --output table

Write-Host "`n📊 Effective Routes (AFTER UDR):" -ForegroundColor Green
Write-Host $effectiveRoutesAfter

# Analysis
Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "  ANALYSIS: Route Precedence" -ForegroundColor Cyan
Write-Host "="*70 -ForegroundColor Cyan

Write-Host "`n🔍 Key Observations:" -ForegroundColor Magenta
Write-Host "   1. BEFORE UDR: 192.168.100.0/24 had Source='VirtualNetworkGateway', NextHop=10.1.3.10 (NVA)" -ForegroundColor White
Write-Host "   2. AFTER UDR:  192.168.100.0/24 now has Source='User', NextHop=10.1.4.4 (Firewall)" -ForegroundColor White
Write-Host "   3. 192.168.200.0/24 still has Source='VirtualNetworkGateway', NextHop=10.1.3.10 (NVA)" -ForegroundColor White

Write-Host "`n📚 Azure Route Priority:" -ForegroundColor Yellow
Write-Host "   1. User Defined Routes (UDRs)        ← Highest Priority ✅" -ForegroundColor Green
Write-Host "   2. BGP Routes (Route Server/VPN/ER)  ← Medium Priority" -ForegroundColor Yellow
Write-Host "   3. System Routes (VNet, Internet)    ← Lowest Priority" -ForegroundColor Gray

Write-Host "`n💡 Use Case:" -ForegroundColor Cyan
Write-Host "   • Route Server provides dynamic routing (BGP)" -ForegroundColor White
Write-Host "   • UDRs can selectively override specific routes when needed" -ForegroundColor White
Write-Host "   • Example: Force audit traffic through firewall while keeping others via NVA" -ForegroundColor White

# Cleanup option
Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "  CLEANUP OPTIONS" -ForegroundColor Cyan
Write-Host "="*70 -ForegroundColor Cyan

Write-Host "`nTo remove the UDR and restore BGP routing:" -ForegroundColor Yellow
Write-Host "  # Disassociate route table from subnet" -ForegroundColor Gray
Write-Host "  az network vnet subnet update --vnet-name spoke1-vnet --name default -g $ResourceGroup --route-table ''" -ForegroundColor Cyan
Write-Host "`n  # Delete route table" -ForegroundColor Gray
Write-Host "  az network route-table delete --name $RouteTableName -g $ResourceGroup" -ForegroundColor Cyan

Write-Host "`n✅ Demo Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
