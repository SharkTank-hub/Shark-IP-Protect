# Shark IP Protect – General Questions & Answers

## ❓ What is Shark IP Protect?

Shark IP Protect is a continuous Windows-based firewall protection system that monitors for malicious activity and automatically blocks dangerous IP addresses. It works alongside Windows Server Hardening to reduce attack surface and strengthen baseline security.

---

## ❓ Will this break my server or hosted services?

No. Shark IP Protect only blocks IP addresses that:

* Appear in your configured threat intelligence lists
* Trigger repeated failed Windows authentication events (Event ID 4625)

It does **not** monitor or block normal application traffic.

---

## ❓ Will this block players on my game server (e.g., DayZ, FiveM, Minecraft)?

No — normal game traffic is not affected.

Game servers such as **DayZ**, **Grand Theft Auto V** (FiveM), or **Minecraft** do not use Windows authentication for player connections. Shark IP Protect only reacts to Windows security events or known malicious IP lists.

Players connecting normally will never be blocked.

---

## ❓ Does it block legitimate users?

No, unless:

* They are actively brute-forcing Windows logins
* Their IP already exists in a malicious IP list
* They repeatedly fail Windows authentication attempts

Normal users, website visitors, API clients, and game players are safe.

---

## ❓ Does this replace my firewall?

No. It enhances it.

Shark IP Protect uses the built-in Windows Advanced Firewall to automatically create block rules. It does not disable or replace native firewall protections.

---

## ❓ Is it safe to run on a production server?

Yes. It is designed for:

* Windows Servers
* Dedicated hosting environments
* VPS instances
* Hybrid setups (web server + game server + RDP)

It runs in a controlled loop and only applies firewall rules when new threats are detected.

---

## ❓ What happens on first run?

On first run:

* Existing IP lists may be applied
* A larger number of firewall rules may be created
* A notification may be sent summarizing blocked IPs

If the list is very large, Discord alerts automatically summarize instead of sending oversized messages.

---

## ❓ Can I test without actually blocking IPs?

Yes. Use Dry Run mode.

Dry Run simulates firewall changes without applying them, allowing you to safely verify behavior before going live.

---

## ❓ Can I whitelist trusted IPs?

Yes. The system can be configured to permanently ignore trusted IPs such as:

* Your home IP
* Management networks
* Monitoring services
* Trusted admin locations

---

## ❓ Does it slow down my server?

No noticeable impact.

* It checks logs at intervals (default 5 minutes)
* Firewall rules are grouped for efficiency
* It does not inspect packet traffic in real time

CPU and memory usage remain minimal.

---

## ❓ What notifications does it support?

Shark IP Protect supports:

* Windows Toast notifications
* Email alerts
* Discord webhook alerts

Notifications include time, date, and blocked IP details.

---

## ❓ Is my data shared anywhere?

No.

All processing happens locally on your server. No telemetry, no cloud processing, no external data sharing.

---

## ❓ What kind of attacks does it protect against?

It is designed to mitigate:

* RDP brute-force attacks
* Windows login brute-force attempts
* Known malicious IP lists
* Automated scanning attempts

---

## ❓ Can this lock me out of my own server?

Only if your own IP repeatedly fails Windows authentication or is in a malicious list.

Best practice:

* Add your IP to a whitelist.
* Use strong credentials.
* Avoid repeated failed login attempts.

---

## ❓ Is this enterprise-grade?

Shark IP Protect is designed with production environments in mind. While lightweight and easy to deploy, it follows defensive security best practices and supports hardened Windows server configurations.

