<#
    blackwall.ps1 — Windows Debloater + Setup Wizard
    Author: Thrausi
    Purpose:
      - Debloat Windows (Minimal/Balanced/Aggressive)
      - Apply privacy/gaming/QoL tweaks
      - Install apps via winget (bundles + barebones bundle + custom pick)
      - DryRun mode, state persistence, JSON summary + manifest import/export

    Usage examples:
      - Preview only:     .\blackwall.ps1 -DryRun
      - Barebones flow:   .\blackwall.ps1 -Barebones
      - Normal run:       .\blackwall.ps1

    IMPORTANT:
      - Run as Administrator.
      - Keep winget updated; package IDs can change over time.
#>

#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Minimal','Balanced','Aggressive')] [string]$DebloatPreset = 'Balanced',
    [switch]$NoRestorePoint,
    [switch]$Barebones
)

#region --- Bootstrap ---
$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "blackwall - Debloat & Setup"

$Global:RunId     = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:BaseDir   = Join-Path $env:ProgramData "blackwall"
$Global:LogPath   = Join-Path $Global:BaseDir "blackwall_$RunId.log"
$Global:ReportPath= Join-Path $Global:BaseDir "blackwall_Report_$RunId.json"
$Global:StatePath = Join-Path $Global:BaseDir "blackwall_State.json"
$Global:Dry       = [bool]$PSBoundParameters['DryRun']

New-Item -ItemType Directory -Path $Global:BaseDir -Force | Out-Null
Start-Transcript -Path $Global:LogPath -Append | Out-Null

function Write-Info { param($m)  ; Write-Host "[i] $m" -ForegroundColor Cyan }
function Write-Warn { param($m)  ; Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Okay { param($m)  ; Write-Host "[✓] $m" -ForegroundColor Green }
function Write-Do   { param($m)  ; Write-Host "[»] $m" -ForegroundColor Magenta }

function Invoke-LoggedAction {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Action,
        [Parameter(Mandatory=$true)][string]$Description
    )
    Write-Do $Description
    if ($Global:Dry) { Write-Warn "DryRun: skipping: $Description"; return }
    try { & $Action } catch { Write-Warn "Error during: $Description - $($_.Exception.Message)" ; throw }
}

function Save-State { param([object]$Obj)
    try { $Obj | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $Global:StatePath } catch { Write-Warn "Save-State failed: $($_.Exception.Message)" }
}
function Get-State {
    if (Test-Path $Global:StatePath) {
        try { Get-Content $Global:StatePath | ConvertFrom-Json } catch { @{ } }
    } else { @{ } }
}
$state = Get-State
if (-not $state.ContainsKey('LastPreset')) { $state.LastPreset = $DebloatPreset }
if ($Barebones) { $state.Barebones = $true; Save-State $state }

# trackers for report
$InstalledPackages = @()
$FailedPackages = @()
$RemovedPackages = @()
#endregion

#region --- Winget check ---
function Test-WingetPresence {
    try {
        winget --version | Out-Null
        Write-Okay "winget detected."
        return $true
    } catch {
        Write-Warn "winget not found. Opening App Installer store page (best-effort)."
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" -ErrorAction SilentlyContinue
        return $false
    }
}
$HasWinget = Test-WingetPresence
#endregion

#region --- Restore Point ---
function New-SystemRestorePointSafe {
    try {
        if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) { Write-Warn "System Protection may be off; restore point might fail." }
        Invoke-LoggedAction -Action { Checkpoint-Computer -Description "blackwall-$Global:RunId" -RestorePointType MODIFY_SETTINGS } -Description "Create System Restore Point"
        Write-Okay "Restore point attempted."
    } catch { Write-Warn "Restore point failed: $($_.Exception.Message)" }
}
if (-not $NoRestorePoint) { New-SystemRestorePointSafe } else { Write-Warn "Skipping restore point (NoRestorePoint)"; }
#endregion

#region --- Helpers (Appx, Services, Tasks, Registry) ---
function Remove-AppxIfPresent {
    param([string[]]$PackageWildcards)
    foreach ($w in $PackageWildcards) {
        Invoke-LoggedAction -Action {
            try {
                Get-AppxPackage -AllUsers -Name $w -ErrorAction SilentlyContinue | ForEach-Object {
                    $pkg = $_.PackageFullName
                    Remove-AppxPackage -Package $pkg -AllUsers -ErrorAction SilentlyContinue
                    $RemovedPackages += $pkg
                }
                Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $w | ForEach-Object {
                    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
                }
            } catch {}
        } -Description "Removing Appx matching '$w'"
    }
}

