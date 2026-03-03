<#
.SYNOPSIS
Production-Safe Windows Server Baseline Script

Modes:
1 - Audit Only
2 - Apply Hardening
3 - Restore Baseline Changes
#>

# ==============================
# INITIAL CONFIGURATION
# ==============================

$ErrorActionPreference = "Stop"
$Global:FailureCount = 0
$Global:ChangesApplied = @()

# Define log folder relative to script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFolder = Join-Path $ScriptDir "logs"

# Create Logs folder if it doesn't exist
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

# Log file path
$LogPath = Join-Path $LogFolder "WindowsServerBaseline.log"

Start-Transcript -Path $LogPath -Append

# ==============================
# LOGGING FUNCTION
# ==============================

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    Write-Output $logEntry
    # Add-Content -Path $LogPath -Value $logEntry
}

# ==============================
# SAFE EXECUTION WRAPPER
# ==============================

function Invoke-Safely {
    param(
        [scriptblock]$Action,
        [string]$TaskName,
        [string]$FixSuggestion,
        [string]$ChangeTag
    )

    try {
        & $Action
        Write-Log "$TaskName completed successfully."
        if ($ChangeTag) { $Global:ChangesApplied += $ChangeTag }
    }
    catch {
        $Global:FailureCount++
        Write-Log "$TaskName FAILED. Error: $($_.Exception.Message)" "ERROR"
        Write-Log "Suggested Fix: $FixSuggestion" "WARNING"
    }
}

# ==============================
# ADMIN CHECK
# ==============================

function EnsureAdminRights {
    # Create a WindowsPrincipal object from the current identity
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    # Check if user is in the Administrators group
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Restarting with Administrator privileges..."
        Start-Process powershell.exe -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

EnsureAdminRights

# ==============================
# MODE SELECTION
# ==============================

Write-Host ""
Write-Host "Select Mode:"
Write-Host "1 - Audit Only"
Write-Host "2 - Apply Hardening"
Write-Host "3 - Restore Changes"
$Mode = Read-Host "Enter selection"

# ==============================
# ENVIRONMENT DETECTION
# ==============================

$IsDomainJoined = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
$IsDC = (Get-Service NTDS -ErrorAction SilentlyContinue)

Write-Log "Domain Joined: $IsDomainJoined"
Write-Log "Domain Controller: $([bool]$IsDC)"

# ==============================
# RESTORE MODE
# ==============================

if ($Mode -eq "3") {

    Write-Log "Starting restore mode..."

    Invoke-Safely {
        Enable-ScheduledTask -TaskPath "\Microsoft\Windows\Server Manager\" `
            -TaskName "ServerManager"
    } "Restore Server Manager Startup" "Verify scheduled task exists." "Restore_ServerManager"

    Invoke-Safely {
        Remove-NetFirewallRule -DisplayName "Block Outbound RDP (TCP 3389)" -ErrorAction SilentlyContinue
    } "Remove Custom RDP Block Rule" "Check firewall rules manually." "Restore_RDP"

    Invoke-Safely {
        Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force
    } "Restore SMBv1" "Ensure SMB feature is available." "Restore_SMB"

    Write-Log "Restore completed."
    Stop-Transcript
    exit
}

# ==============================
# AUDIT MODE
# ==============================

if ($Mode -eq "1") {
    Write-Log "Audit Mode Selected."

    Write-Log "SMBv1 Enabled: $((Get-SmbServerConfiguration).EnableSMB1Protocol)"
    Write-Log "RDP Outbound Rule Exists: $([bool](Get-NetFirewallRule -DisplayName 'Block Outbound RDP (TCP 3389)' -ErrorAction SilentlyContinue))"
    Write-Log "Print Spooler Status: $((Get-Service Spooler).Status)"

    Write-Log "Audit completed."
    Stop-Transcript
    exit
}

# ==============================
# HARDENING MODE
# ==============================

Write-Log "Starting hardening mode..."

# Disable Server Manager Startup
Invoke-Safely {
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Server Manager\" `
        -TaskName "ServerManager"
} "Disable Server Manager Startup" "Ensure scheduled task exists." "Disable_ServerManager"

# Disable Print Spooler (if not DC)
if (-not $IsDC) {
    Invoke-Safely {
        Stop-Service Spooler -Force
        Set-Service Spooler -StartupType Disabled
    } "Disable Print Spooler" "Ensure server is not a Print Server." "Disable_Spooler"
}

# Disable SMBv1
Invoke-Safely {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
} "Disable SMBv1" "Check SMB configuration manually." "Disable_SMB"

# Block Outbound RDP
Invoke-Safely {
    if (-not (Get-NetFirewallRule -DisplayName "Block Outbound RDP (TCP 3389)" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -DisplayName "Block Outbound RDP (TCP 3389)" `
            -Direction Outbound `
            -Protocol TCP `
            -LocalPort 3389 `
            -Action Block `
            -Profile Any
    }
} "Block Outbound RDP" "Verify firewall configuration." "Block_RDP"

# NTLM Hardening
Invoke-Safely {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
        -Name LmCompatibilityLevel -Value 5
} "Harden NTLM Settings" "Verify registry path exists." "Harden_NTLM"

# Enable Firewall Logging
Invoke-Safely {
    Set-NetFirewallProfile -Profile Domain,Public,Private `
        -LogBlocked True `
        -LogFileName "%systemroot%\system32\LogFiles\Firewall\pfirewall.log"
} "Enable Firewall Logging" "Verify firewall service is running." "Firewall_Logging"

# Defender Check (only if available)
Invoke-Safely {
    if (Get-Command Set-MpPreference -ErrorAction Stop) {
        Set-MpPreference -DisableRealtimeMonitoring $false
    }
} "Ensure Windows Defender Enabled" "Install Defender feature if missing." "Defender_Enable"

Write-Log "Hardening completed."

# ==============================
# SUMMARY
# ==============================

Write-Log "Script completed with $FailureCount failure(s)."

if ($FailureCount -gt 0) {
    Write-Log "Review log file at $LogPath for details." "WARNING"
}
else {
    Write-Log "All tasks completed successfully."
}

Stop-Transcript
Write-Host ""
Write-Host "Execution finished. Review log at $LogPath"