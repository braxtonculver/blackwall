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

## Intended Use

**Blackwall** is designed for IT professionals, system administrators, and power users who need efficient, repeatable Windows setup processes across multiple systems.  

It’s also perfect for casual users who want to streamline their PC experience by removing unnecessary Windows bloat and applying sensible privacy, performance, and QoL tweaks—without diving into complicated manual configurations.

## ⚠️ Disclaimer

**Blackwall** makes significant modifications to your Windows system, including:

- Removing preinstalled apps and system components  
- Disabling telemetry and background services  
- Tweaking privacy, performance, and gaming settings  
- Installing curated software bundles via Winget  

Because of the extent of these changes, some antivirus software may flag certain actions or scripts as suspicious. While **Blackwall is safe when used as intended**, it fundamentally alters the system in ways that Windows itself might not expect.  

**Use at your own risk.** We strongly recommend:

- Reviewing the PowerShell script before running it  
- Running in `-DryRun` mode first to see what will be changed  
- Backing up important data or creating a system restore point  

By using Blackwall, you acknowledge that you understand these risks and accept responsibility for the changes applied to your system.