function Set-ServiceStartup { param([string]$Name,[string]$StartupType)
    Invoke-LoggedAction -Action { Set-Service -Name $Name -StartupType $StartupType -ErrorAction SilentlyContinue } -Description "Set service '$Name' to $StartupType"
}

function Stop-AndDisableService { param([string]$Name)
    Invoke-LoggedAction -Action { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue; Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue } -Description "Stop & disable service '$Name'"
}

function Disable-ScheduledTask { param([string]$Task)
    Invoke-LoggedAction -Action { schtasks /Change /TN $Task /Disable | Out-Null } -Description "Disable scheduled task '$Task'"
}

function Set-RegistryValue {
    param([string]$Path,[string]$Name,[object]$Value,[Microsoft.Win32.RegistryValueKind]$Type=[Microsoft.Win32.RegistryValueKind]::DWord)
    Invoke-LoggedAction -Action {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
    } -Description "Registry: $Path - $Name = $Value"
}
#endregion

#region --- Debloat lists & logic ---
# Opinionated lists — edit them as you see fit
$BloatMinimal = @(
    "Microsoft.3DBuilder","Microsoft.BingNews","Microsoft.BingWeather","Microsoft.GetHelp","Microsoft.Getstarted",
    "Microsoft.Microsoft3DViewer","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes","Microsoft.MixedReality.Portal","Microsoft.OneConnect","Microsoft.People",
    "Microsoft.SkypeApp","Microsoft.Todos","Microsoft.Wallet","Microsoft.XboxApp","Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider","Microsoft.YourPhone","Microsoft.ZuneMusic","Microsoft.ZuneVideo","Microsoft.WindowsMaps"
)
$BloatBalanced = $BloatMinimal + @(
    "Microsoft.MicrosoftNews","Microsoft.MSPaint","Microsoft.Paint3D","Microsoft.Whiteboard",
    "Microsoft.BingTranslator","Microsoft.PowerAutomateDesktop","Clipchamp.Clipchamp","MicrosoftTeams"
)
$BloatAggressive = $BloatBalanced + @(
    "Microsoft.OneDrive","Microsoft.WindowsAlarms","Microsoft.WindowsFeedbackHub","Microsoft.WindowsCamera"
)

function Invoke-Debloat { param([string]$Preset)
    Write-Info "Debloat preset: $Preset"
    switch ($Preset) {
        'Minimal'   { $list = $BloatMinimal }
        'Balanced'  { $list = $BloatBalanced }
        'Aggressive'{ $list = $BloatAggressive }
        default     { $list = $BloatBalanced }
    }

    Remove-AppxIfPresent -PackageWildcards $list

    # Telemetry / services — conservative defaults, undo available
    Stop-AndDisableService 'DiagTrack'        # Connected User Experiences & Telemetry
    Stop-AndDisableService 'dmwappushservice' # dmwappush (WAP push)
    Set-ServiceStartup 'SysMain' 'Manual'     # SysMain -> Manual to reduce aggressive caching on HDDs

    @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    ) | ForEach-Object { Disable-ScheduledTask $_ }

    # Start menu suggestions off (per-user)
    $exp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-RegistryValue -Path $exp -Name "Start_IrisRecommendations" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-RegistryValue -Path $exp -Name "ShowSyncProviderNotifications" -Value 0

    if ($Preset -eq 'Aggressive') {
        Invoke-LoggedAction -Action { Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue } -Description "Uninstall OneDrive (Aggressive)"
    }

    $state.LastPreset = $Preset; Save-State $state
    Write-Okay "Debloat ($Preset) complete."
}
#endregion

#region --- Tweaks ---
function Set-PrivacyTweaks {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
    Write-Okay "Privacy tweaks applied."
}

function Set-GamingTweaks {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    Invoke-LoggedAction -Action { powercfg -setactive SCHEME_MIN | Out-Null } -Description "Set power plan: High performance"
    Write-Okay "Gaming tweaks applied."
}

function Set-QoLTweaks {
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1
    Invoke-LoggedAction -Action { powercfg -h off } -Description "Disable hibernate"
    Invoke-LoggedAction -Action { Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart } -Description "Enable .NET Framework 3.5"
    Write-Okay "QoL tweaks applied."
}
#endregion

#region --- App Bundles (including Barebones) ---
# Barebones bundle = minimal utilities & runtimes only (no consumer apps)
$BundleBarebones = @(
    "7zip.7zip",
    "Microsoft.VCRedist.2015+.x64",
    "Microsoft.EdgeWebView2Runtime",
    "Microsoft.DotNet.DesktopRuntime.8"
)

