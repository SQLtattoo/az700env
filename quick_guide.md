# ⚡ Quick Start Guide - AZ-700 Demo Environment

> **TL;DR: Get up and running in 5 minutes!** 🚀  
> This guide is for trainers and beginners who want to deploy the environment quickly without diving into technical details.

---

## 🎯 **What You'll Get**

A complete Azure networking demo environment with:
- ✅ Hub-and-spoke network topology
- ✅ Application Gateway (WAF protection)
- ✅ Traffic Manager (global load balancing)
- ✅ Route Server with BGP routing
- ✅ All AZ-700 exam scenarios covered

> ⚠️ **Azure Front Door** is disabled by default (requires App Service Plan quota). Use `infra/deploy-afd-simple.bicep` separately if needed for AFD demos.

**Cost**: Choose from $25/day (minimal) to $109/day (full) depending on what you need.

---

## 📋 **Prerequisites (5 Minutes)**

### **What You Need:**
1. **Azure Subscription** - Must have Owner or Contributor access
2. **Azure CLI** - Command line tool for Azure
3. **Azure Developer CLI (azd)** - Easy deployment tool

### **Quick Install (Windows PowerShell):**

```powershell
# 1. Install Azure CLI
winget install Microsoft.AzureCLI

# 2. Install Azure Developer CLI (azd)
winget install Microsoft.Azd

# 3. Login to Azure
az login
azd auth login

# 4. Verify installations
az --version
azd version
```

✅ **Done!** You're ready to deploy.

---

## 🚀 **Deploy in 3 Steps**

### **Step 1: Get the Code**

```powershell
# Clone the repository
git clone https://github.com/SQLtattoo/az700env.git
cd az700env
```

### **Step 2: Choose Your Deployment Mode**

Edit `infra/main.parameters.json` to set your desired profile before deploying:

#### **🌱 Option A: Minimal (Cheapest - ~$25/day)**
*Perfect for beginners and basic demos*

Set these to `false` in `infra/main.parameters.json`:
```json
"deployFirewall":     { "value": false },
"deployBastion":      { "value": false },
"deployRouteServer":  { "value": false },
"deployExpressRoute": { "value": false },
"deployVpnGateway":   { "value": false }
```

**What you get:**
- ✅ Hub-and-spoke networks
- ✅ Azure Front Door + App Gateway
- ✅ Traffic Manager
- ✅ Virtual Network Manager
- ❌ No Firewall, VPN, Route Server (saves $$)

---

#### **🌿 Option B: Essential (Balanced - ~$50/day)**
*Recommended for most training scenarios*

Set these to `false` in `infra/main.parameters.json`:
```json
"deployBastion":      { "value": false },
"deployFirewall":     { "value": false },
"deployRouteServer":  { "value": false },
"deployExpressRoute": { "value": false }
```

**What you get:**
- ✅ Everything from Minimal mode
- ✅ VPN Gateway (site-to-site demos)
- ✅ NAT Gateway
- ❌ No Firewall or Route Server

---

#### **🌳 Option C: Full (Complete - ~$109/day)**
*For comprehensive demos and all features*

Leave all values as `true` in `infra/main.parameters.json` (default), then:

```powershell
azd up
```

**What you get:**
- ✅ EVERYTHING enabled
- ✅ Azure Firewall Premium
- ✅ Route Server with BGP
- ✅ All networking features

---

### **Step 3: Deploy**

```powershell
# azd will prompt interactively for the VM admin password
azd up
```

The deployment will:
1. ⏳ Ask for environment name (e.g., "az700demo")
2. ⏳ Ask for Azure region (e.g., "uksouth")
3. ⏳ Deploy resources (15-30 minutes)
4. ✅ Show you the URLs when complete

**Grab a coffee!** ☕ This takes 15-60 minutes, depending the choices you made.

---

## 🎬 **After Deployment - Quick Tests**

### **1. Check Azure Front Door (Global CDN)**

```powershell
# Get your AFD URL
azd env get-values | Select-String "AZURE_FRONT_DOOR_ENDPOINT"

# Open in browser - you should see a demo website!
```

### **2. Check Traffic Manager (Global DNS)**

```powershell
# Get your Traffic Manager URL
azd env get-values | Select-String "TRAFFIC_MANAGER_FQDN"

# Open in browser - routes to closest region!
```

### **3. View All Resources**

```powershell
# Open Azure Portal
az group show --name rg-az700-<your-env-name> --query id -o tsv | xargs start
```

---

## 📖 **Run Your First Demo**

### **Demo: Azure Front Door Multi-Layer Security**

1. **Run the demo script:**
   ```powershell
   cd scripts
   .\Demo-AzureFrontDoor.ps1 -ResourceGroupName rg-az700-<your-env-name>
   ```

2. **What the script shows:**
   - ✅ AFD endpoint URL
   - ✅ Direct App Gateway URL
   - ✅ Backend App Service URL
   - ✅ Multi-layer security explanation

3. **Open the URLs in browser** - see the three-tier architecture!

### **Demo: Route Server BGP Routing** (If deployed Full mode)

1. **Run the demo script:**
   ```powershell
   cd scripts
   .\Demo-RouteServerVsUDR.ps1 -ResourceGroupName rg-az700-<your-env-name>
   ```

2. **What the script shows:**
   - ✅ BGP peering status
   - ✅ Routes learned from NVA
   - ✅ Route injection into VNets
   - ✅ Comparison with static UDRs

---

## 💰 **Cost Management**

### **Daily Costs by Mode:**

