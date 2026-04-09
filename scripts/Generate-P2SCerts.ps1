<#
.SYNOPSIS
    Generates self-signed certificates for Azure VPN Gateway Point-to-Site authentication.

.DESCRIPTION
    This script creates:
    1. A self-signed root certificate
    2. A client certificate signed by the root certificate
    3. Exports the root certificate public key in Base64 format (for Azure)
    4. Exports the client certificate with private key (.pfx) for installation on client machines
    
    The generated certificates can be used for testing Azure VPN Gateway Point-to-Site connections.

.PARAMETER RootCertName
    Name of the root certificate. Default: "P2SRootCert"

.PARAMETER ClientCertName
    Name of the client certificate. Default: "P2SClientCert"

.PARAMETER OutputPath
    Path where certificates will be exported. Default: ".\certs"

.PARAMETER ClientCertPassword
    Password for the exported client certificate .pfx file. Default: "P@ssw0rd123!"

.EXAMPLE
    .\Generate-P2SCerts.ps1
    
.EXAMPLE
    .\Generate-P2SCerts.ps1 -RootCertName "MyRootCert" -ClientCertName "MyClientCert" -OutputPath "C:\Certs"
    
.NOTES
    File Name      : Generate-P2SCerts.ps1
    Prerequisite   : PowerShell 5.1 or later, Windows 10 or Windows Server 2016+
    Author         : AZ-700 Demo Environment
    Date           : January 2026
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$RootCertName = "P2SRootCert",

    [Parameter(Mandatory = $false)]
    [string]$ClientCertName = "P2SClientCert",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\certs",

    [Parameter(Mandatory = $false)]
    [SecureString]$ClientCertPassword
)

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "✅ Created output directory: $OutputPath" -ForegroundColor Green
}

# Set default password if not provided
if (-not $ClientCertPassword) {
    $ClientCertPassword = ConvertTo-SecureString -String "P@ssw0rd123!" -Force -AsPlainText
}

Write-Host "`n🔐 Generating P2S VPN Certificates..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Step 1: Create self-signed root certificate
Write-Host "`n📜 Step 1: Creating self-signed root certificate..." -ForegroundColor Yellow
$rootCert = New-SelfSignedCertificate `
    -Type Custom `
    -KeySpec Signature `
    -Subject "CN=$RootCertName" `
    -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 `
    -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsageProperty Sign `
    -KeyUsage CertSign `
    -NotAfter (Get-Date).AddYears(2)

Write-Host "   ✅ Root certificate created: $($rootCert.Thumbprint)" -ForegroundColor Green
Write-Host "   📍 Location: Cert:\CurrentUser\My\$($rootCert.Thumbprint)" -ForegroundColor Gray

# Step 2: Create client certificate signed by root
Write-Host "`n👤 Step 2: Creating client certificate..." -ForegroundColor Yellow
$clientCert = New-SelfSignedCertificate `
    -Type Custom `
    -KeySpec Signature `
    -Subject "CN=$ClientCertName" `
    -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 `
    -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -Signer $rootCert `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") `
    -NotAfter (Get-Date).AddYears(1)

Write-Host "   ✅ Client certificate created: $($clientCert.Thumbprint)" -ForegroundColor Green
Write-Host "   📍 Location: Cert:\CurrentUser\My\$($clientCert.Thumbprint)" -ForegroundColor Gray

# Step 3: Export root certificate public key (Base64 for Azure)
Write-Host "`n📤 Step 3: Exporting root certificate public key..." -ForegroundColor Yellow
$rootCertPath = Join-Path $OutputPath "$RootCertName.cer"
Export-Certificate -Cert $rootCert -FilePath $rootCertPath -Type CERT | Out-Null

# Convert to Base64 format that Azure expects (without headers)
$rootCertBase64 = [System.Convert]::ToBase64String((Get-Content $rootCertPath -AsByteStream -Raw))
$rootCertBase64Path = Join-Path $OutputPath "$RootCertName-base64.txt"
$rootCertBase64 | Out-File -FilePath $rootCertBase64Path -Encoding ascii

Write-Host "   ✅ Root certificate exported:" -ForegroundColor Green
Write-Host "      📄 Binary (.cer): $rootCertPath" -ForegroundColor Gray
Write-Host "      📄 Base64 (for Azure): $rootCertBase64Path" -ForegroundColor Gray

# Step 4: Export client certificate with private key
Write-Host "`n📤 Step 4: Exporting client certificate with private key..." -ForegroundColor Yellow
$clientCertPath = Join-Path $OutputPath "$ClientCertName.pfx"
Export-PfxCertificate -Cert $clientCert -FilePath $clientCertPath -Password $ClientCertPassword | Out-Null

Write-Host "   ✅ Client certificate exported: $clientCertPath" -ForegroundColor Green
Write-Host "   🔑 Password: P@ssw0rd123! (default)" -ForegroundColor Gray

# Step 5: Display summary and next steps
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🎉 Certificate Generation Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n📋 Generated Files:" -ForegroundColor Cyan
Write-Host "   📄 $rootCertPath" -ForegroundColor White
Write-Host "   📄 $rootCertBase64Path" -ForegroundColor White
Write-Host "   📄 $clientCertPath" -ForegroundColor White

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1️⃣  Copy the Base64 content from: $rootCertBase64Path" -ForegroundColor Yellow
Write-Host "   2️⃣  Update azure.yaml parameter 'p2sRootCertData' with the Base64 content" -ForegroundColor Yellow
Write-Host "   3️⃣  Set 'enableP2S: true' in azure.yaml" -ForegroundColor Yellow
Write-Host "   4️⃣  Run: azd up" -ForegroundColor Yellow
Write-Host "   5️⃣  Download VPN client config from Azure Portal" -ForegroundColor Yellow
Write-Host "   6️⃣  Install client certificate ($clientCertPath) on client machine" -ForegroundColor Yellow
Write-Host "   7️⃣  Configure VPN client and connect!" -ForegroundColor Yellow

Write-Host "`n💡 Quick Copy Command:" -ForegroundColor Cyan
Write-Host "   Get-Content '$rootCertBase64Path' | Set-Clipboard" -ForegroundColor White

Write-Host "`n✅ Certificates installed in:" -ForegroundColor Cyan
Write-Host "   📂 Cert:\CurrentUser\My\" -ForegroundColor White
Write-Host "   🔍 View with: certlm.msc (Current User -> Personal -> Certificates)" -ForegroundColor Gray

Write-Host "`n🔗 Azure VPN Gateway P2S Documentation:" -ForegroundColor Cyan
Write-Host "   https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-certificate-gateway" -ForegroundColor Blue

# Display the first 100 characters of Base64 for verification
Write-Host "`n🔍 Base64 Preview (first 100 chars):" -ForegroundColor Cyan
Write-Host "   $($rootCertBase64.Substring(0, [Math]::Min(100, $rootCertBase64.Length)))..." -ForegroundColor Gray

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
