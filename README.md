# Shark-IP-Protect

**Author:** Shark
**Version:** 1.0

Shark-IP-Protect is an advanced **Windows firewall protection tool** that continuously monitors and blocks suspicious IP addresses, prevents cyberattacks, and provides real-time notifications. Designed for **Windows Servers and desktops**, it combines **automatic firewall rules**, threat detection, and alerting into one hybrid solution.

---

## Overview

Shark-IP-Protect replaces manual firewall management with **automated protection**. It uses **local threat intelligence files** (`ip_lists/Level*.txt`) and continuously monitors network traffic for attacks.

Key features:

* **Hybrid Continuous Loop**: Runs in the background for real-time protection
* **Multiple Attack Detection**: Brute-force attacks, RDP attacks, port scans, malware C2 communications
* **Dry-Run Mode**: Simulate blocking without modifying firewall rules
* **Optional IPv6 Protection**
* **Automatic Notifications**: Windows toast notifications + optional email alerts
* **Detailed Logging**: Stored in `logs/` and `results/`
* **Persistent Firewall Rules**: Avoid duplicates using cached blocked IPs and rule numbers

---

## Windows Server Hardening

Before running Shark-IP-Protect, it is **highly recommended** to apply the included **Windows Server hardening script**. This ensures your system is secure and optimized for server operations.

### Key Hardening Features

* Disables unnecessary startup tasks and services (print spooler, Bluetooth, UPnP, telemetry)
* Removes Internet Explorer
* Hardened firewall configuration (blocks outbound RDP, logs blocked traffic)
* Disables SMBv1 and insecure protocols
* Enforces Windows Defender and Attack Surface Reduction rules
* Renames default Administrator account and disables Guest
* Optional BitLocker enablement and auditing policies
* Stops unnecessary scheduled tasks and optimizes system bindings

> **Why run hardening first?**
> A hardened baseline ensures firewall rules from Shark-IP-Protect operate effectively and reduces attack surfaces.

---

## Running Shark-IP-Protect

**Do not manually run PowerShell or Python scripts.** Everything is handled via the **batch launcher**.

### Steps

1. **Run the batch launcher as Administrator**:

```cmd
launch_shark_ip_protect.bat
```

2. **Follow the prompts**:

* **Reset Environment**: Optionally clean Python packages and previous cache/logs
* **Fresh Install**: Optionally reinstall required Python packages
* **Dry Run**: Decide if you want to simulate blocking first
* **IPv6 Protection**: Enable optional IPv6 firewall rules

3. The batch script will automatically:

* Check **PowerShell version** and **Python installation**
* Apply **Windows Server hardening** (`WinServer22_Hardening.ps1`)
* Run **Shark-IP-Protect Python script** (`Shark_IP_Protect.py`)
* Create or clean required folders (`logs`, `cache`, `results`) before execution
* Install missing Python packages if requested

4. Shark-IP-Protect will then **monitor traffic continuously** and **block malicious IPs** while providing notifications and logging.

---

## File Structure

```text
Shark-IP-Protect/
│
├─ launch_shark_ip_protect.bat   # Batch launcher (run this as admin)
├─ WinServer22_Hardening.ps1     # Server hardening script (auto-run)
├─ Shark_IP_Protect.py           # Main Python script (auto-run)
├─ ip_lists/                     # Local IP list files (Level1.txt, Level2.txt, etc.)
├─ cache/                        # Cached blocked IPs and firewall rules
├─ logs/                         # Detailed logs of actions
└─ results/                      # Summary reports
```

---

## Alerts

* **Windows Notifications**: Real-time alerts for blocked IPs and detected attacks
* **Email Alerts**: Optional, configurable in the Python script
* **Discord Webhook Alerts**: Optional, configurable in the Python script

---

## Requirements

* **Windows 10 / 11 or Windows Server 2016+**
* **Python 3.9+** installed
* **Administrator privileges** to modify firewall rules

---

## Notes

* Always run **`launch_shark_ip_protect.bat` as Administrator**. The script will attempt to elevate if needed.
* Reset/fresh install cleans old Python packages, cache, and logs.
* Dry run allows testing without changing firewall rules.
* Logs and summaries are saved in:

```text
logs/     # Detailed action logs
results/  # Summary reports
cache/    # Cached blocked IPs and firewall rules
```

---

## Contributing

Shark-IP-Protect is open for contributions. For feature requests, bug reports, or improvements:

* **Discord:** [Shark Tank Community](https://discord.gg/rbBYvN4HR6)
* **Email:** [sharktank.dayz@gmail.com](mailto:sharktank.dayz@gmail.com)

Made with ♥ by **Shark** for the security community.