| Mode | Daily Cost | Monthly Cost | What's Running |
|------|-----------|--------------|----------------|
| **Minimal** | ~$25 | ~$750 | Networks, AFD, Traffic Manager |
| **Essential** | ~$50 | ~$1,500 | + VPN Gateway, ExpressRoute |
| **Full** | ~$109 | ~$3,284 | + Firewall, Route Server, Bastion |

### **💡 Best Practice: Deploy Only When Needed!**

```powershell
# Before training session:
azd up  # Deploy resources

# After training session (SAME DAY):
azd down --purge --force  # Delete everything

# Total cost: Only ~$4-10 per training day!
```

---

## 🛑 **Cleanup (IMPORTANT!)**

### **Delete Everything to Stop Costs:**

```powershell
# Complete cleanup - removes ALL resources
azd down --purge --force

# Verify deletion in Azure Portal
az group list --query "[?contains(name,'rg-az700')].name" -o table
```

⚠️ **Don't forget this step!** Leaving resources running = $109/day charges!

---

## 🆘 **Common Issues & Solutions**

### **Issue 1: Deployment Fails**

**Error**: "Quota exceeded" or "Resource not available"

**Solution**: 
- Choose a different Azure region (try `eastus`, `westus2`, `northeurope`)
- Use Minimal deployment mode to avoid quota issues

```powershell
# Cleanup failed deployment
azd down --purge --force

# Try again with different region
azd up
```

---

### **Issue 2: Can't Find URLs**

**Problem**: Don't know how to access deployed services

**Solution**:
```powershell
# Show ALL environment variables with URLs
azd env get-values

# Or check Azure Portal
az group show --name rg-az700-<your-env-name>
```

---

### **Issue 3: Commands Not Found**

**Error**: "azd: command not found"

**Solution**:
```powershell
# Restart PowerShell to reload PATH
# Then verify:
azd version
az --version

# If still not working, reinstall:
winget install Microsoft.Azd --force
```

---

### **Issue 4: Resource Optimization**

**Question**: How can I optimize my deployment?

**Solution**:
1. **Check what's running**:
   ```powershell
   az resource list --resource-group rg-az700-<your-env-name> -o table
   ```

2. **Redeploy with Minimal mode**:
   ```powershell
   azd down --purge --force
   
   azd up `
     --set deployFirewall=false `
     --set deployBastion=false `
     --set deployRouteServer=false
   ```

3. **Delete immediately after demos**:
   ```powershell
   azd down --purge --force
   ```

---

## 📚 **Next Steps - Go Deeper**

Once you're comfortable with the basics:

1. 📖 **[Full README](README.md)** - Detailed documentation
2. 🏗️ **[Architecture Guide](ARCHITECTURE.md)** - How everything connects
3. 🎬 **[Demo Guide](demoguide/demoguide.md)** - Step-by-step demo walkthroughs
4. ✍️ **[Blog Series](blog/README.md)** - In-depth technical explanations

---

## 🎓 **Training Tips**

### **For Trainers:**

1. **Before Class:**
   - Deploy Minimal or Essential mode 1-2 hours before class
   - Test all URLs and scripts
   - Have Azure Portal open in browser

2. **During Class:**
   - Start with simple demos (AFD, Traffic Manager)
   - Progress to complex scenarios (Route Server, Firewall)
   - Use demo scripts provided in `/scripts` folder

3. **After Class:**
   - Run `azd down --purge --force` SAME DAY
   - Verify deletion in Azure Portal
   - Document any issues for next time

### **For Students:**

1. **Deploy Minimal mode** to learn basics
2. **Follow demo guide** step-by-step
3. **Experiment** with configurations
4. **Clean up immediately** after learning
5. **Use cost alerts** to monitor spending

---

## 🎯 **Success Checklist**

Before you start your demo:

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Azure Developer CLI installed (`azd version`)
- [ ] Chose deployment mode (Minimal/Essential/Full)
- [ ] Deployment completed successfully (15-30 min)
- [ ] Tested AFD URL in browser
- [ ] Tested Traffic Manager URL in browser
- [ ] Demo scripts tested (`.\scripts\Demo-AzureFrontDoor.ps1`)
- [ ] Know how to cleanup (`azd down --purge --force`)
- [ ] Set calendar reminder to delete resources after training!

---

## 💡 **Pro Tips**

1. **Save Money**: Only deploy Full mode when demonstrating advanced features
2. **Speed**: Essential mode deploys faster (15 min vs 30 min)
3. **Reusability**: Keep your `azure.yaml` settings for next time
4. **Documentation**: Take screenshots during first deployment
5. **Automation**: Create PowerShell script for your common deployment mode

**Example saved deployment:**
```powershell
# Save this as deploy-essential.ps1
azd up `
  --set deployBastion=false `
  --set deployFirewall=false `
  --set deployRouteServer=false `
  --set deployExpressRoute=false
```

---

## 🚀 **You're Ready!**

That's it! You now know how to:
- ✅ Deploy the AZ-700 demo environment
- ✅ Choose the right deployment mode
- ✅ Run basic demos
- ✅ Manage costs effectively
- ✅ Clean up resources

**Go deploy and start learning!** 🎓

For more advanced scenarios and detailed explanations, check out the [Full Documentation](README.md) and [Blog Series](blog/README.md).

---

**Questions?** Check the [Full README](README.md) or [Demo Guide](demoguide/demoguide.md)

**Last Updated**: February 5, 2026  
**Difficulty**: Beginner 🌱  
**Time to Deploy**: 15-30 minutes ⏱️  
**Cost**: $25-109/day 💰
