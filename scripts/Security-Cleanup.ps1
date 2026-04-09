# Security Cleanup Script - Remove Sensitive Data from Git History
# This script uses git filter-repo to clean sensitive data from all commits

Write-Host "🔒 Git Security Cleanup Script" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$repoPath = "C:\MyWorx\tdd\mytemplates\az700env"
Set-Location $repoPath

# 1. Check if there are uncommitted changes
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️  You have uncommitted changes. Please review:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
    $continue = Read-Host "Do you want to commit these changes first? (Y/N)"
    if ($continue -eq 'Y' -or $continue -eq 'y') {
        git commit -m "security: Remove sensitive data from azure.yaml.template and fix Route Server BGP"
        Write-Host "✅ Changes committed" -ForegroundColor Green
    } else {
        Write-Host "❌ Aborted. Please commit or stash changes first." -ForegroundColor Red
        exit 1
    }
}

# 2. Create backup
Write-Host "📦 Creating backup..." -ForegroundColor Cyan
$backupPath = "C:\MyWorx\tdd\mytemplates\az700env-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').bundle"
git bundle create $backupPath --all
Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
Write-Host ""

# 3. Show commits with sensitive file
Write-Host "📜 Commits containing azure.yaml.template:" -ForegroundColor Cyan
git log --oneline --all -- azure.yaml.template
Write-Host ""

# 4. Confirm action
Write-Host "⚠️  WARNING: This will rewrite git history!" -ForegroundColor Red
Write-Host "   - All commit SHAs will change" -ForegroundColor Yellow
Write-Host "   - You will need to force push to remote" -ForegroundColor Yellow
Write-Host "   - Team members will need to re-clone" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Are you absolutely sure you want to proceed? (type 'YES' to confirm)"

if ($confirm -ne 'YES') {
    Write-Host "❌ Aborted. No changes made." -ForegroundColor Red
    exit 0
}

# 5. Install git-filter-repo if needed
Write-Host ""
Write-Host "🔍 Checking for git-filter-repo..." -ForegroundColor Cyan
$filterRepoPath = Get-Command git-filter-repo -ErrorAction SilentlyContinue
if (-not $filterRepoPath) {
    Write-Host "⚠️  git-filter-repo not found. Installing..." -ForegroundColor Yellow
    pip install git-filter-repo
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install git-filter-repo. Install manually:" -ForegroundColor Red
        Write-Host "   pip install git-filter-repo" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "✅ git-filter-repo is available" -ForegroundColor Green

# 6. Create replacement file
Write-Host ""
Write-Host "📝 Creating replacement patterns..." -ForegroundColor Cyan
$replacements = @"
regex:ssh-rsa AAAAB3NzaC1yc2EAAAA[A-Za-z0-9+/=]+==>[REDACTED_SSH_KEY]
regex:MIIC[A-Za-z0-9+/=]{500,}==>[REDACTED_CERTIFICATE]
"@
$replacements | Out-File -FilePath "$repoPath\replacements.txt" -Encoding UTF8
Write-Host "✅ Replacement patterns created" -ForegroundColor Green

# 7. Run git-filter-repo
Write-Host ""
Write-Host "🧹 Cleaning repository history..." -ForegroundColor Cyan
Write-Host "   This may take a few minutes..." -ForegroundColor Yellow

git filter-repo --replace-text replacements.txt --force

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Repository history cleaned successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ git-filter-repo failed" -ForegroundColor Red
    exit 1
}

# 8. Clean up
Remove-Item replacements.txt -ErrorAction SilentlyContinue

# 9. Verify
Write-Host ""
Write-Host "🔍 Verifying sensitive data is removed..." -ForegroundColor Cyan
$found = git log --all --full-history -- azure.yaml.template | Select-String -Pattern "ssh-rsa AAAAB3NzaC1yc2E|MIIC5zCCAc"
if ($found) {
    Write-Host "⚠️  Sensitive data still found in history!" -ForegroundColor Red
    $found
} else {
    Write-Host "✅ No sensitive data found in history" -ForegroundColor Green
}

# 10. Re-add remote (git-filter-repo removes it for safety)
Write-Host ""
Write-Host "🔗 Re-adding remote origin..." -ForegroundColor Cyan
git remote add origin https://github.com/SQLtattoo/az700env.git
Write-Host "✅ Remote added" -ForegroundColor Green

# 11. Final instructions
Write-Host ""
Write-Host "✅ CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review the changes: git log --oneline -10" -ForegroundColor White
Write-Host "   2. Force push to remote: git push origin main --force" -ForegroundColor White
Write-Host "   3. Rotate your SSH keys and certificates" -ForegroundColor White
Write-Host "   4. Notify team members to re-clone the repository" -ForegroundColor White
Write-Host ""
Write-Host "📦 Backup location: $backupPath" -ForegroundColor Yellow
Write-Host ""
