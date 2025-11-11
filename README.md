# Intune-Scripts-# ===============================
# Detect-LatestWindowsPatch.ps1
# Detection script: verifies if device is on latest patch
# Works with Windows 11 24H2
# ===============================

# Get current build
$CurrentBuild = [int](Get-ComputerInfo).OsBuildNumber

# Define the latest known build for Win11 24H2
# (⚠️ Update this value when new LCUs are released)
$LatestBuild = 26100.4851    # Aug 12, 2025 LCU (KB5064010)

Write-Output "Current build: $CurrentBuild"
Write-Output "Expected build: $LatestBuild"

if ($CurrentBuild -ge $LatestBuild) {
    Write-Output "Compliant: Device is up to date."
    exit 0
} else {
    Write-Output "Not Compliant. Device is missing latest updates."
    exit 1
}


# ===============================
# Remediate-LatestWindowsPatch.ps1
# Remediation script: repairs update components and installs latest LCU
# ===============================

Write-Output "=== Starting Windows Update remediation ==="

# Step 1: Repair OS image
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

# Step 2: Reset Windows Update services & cache
Stop-Service wuauserv, cryptSvc, bits, msiserver -ErrorAction SilentlyContinue
Rename-Item C:\Windows\SoftwareDistribution SoftwareDistribution.old -ErrorAction SilentlyContinue
Rename-Item C:\Windows\System32\catroot2 catroot2.old -ErrorAction SilentlyContinue
Start-Service wuauserv, cryptSvc, bits, msiserver

# Step 3: Ensure .NET 3.5 (common prerequisite)
$netfx = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
if ($netfx.State -ne 'Enabled') {
    DISM /Online /Enable-Feature /FeatureName NetFx3 /All
}

# Step 4: Trigger Windows Update scan & install latest patches
Write-Output "Triggering Windows Update scan..."
try {
    Install-Module PSWindowsUpdate -Force -Scope AllUsers -ErrorAction SilentlyContinue
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
} catch {
    Write-Output "PSWindowsUpdate module not available. Using UsoClient..."
    # Backup method: use UsoClient to trigger scan & install
    Start-Process "UsoClient.exe" ScanInstallWait -NoNewWindow -Wait
}

Write-Output "=== Remediation complete. Reboot may be required. ==="
exit 0

