# Azure Front Door Demo Script
# Demonstrates global load balancing, WAF protection, and edge acceleration

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-az700t4",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

Write-Host "🌐 Azure Front Door Demo Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription if provided
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

# Get Front Door details
Write-Host "📋 Step 1: Getting Front Door Configuration..." -ForegroundColor Yellow
$frontDoorProfile = az cdn profile list --resource-group $ResourceGroupName --query "[?contains(name, 'fd-')]" | ConvertFrom-Json | Select-Object -First 1

if (-not $frontDoorProfile) {
    Write-Host "❌ Error: Azure Front Door not found in resource group '$ResourceGroupName'" -ForegroundColor Red
    exit 1
}

$profileName = $frontDoorProfile.name
Write-Host "✅ Found Front Door Profile: $profileName" -ForegroundColor Green

# Get endpoint
$endpoint = az cdn endpoint list --profile-name $profileName --resource-group $ResourceGroupName | ConvertFrom-Json | Select-Object -First 1

if (-not $endpoint) {
    # Try AFD endpoints
    $endpoint = az afd endpoint list --profile-name $profileName --resource-group $ResourceGroupName | ConvertFrom-Json | Select-Object -First 1
}

$endpointHostName = $endpoint.hostName
$frontDoorUrl = "https://$endpointHostName"

Write-Host "✅ Front Door URL: $frontDoorUrl" -ForegroundColor Green
Write-Host ""

# Get backend App Services
Write-Host "📋 Step 2: Getting Backend App Services..." -ForegroundColor Yellow
$webApps = az webapp list --resource-group $ResourceGroupName --query "[?contains(name, 'afd')].[name,hostNames[0]]" --output tsv

$webAppsList = @()
$webApps -split "`n" | ForEach-Object {
    $parts = $_ -split "`t"
    if ($parts.Length -eq 2) {
        $webAppsList += @{
            Name = $parts[0]
            Url = "https://$($parts[1])"
        }
    }
}

if ($webAppsList.Count -eq 0) {
    Write-Host "⚠️  Warning: No backend App Services found" -ForegroundColor Yellow
} else {
    Write-Host "✅ Found $($webAppsList.Count) backend App Services:" -ForegroundColor Green
    $webAppsList | ForEach-Object {
        Write-Host "   - $($_.Name): $($_.Url)" -ForegroundColor Cyan
    }
}
Write-Host ""

# Test connectivity
Write-Host "📋 Step 3: Testing Front Door Connectivity..." -ForegroundColor Yellow
Write-Host "Testing: $frontDoorUrl" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $frontDoorUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ Front Door is responding: $($response.StatusCode)" -ForegroundColor Green
    
    # Check headers
    if ($response.Headers['X-Azure-Ref']) {
        Write-Host "   - X-Azure-Ref: $($response.Headers['X-Azure-Ref'])" -ForegroundColor Cyan
    }
    if ($response.Headers['X-Cache']) {
        Write-Host "   - X-Cache: $($response.Headers['X-Cache'])" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠️  Warning: Could not connect to Front Door" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Performance test
Write-Host "📋 Step 4: Performance Comparison..." -ForegroundColor Yellow
Write-Host "Testing latency: Front Door vs Direct App Service" -ForegroundColor Cyan

# Test Front Door
$afdTimes = @()
for ($i = 1; $i -le 3; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-WebRequest -Uri $frontDoorUrl -UseBasicParsing -TimeoutSec 10 | Out-Null
        $sw.Stop()
        $afdTimes += $sw.ElapsedMilliseconds
    } catch {
        Write-Host "   Test $i failed" -ForegroundColor Red
    }
}

$afdAvg = ($afdTimes | Measure-Object -Average).Average
Write-Host "✅ Front Door Average: $([math]::Round($afdAvg, 2)) ms" -ForegroundColor Green

# Test direct backend (if available)
if ($webAppsList.Count -gt 0) {
    $directTimes = @()
    $directUrl = $webAppsList[0].Url
    
    for ($i = 1; $i -le 3; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            Invoke-WebRequest -Uri $directUrl -UseBasicParsing -TimeoutSec 10 | Out-Null
            $sw.Stop()
            $directTimes += $sw.ElapsedMilliseconds
        } catch {
            Write-Host "   Test $i failed" -ForegroundColor Red
        }
    }
    
    $directAvg = ($directTimes | Measure-Object -Average).Average
    Write-Host "✅ Direct Backend Average: $([math]::Round($directAvg, 2)) ms" -ForegroundColor Green
    
    $improvement = [math]::Round((($directAvg - $afdAvg) / $directAvg) * 100, 1)
    if ($improvement -gt 0) {
        Write-Host "🚀 Front Door is $improvement% faster!" -ForegroundColor Green
    } else {
        Write-Host "📊 Performance comparison complete" -ForegroundColor Cyan
    }
}
Write-Host ""

# WAF Policy
Write-Host "📋 Step 5: WAF Policy Information..." -ForegroundColor Yellow
$wafPolicies = az network front-door waf-policy list --resource-group $ResourceGroupName | ConvertFrom-Json

if ($wafPolicies.Count -gt 0) {
    $wafPolicy = $wafPolicies[0]
    Write-Host "✅ WAF Policy: $($wafPolicy.name)" -ForegroundColor Green
    Write-Host "   - Mode: $($wafPolicy.policySettings.mode)" -ForegroundColor Cyan
    Write-Host "   - State: $($wafPolicy.policySettings.enabledState)" -ForegroundColor Cyan
    Write-Host "   - Custom Rules: $($wafPolicy.customRules.rules.Count)" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  No WAF policy found" -ForegroundColor Yellow
}
Write-Host ""

# Demo commands
Write-Host "🎯 Demo Commands" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Open Front Door URL in browser:" -ForegroundColor Cyan
Write-Host "   $frontDoorUrl" -ForegroundColor White
Write-Host ""
Write-Host "2️⃣  Test WAF Rate Limiting (PowerShell):" -ForegroundColor Cyan
Write-Host "   1..150 | ForEach-Object { Invoke-WebRequest -Uri '$frontDoorUrl' -UseBasicParsing }" -ForegroundColor White
Write-Host ""
Write-Host "3️⃣  View Front Door metrics:" -ForegroundColor Cyan
Write-Host "   az monitor metrics list --resource `"$($frontDoorProfile.id)`" --metric-names TotalLatency" -ForegroundColor White
Write-Host ""
Write-Host "4️⃣  View WAF logs (requires diagnostic settings):" -ForegroundColor Cyan
Write-Host "   Portal > Front Door > Diagnostic settings > Check for WAF logs" -ForegroundColor White
Write-Host ""

Write-Host "✅ Demo script complete!" -ForegroundColor Green
