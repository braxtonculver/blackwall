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

Suitable for IT professionals, system administrators, and power users who require efficient, repeatable Windows setup processes across multiple systems or deployments.
