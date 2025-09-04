# Blackwall — Windows Debloat & Setup Wizard

Blackwall is a PowerShell-based utility designed to streamline Windows deployment and post-install configuration. It provides a comprehensive, automated approach for system debloating, privacy hardening, application installation, and system optimization.

---

## Key Features

- **Debloat Windows:** Offers three predefined presets (Minimal, Balanced, Aggressive) and a Barebones option for essential system components only.
- **Privacy & QoL Enhancements:** Disables telemetry, system suggestions, and unnecessary background services to improve security and system responsiveness.
- **Gaming Optimization:** Applies performance-focused tweaks including GPU scheduling, GameDVR configuration, and high-performance power plans.
- **Automated Application Installation:** Supports curated app bundles (Essentials, Browsers, Development Tools, Creators, Gaming, Runtimes) via Winget, with optional manual selection.
- **DryRun Mode:** Allows users to preview all planned changes before execution.
- **Manifest Export/Import:** Records and restores system state and installed packages for consistency across multiple systems or deployments.
- **Logging & Reporting:** Generates detailed logs and JSON summaries for auditing or compliance purposes.

---

## Usage Examples

- **Preview planned changes**
<pre>.\blackwall.ps1 -DryRun</pre>

- **Install only core system utilities (Barebones)**
<pre>.\blackwall.ps1 -Barebones</pre>

- **Full system setup**
<pre>.\blackwall.ps1</pre>

---

## Requirements

- Windows 10 or later
- PowerShell 7 recommended
- Administrative privileges
- Updated Winget package manager

---

## 🔨 Building Blackwall into an EXE

Blackwall is written in PowerShell, but you can package it into a standalone `.exe` for easier distribution using **PS2EXE**.

### Step 1 — Install PS2EXE
Open PowerShell as Administrator and run:
Install-Module -Name ps2exe -Scope CurrentUser

If prompted about untrusted repositories, type Y and hit Enter.

---

### Step 2 — Convert the Script
Navigate to the folder containing `blackwall.ps1` and run:
Invoke-PS2EXE .\blackwall.ps1 .\blackwall.exe

This will generate `blackwall.exe` in the same directory.

---

### Step 3 — Run the EXE
You can now run Blackwall just like any other Windows program:
.\blackwall.exe

⚠️ Note: Antivirus software may flag the EXE because it modifies system components. This is expected due to the nature of what Blackwall does.

---

### Optional — Custom Icon
You can add a custom icon by running:
Invoke-PS2EXE .\blackwall.ps1 .\blackwall.exe -iconFile .\icon.ico

---

## Intended Use

**Blackwall** is designed for IT professionals, system administrators, and power users who need efficient, repeatable Windows setup processes across multiple systems.  

It’s also perfect for casual users who want to streamline their PC experience by removing unnecessary Windows bloat and applying sensible privacy, performance, and QoL tweaks—without diving into complicated manual configurations.

---

## ⚠️ Disclaimer

**Blackwall** performs extensive modifications to Windows that go far beyond simple tweaks. Before running, understand what it does, what it can do, and how it may affect your system.

### What It Does

- **Debloating Windows**  
  Removes preinstalled apps, optional features, and other bloat based on your selected preset (Minimal, Balanced, Aggressive, or Barebones).  
  Expect some system apps to disappear—things like Xbox components, bundled store apps, and unnecessary background services may be removed.

- **Privacy & Telemetry Hardening**  
  Disables Windows telemetry, data collection, system suggestions, Cortana integration, and other background services that may track usage.  
  Some functionality may be limited; for example, certain Windows Store features or live tiles might not work.

- **Performance & Gaming Optimizations**  
  Applies tweaks like GPU scheduling adjustments, high-performance power plans, GameDVR/game mode tweaks, and network optimizations.  
  Expect improved system responsiveness and gaming performance, but some default OS behaviors may be altered.

- **Automated Application Installation**  
  Installs curated application bundles using Winget (Essentials, Browsers, Development Tools, Creators, Gaming, Runtimes).  
  Optional manual selection is available, but some apps may require elevated privileges or user input during installation.

- **System State Management**  
  Supports manifest export/import for installed apps and settings, enabling consistent setup across multiple machines or redeployments.

- **Logging & Auditing**  
  Generates detailed logs and JSON summaries for all actions taken, which can be used for auditing or troubleshooting.

### What to Expect

- Some Windows features may break or behave differently.  
- Certain security software may flag the script due to the nature of system modifications.  
- Running in `-DryRun` mode is strongly recommended to preview all planned changes.  
- Back up important data or create a system restore point before executing.  

### Use at Your Own Risk

While **Blackwall is safe when used responsibly**, it fundamentally alters your system. Users should:

- Review the code themselves to understand every action.  
- Test in a controlled environment (VM or secondary machine) if unsure.  
- Accept that by running Blackwall, they are responsible for all changes applied to their system.

By proceeding, you acknowledge these risks and confirm that you understand the extent of the modifications Blackwall makes.
