<# 
.SYNOPSIS
Intune Windows Update Patching Detection Script >

.DESCRIPTION
Intune Windows Update Patching Detection Script >

.Demo
YouTube video link--> https://www.youtube.com/@ChanderManiPandey

.OUTPUTS
Script will install latest Security Update >

.Log Location 
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Intune_Patching_Compliance_Log_Current_Date

.NOTES
 Version            :   1.0
 Author             :   Chander Mani Pandey
 Creation Date      :   05 July 2025
 
 Find the author on:
   
 YouTube            :   https://www.youtube.com/@chandermanipandey8763  
 Twitter            :   https://twitter.com/Mani_CMPandey  
 LinkedIn           :   https://www.linkedin.com/in/chandermanipandey  
 BlueSky            :   https://bsky.app/profile/chandermanipandey.bsky.social
 GitHub             :   https://github.com/ChanderManiPandey2022
#>

#===========================   Logging Setup ===========================================
$error.Clear() 
Clear
$ErrorActionPreference = 'Stop' 
Set-ExecutionPolicy -ExecutionPolicy 'Bypass' -Force -ErrorAction 'Stop'

$IntLog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (!(Test-Path -Path $IntLog)) { New-Item -ItemType Directory -Path $IntLog -Force | Out-Null }
$LogPath = "$IntLog\Intune_Patching_Compliance.log"

Function Write-Log {
    Param([string]$Message)
    "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - $Message" | Out-File -FilePath $LogPath -Append
}

Write-Log "====================== Running Intune Patching Detection Script $(Get-Date -Format 'yyyy/MM/dd') ===================="

# =========================== ESP Check ==============================================================
$ESP = Get-Process -ProcessName CloudExperienceHostBroker -ErrorAction SilentlyContinue
If ($ESP) {
    Write-Log "Windows Autopilot ESP Running"
    Write-Log "Exiting Intune Patching Detection Script"
    Write-Host "Exiting Intune Patching Detection Script"
    Exit 1
} Else {
    Write-Log "Windows Autopilot ESP Not Running"
}

$HostName = $env:COMPUTERNAME
Write-Log "Checking if machine $HostName is on the latest cumulative update..."

# =========================== Function to Get Latest Build ============================================
Function Get-LatestWindowsUpdateInfo {
    $currentBuild = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
    $osBuildMajor = $currentBuild.Substring(0, 1)

    $updateUrl = if ($osBuildMajor -eq "2") {
        "https://aka.ms/Windows11UpdateHistory"
    } else {
        "https://support.microsoft.com/en-us/help/4043454"
    }

    $response = if ($PSVersionTable.PSVersion.Major -ge 6) {
        Invoke-WebRequest -Uri $updateUrl -ErrorAction Stop
    } else {
        Invoke-WebRequest -Uri $updateUrl -UseBasicParsing -ErrorAction Stop
    }

    $updateLinks = $response.Links | Where-Object {
        $_.outerHTML -match "supLeftNavLink" -and
        $_.outerHTML -match "KB" -and
        $_.outerHTML -notmatch "Preview" -and
        $_.outerHTML -notmatch "Out-of-band"
    }

    $latest = $updateLinks | Where-Object {
        $_.outerHTML -match $currentBuild
    } | Select-Object -First 1

    if ($latest) {
        $title = $latest.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;', ' - ')
        $kbId  = "KB" + $latest.href.Split('/')[-1]

        [PSCustomObject]@{
            LatestUpdate_Title = $title
            LatestUpdate_KB    = $kbId
        }
    } else {
        Write-Log "No update found for current build."
        Write-Host "No update found for current build."
        exit 1
    }
}

# =========================== Get Latest Update Info =====================================================================
$latestUpdateInfo = Get-LatestWindowsUpdateInfo

# Get current major build (e.g., 19045 or 22621)
$currentMajorBuild = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber

# Extract build string from update title
$buildStringRaw = ($latestUpdateInfo.LatestUpdate_Title -split 'OS Build ')[-1] -replace '[\)\(]', ''
$matchedBuild = ($buildStringRaw -split 'and') | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "$currentMajorBuild*" } | Select-Object -First 1

if (-not $matchedBuild) {
    Write-Log "Could not find matching build from update title: $buildStringRaw"
    Write-Host "Could not find matching build from update title: $buildStringRaw"
    Exit 1
}

try {
    $latestBuild = [version]"10.0.$matchedBuild"
} catch {
    Write-Log "Failed to parse latest build: $matchedBuild"
    Write-Host "Failed to parse latest build: $matchedBuild"
    Exit 1
}

# =========================== Get Current OS Version =========================================================================
try {
    $currentBuildNumber = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    $currentUBR = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
    $currentBuild = [version]"10.0.$currentBuildNumber.$currentUBR"
} catch {
    Write-Log "Failed to get current build or UBR"
    Write-Host "Failed to get current build or UBR"
    Exit 1
}

# =========================== Compare and Output ===============================================
Write-Log "Latest Available Build: $latestBuild"
Write-Log "Current Machine Build: $currentBuild"

if ($currentBuild -ge $latestBuild) {
    Write-Log "Machine is Compliant. Current Build: $currentBuild, Required: $latestBuild"
    Write-Host "Machine is Compliant. Current Build: $currentBuild, Required: $latestBuild"
    Exit 0
} else {
    Write-Log "Machine is NOT Compliant. Current Build: $currentBuild, Required: $latestBuild"
    Write-Log "Remediation required. Triggering Intune remediation if configured."
    Write-Host "Machine is NOT Compliant. Current Build: $currentBuild, Required: $latestBuild"
    Exit 1
}

# =========================== Script End =========================================================