$BundleEssentials = @("7zip.7zip","Notepad++.Notepad++","Git.Git","Valve.Steam","Discord.Discord")
$BundleBrowsers  = @("Brave.Brave","LibreWolf.LibreWolf","Google.Chrome","Mozilla.Firefox")
$BundleDev       = @("Microsoft.VisualStudioCode","Python.Python.3.12","Docker.DockerDesktop","JetBrains.Toolbox")
$BundleCreators  = @("OBSProject.OBSStudio","GIMP.GIMP","Inkscape.Inkscape","Audacity.Audacity","BlenderFoundation.Blender")
$BundleGaming    = @("NVIDIA.GeForceExperience","AMD.Software","MSI.Afterburner","Razer.Synapse","EpicGames.EpicGamesLauncher")
$BundleRuntimes  = @("Microsoft.VCRedist.2015+.x64","Microsoft.DotNet.DesktopRuntime.8","Microsoft.DirectX","Microsoft.EdgeWebView2Runtime")

$AllKnownPackages = ($BundleBarebones + $BundleEssentials + $BundleBrowsers + $BundleDev + $BundleCreators + $BundleGaming + $BundleRuntimes) | Select-Object -Unique

function Install-WingetPackage { param([string]$Id)
    if (-not $HasWinget) { Write-Warn "winget missing; skipping $Id"; $FailedPackages += $Id; return }
    Invoke-LoggedAction -Action {
        & winget install --id $Id --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
        $rc = $LASTEXITCODE
        if ($rc -eq 0) { Write-Okay "Installed: $Id"; $InstalledPackages += $Id } else { Write-Warn "winget exit $rc for $Id"; $FailedPackages += $Id }
    } -Description "Installing $Id"
}

function Install-PackageSet { param([string[]]$Ids)
    foreach ($id in $Ids) { Install-WingetPackage -Id $id }
}

function Install-AppsMenu {
    $isBare = ($state.ContainsKey('Barebones') -and $state.Barebones) -or $Barebones
    Write-Host "`n=== App Installation ===" -ForegroundColor Cyan
    Write-Host "1) Essentials"
    Write-Host "2) Browsers"
    Write-Host "3) Dev Tools"
    Write-Host "4) Creator Suite"
    Write-Host "5) Gaming Stack"
    Write-Host "6) Runtimes (VC++, .NET, DirectX)"
    Write-Host "7) Barebones (Minimal runtimes/utilities)"
    Write-Host "8) All of the above (except Barebones)"
    Write-Host "9) Pick individual packages"
    Write-Host "0) Back"
    $choice = Read-Host "Choose"
    switch ($choice) {
        '1' { Install-PackageSet -Ids $BundleEssentials }
        '2' { Install-PackageSet -Ids $BundleBrowsers }
        '3' { Install-PackageSet -Ids $BundleDev }
        '4' { Install-PackageSet -Ids $BundleCreators }
        '5' { Install-PackageSet -Ids $BundleGaming }
        '6' { Install-PackageSet -Ids $BundleRuntimes }
        '7' { Install-PackageSet -Ids $BundleBarebones }
        '8' { Install-PackageSet -Ids ($BundleEssentials + $BundleBrowsers + $BundleDev + $BundleCreators + $BundleGaming + $BundleRuntimes) }
        '9' {
            if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
                $pick = $AllKnownPackages | Out-GridView -Title "Select packages to install (Ctrl/Shift multi-select)" -OutputMode Multiple
                if ($pick) { Install-PackageSet -Ids $pick }
            } else {
                Write-Host "Enter comma-separated winget IDs (examples: Microsoft.VisualStudioCode, Brave.Brave)"
                $manual = Read-Host "IDs"
                if ($manual) { Install-PackageSet -Ids ($manual -split ',\s*') }
            }
        }
        default { return }
    }
}
#endregion

#region --- Manifest export/import & summary ---
function Export-Manifest { param([string]$Path)
    $manifest = @{
        Preset = $state.LastPreset
        Barebones = ($state.ContainsKey('Barebones') -and $state.Barebones)
        Installed = $InstalledPackages
        Failed = $FailedPackages
        Removed = $RemovedPackages
        Timestamp = (Get-Date).ToString("o")
    }
    try { $manifest | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $Path; Write-Okay "Manifest saved to $Path" } catch { Write-Warn "Export failed: $($_.Exception.Message)" }
}

function Import-Manifest { param([string]$Path)
    if (-not (Test-Path $Path)) { Write-Warn "No manifest found at $Path"; return }
    try {
        $m = Get-Content $Path | ConvertFrom-Json
        if ($m.Installed) { Install-PackageSet -Ids $m.Installed }
    } catch { Write-Warn "Import failed: $($_.Exception.Message)" }
}

