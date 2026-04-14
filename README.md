# 🚀 Azure AZ-700 Networking Demo Environment

> **Complete Azure Networking Demonstration Platform for AZ-700 Certification Training**  
> Production-grade hub-and-spoke architecture with advanced traffic management and security

🏗️ **[Architecture](ARCHITECTURE.md)** | 📖 **[Demo Guide](demoguide/demoguide.md)** | ✍️ **[Blog Series](blog/README.md)** | ⚡ **[Quick Start](quick_guide.md)**

---

## ⚡ **TL;DR - Get Started**

> **New here? Start with the [⚡ Quick Start Guide](quick_guide.md)!**  
> Deploy in 5 minutes | From $25/day | Perfect for beginners

---

## 🎯 **What Is This?**

A comprehensive, production-ready Azure networking environment designed for **AZ-700 certification training**, featuring:

- 🏗️ **Hub-and-Spoke Network Topology** - Enterprise-grade VNet architecture
- 🌐 **Global Traffic Management** - Azure Front Door, Traffic Manager, Application Gateway
- 🔒 **Multi-Layer Security** - Dual WAF, Private Link, NSGs, Azure Firewall
- 🔄 **Dynamic Routing** - Route Server with BGP and NVA integration
- 📊 **Network Monitoring** - VNet Flow Logs, Traffic Analytics, Network Watcher
- 🎛️ **Centralized Management** - Azure Virtual Network Manager (AVNM)

**Perfect for**: Trainers, students, solution architects, and anyone studying AZ-700 exam objectives.

---

## 📚 **Documentation**

| Document | Description | Audience |
|----------|-------------|----------|
| **[⚡ Quick Start](quick_guide.md)** | 5-minute deployment | 🌱 Beginners & Trainers |
| **[🏗️ Architecture](ARCHITECTURE.md)** | Complete diagrams & design | 🔧 Technical Users |
| **[📖 Demo Guide](demoguide/demoguide.md)** | Step-by-step demos | 🎓 All Users |
| **[✍️ Blog Series](blog/README.md)** | 4-part deep dive (12,500+ words) | 📚 Learners |

---

## 🚀 **Deploy Now**

### **Prerequisites**
```bash
# Install tools
winget install Microsoft.AzureCLI
winget install Microsoft.Azd

# Login
az login
azd auth login
```

### **Choose Your Deployment Mode**

```bash
# Clone repository
git clone https://github.com/SQLtattoo/az700env.git
cd az700env
```

Before deploying, edit `infra/main.parameters.json` to set your feature toggles, then:

```powershell
# Deploy — azd will prompt interactively for required parameters
azd up
```

**During `azd up` you will be prompted for:**

| Prompt | Purpose | Example |
|--------|---------|---------|
| `hubLocation` | Primary region — used for hub, spoke1, and workload VNets | `uksouth` |
| `spoke2Location` | Cross-region spoke — **must be different from hub** to demonstrate multi-region routing | `northeurope` |
| `adminPassword` | VM administrator password | *(secure input)* |

> The separate `spoke2Location` prompt is intentional — deploying spoke2 in a different region is a core AZ-700 demo scenario (cross-region VNet peering, Traffic Manager geo-routing, latency-based routing).

#### **💰 Deployment Profiles** (edit `infra/main.parameters.json`)

| Profile | Daily Cost | What to set to `false` |
|---------|-----------|------------------------|
| 🌱 Minimal | ~$25/day | `deployKeyVault`, `deployFirewall`, `deployBastion`, `deployRouteServer`, `deployVpnGateway`, `deployExpressRoute` |
| 🌿 Essential | ~$50/day | `deployFirewall`, `deployBastion` |
| 🌳 Full | ~$109/day | Nothing — deploy everything |

---

## 💰 **Cost Overview**

> ⚠️ **DISCLAIMER**: Costs based on my testing (Feb 2026, UK South/North Europe).  
> Your costs WILL vary. Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/).

| Mode | Daily | Monthly* | Savings |
|------|------|----------|---------|
| **Full 24/7** | $109 | $3,284 | Baseline |
| **Essential 24/7** | $50 | $1,500 | 54% ⬇️ |
| **Minimal 24/7** | $25 | $750 | 77% ⬇️ |
| **Deploy-on-Demand** | Variable | $100 | **97%** ⬇️ ✨ |

*30-day month

### **💡 Top Cost Saver**
> **Use FREE Bastion Developer SKU** instead of Standard!  
> Saves $435/month - Set `deployBastion: false` and deploy free Dev SKU when needed.

