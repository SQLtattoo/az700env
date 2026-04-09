# Enable VNet Flow Logs with Traffic Analytics
# VNet flow logs replace NSG flow logs (deprecated June 2025, retired Sept 2027)

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "uksouth"
)

Write-Host "Enabling VNet Flow Logs with Traffic Analytics..." -ForegroundColor Cyan

# Get the deployed resources
$workspaceId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name "az700-law" `
    --query id -o tsv

if ([string]::IsNullOrEmpty($workspaceId)) {
    Write-Host "ERROR: Could not find Log Analytics workspace 'az700-law'" -ForegroundColor Red
    exit 1
}

Write-Host "Workspace ID: $workspaceId" -ForegroundColor Gray

# Get all storage accounts for flow logs (one per region)
$storageAccounts = az storage account list `
    --resource-group $ResourceGroupName `
    --query "[?starts_with(name, 'az700fl')].{name:name, id:id, location:location}" | ConvertFrom-Json

Write-Host "Found $($storageAccounts.Count) storage account(s) for flow logs" -ForegroundColor Yellow
foreach ($sa in $storageAccounts) {
    Write-Host "  - $($sa.name) in $($sa.location)" -ForegroundColor Gray
}

# Get all VNets in the resource group
$vnets = az network vnet list --resource-group $ResourceGroupName --query "[].{name:name, id:id, location:location}" | ConvertFrom-Json

Write-Host "Found $($vnets.Count) VNets to configure" -ForegroundColor Yellow

foreach ($vnet in $vnets) {
    Write-Host "Enabling flow log for VNet: $($vnet.name) ($($vnet.location))" -ForegroundColor Green
    
    $flowLogName = "flowlog-$($vnet.name)"
    $vnetLocation = $vnet.location
    
    # Find storage account in the same region as the VNet
    $storageId = ($storageAccounts | Where-Object { $_.location -eq $vnetLocation } | Select-Object -First 1).id
    
    if ([string]::IsNullOrEmpty($storageId)) {
        Write-Host "  ⚠ No storage account found in $vnetLocation - skipping $($vnet.name)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "  Using storage: $storageId" -ForegroundColor Gray
    
    # Check if flow log already exists
    $existing = az network watcher flow-log show `
        --location $vnetLocation `
        --name $flowLogName `
        2>$null
    
    if ($existing) {
        Write-Host "  Flow log already exists, updating..." -ForegroundColor Yellow
        
        az network watcher flow-log update `
            --location $vnetLocation `
            --name $flowLogName `
            --vnet $vnet.id `
            --enabled true `
            --storage-account $storageId `
            --workspace $workspaceId `
            --interval 10 `
            --retention 7 `
            --format JSON `
            --log-version 2 `
            --traffic-analytics true
    } else {
        Write-Host "  Creating new VNet flow log..." -ForegroundColor Yellow
        
        az network watcher flow-log create `
            --location $vnetLocation `
            --name $flowLogName `
            --vnet $vnet.id `
            --enabled true `
            --storage-account $storageId `
            --workspace $workspaceId `
            --interval 10 `
            --retention 7 `
            --format JSON `
            --log-version 2 `
            --traffic-analytics true
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Flow log configured for $($vnet.name)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to configure flow log for $($vnet.name)" -ForegroundColor Red
    }
}

Write-Host "`n✓ VNet Flow Logs with Traffic Analytics enabled!" -ForegroundColor Green
Write-Host "Traffic Analytics data will be available in 10-15 minutes" -ForegroundColor Cyan
Write-Host "Access at: Azure Portal > Network Watcher > Traffic Analytics" -ForegroundColor Cyan