function Write-SummaryReport {
    $report = @{
        RunId = $Global:RunId
        Preset = $state.LastPreset
        Barebones = ($state.ContainsKey('Barebones') -and $state.Barebones)
        Installed = $InstalledPackages
        Failed = $FailedPackages
        Removed = $RemovedPackages
        Timestamp = (Get-Date).ToString("o")
    }
    try { $report | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $Global:ReportPath; Write-Okay "Report saved: $Global:ReportPath" } catch { Write-Warn "Report save failed: $($_.Exception.Message)" }
    # Print human summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host ("Installed: {0}" -f ($InstalledPackages.Count))
    if ($InstalledPackages) { $InstalledPackages | ForEach-Object { Write-Host "  - $_" } }
    Write-Host ("Failed: {0}" -f ($FailedPackages.Count))
    if ($FailedPackages) { $FailedPackages | ForEach-Object { Write-Host "  - $_" } }
    Write-Host ("Removed Appx: {0}" -f ($RemovedPackages.Count))
}
#endregion

#region --- Undo helpers ---
function Undo-Common {
    Invoke-LoggedAction -Action { Set-Service -Name 'DiagTrack' -StartupType Manual -ErrorAction SilentlyContinue } -Description "Re-enable DiagTrack (Manual)"
    Invoke-LoggedAction -Action { schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Enable | Out-Null } -Description "Enable CEIP task"
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 1
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1
    Invoke-LoggedAction -Action { powercfg -h on } -Description "Enable hibernate"
    Write-Okay "Basic undo applied."
}
#endregion

#region --- Main Menu ---
function Start-MainMenu {
    while ($true) {
        $isBare = ($state.ContainsKey('Barebones') -and $state.Barebones) -or $Barebones
        Write-Host "`n======================" -ForegroundColor Cyan
        Write-Host " blackwall — Debloat & Setup"
        Write-Host (" DryRun: {0}   Barebones: {1}   Log: {2}" -f $Global:Dry, $isBare, $Global:LogPath)
        Write-Host "======================"
        Write-Host "1) Debloat (Preset: $state.LastPreset)"
        Write-Host "2) Apply Privacy Tweaks"
        Write-Host "3) Apply Gaming Tweaks"
        Write-Host "4) Apply QoL Tweaks"
        Write-Host "5) Install Apps"
        Write-Host "6) Change Debloat Preset"
        Write-Host "7) Toggle Barebones Mode (permanent)"
        Write-Host "8) Export manifest of this run"
        Write-Host "9) Undo Common Changes"
        Write-Host "A) Run EVERYTHING (respects Barebones)"
        Write-Host "R) Reboot"
        Write-Host "Q) Quit"
        $choice = Read-Host "Choose"
        switch ($choice.ToUpper()) {
            '1' { Invoke-Debloat -Preset $state.LastPreset }
            '2' { Set-PrivacyTweaks }
            '3' { Set-GamingTweaks }
            '4' { Set-QoLTweaks }
            '5' { Install-AppsMenu }
            '6' {
                $opt = Read-Host "Preset (Minimal/Balanced/Aggressive)"
                if ($opt -in @('Minimal','Balanced','Aggressive')) { $state.LastPreset = $opt; Save-State $state; Write-Okay "Preset set to $opt" } else { Write-Warn "Invalid." }
            }
            '7' {
                $state.Barebones = -not ($state.ContainsKey('Barebones') -and $state.Barebones)
                Save-State $state
                Write-Okay ("Barebones mode now: {0}" -f $state.Barebones)
            }
            '8' {
                $path = Read-Host "Manifest path to save (default in ProgramData): Leave blank for default"
                if (-not $path) { $path = Join-Path $Global:BaseDir "blackwall_Manifest_$Global:RunId.json" }
                Export-Manifest -Path $path
            }
            '9' { Undo-Common }
            'A' {
                Invoke-Debloat -Preset $state.LastPreset
                Set-PrivacyTweaks
                Set-GamingTweaks
                Set-QoLTweaks
                # Respect barebones: if enabled, the installer will offer the barebones bundle OR custom picker
                Install-AppsMenu
                Write-SummaryReport
                Write-Okay "One-click routine finished."
            }
            'R' { if (-not $Global:Dry) { Restart-Computer -Force } else { Write-Warn "DryRun: Not rebooting." } }
            'Q' { break }
            default { Write-Warn "Unknown choice." }
        }
    }
}
#endregion

try {
    Start-MainMenu
} catch {
    Write-Warn "Unexpected error: $($_.Exception.Message)"
} finally {
    Write-SummaryReport
    Stop-Transcript | Out-Null
    Write-Info "Log: $Global:LogPath"
    Save-State $state
}