**📖 Full cost analysis**: [Blog Part 4](blog/part4-cost-optimization.md)

---

## 🏗️ **What Gets Deployed?**

### **Core Services** (Always)
✅ Hub-and-spoke VNet topology  
✅ VNet peering with gateway transit  
✅ Application Gateway WAF v2  
✅ Traffic Manager (global DNS)  
✅ Azure Virtual Network Manager (AVNM)  
✅ Private Endpoints & DNS Zones  
✅ VNet Flow Logs + Traffic Analytics  

### **Optional Services** (Conditional)
⚙️ Azure Firewall Premium (deployFirewall)  
⚙️ Route Server + BGP NVA (deployRouteServer)  
⚙️ VPN Gateway + P2S (deployVpnGateway / enableP2S)  
⚙️ ExpressRoute demo (deployExpressRoute)  
⚙️ Azure Bastion (deployBastion - use FREE Dev SKU!)  
⚙️ NAT Gateway (deployNatGateway)  

> ⚠️ **Azure Front Door** is currently disabled in the template (App Service Plan quota requirement). Use `infra/deploy-afd-simple.bicep` separately if needed.

---

## 🎬 **Demo Scenarios**

This environment supports all major AZ-700 exam scenarios:

1. **🌐 Global Traffic Management** - Traffic Manager routing
2. **🚀 Multi-Layer Security** - AFD → App Gateway → App Service
3. **🔄 BGP Dynamic Routing** - Route Server with FRRouting
4. **🎛️ Centralized Management** - AVNM network groups
5. **🔥 Azure Firewall** - Network/app rules (optional)
6. **🔌 ExpressRoute** - Enterprise connectivity (demo)
7. **📊 Network Monitoring** - Flow Logs & Traffic Analytics

**📖 Step-by-step instructions**: [Demo Guide](demoguide/demoguide.md)

---

## 🎓 **AZ-700 Exam Coverage**

✅ Design, implement, and manage hybrid networking  
✅ Design and implement core networking infrastructure  
✅ Design and implement routing  
✅ Secure and monitor networks  
✅ Design and implement Private access to Azure Services  

**All exam modules covered!**

---

## 🛠️ **Management Commands**

```bash
# View deployed resources
az resource list --resource-group rg-az700-<env> -o table

# Get environment info (URLs, IPs)
azd env get-values

# Delete everything (stop costs!)
azd down --purge --force

# Redeploy with saved settings
azd up
```

---

## 🔧 **Customization**

All feature toggles and configuration live in `infra/main.parameters.json`. Edit it before running `azd up`:

```json
"deployFirewall":     { "value": false },   // Save $87.50/day
"deployBastion":      { "value": false },   // Save $14.52/day (use FREE Dev SKU)
"deployRouteServer":  { "value": false },   // Save $15.37/day
"deployVpnGateway":   { "value": false },   // Save $13.84/day
"deployExpressRoute": { "value": false },   // Demo only
"enableP2S":          { "value": false }    // Requires deployVpnGateway: true
```

### **🔑 Route Server / BGP NVA (deployRouteServer: true)**

If enabling Route Server, you need to provide your SSH public key in `main.parameters.json` for the BGP NVA VM.

Generate a key pair (run once, keep the private key safe):

```powershell
# Windows / Linux / macOS
ssh-keygen -t rsa -b 4096 -f ~/.ssh/az700-nva
```

Then copy the public key into `main.parameters.json`:

```powershell
Get-Content ~/.ssh/az700-nva.pub
```

Paste the output as the value for `nvaSshPublicKey` in `infra/main.parameters.json`.

To connect to the NVA later:
```powershell
ssh -i ~/.ssh/az700-nva azadmin@<nva-private-ip>
```

**📖 All parameters**: [Architecture - Cost Optimization](ARCHITECTURE.md)

---

## 🆘 **Need Help?**

- 📖 **[Quick Start](quick_guide.md)** - Beginner walkthrough
- 🏗️ **[Architecture](ARCHITECTURE.md)** - Technical deep dive
- 📝 **[Blog Series](blog/README.md)** - Learning resource
- 🐛 **[GitHub Issues](https://github.com/SQLtattoo/az700env/issues)** - Report bugs

---

## 🤝 **Contributing**

Contributions welcome! Submit issues or pull requests on [GitHub](https://github.com/SQLtattoo/az700env).

---

## 📄 **License**

MIT License - Free to use and modify

---

**Built with ❤️ for the Azure community**

*Repository: [github.com/SQLtattoo/az700env](https://github.com/SQLtattoo/az700env)*  
*Last Updated: February 5, 2026*
