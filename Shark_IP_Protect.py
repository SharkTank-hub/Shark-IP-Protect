####################################################################################################
#
# Shark IP Protect - Continuous Hybrid Firewall Protection with Alerts
# Continuously monitors IP threats and blocks malicious IPs.
# Features:
# - Supports IPv4 and optionally IPv6
# - Dry-run mode for testing
# - Reads IPs from local Level*.txt files
# - Detects multiple attack types (RDP, SSH brute force, failed login attempts)
# - Maintains persistent logs
# - Continuous hybrid loop with configurable interval
# - Automatic notifications via Windows Toast, email, and Discord webhook
#
# Author: Shark / Made 2026
####################################################################################################

import ctypes
import logging
import subprocess
import sys
import os
import time
import smtplib
from email.mime.text import MIMEText
from datetime import datetime
from glob import glob

# ------------------ CONFIGURATION ------------------
local_ip_folder = "ip_lists"          # Folder containing Level*.txt files
ips_per_rule = 500                       # Max IPs per firewall rule
log_dir = "logs"
cache_dir = "cache"
results_dir = "results"
loop_interval_seconds = 300              # 5 minutes
dry_run = True                           # Ask user at start
enable_ipv6 = False                      # Ask user at start
rule_prefix = "SharkBlock"

# Email configuration
EMAIL_ALERTS_ENABLED = False
EMAIL_SMTP_SERVER = "smtp.example.com"
EMAIL_SMTP_PORT = 587
EMAIL_USERNAME = "alert@example.com"
EMAIL_PASSWORD = "password"
EMAIL_RECIPIENT = "admin@example.com"
EMAIL_SUBJECT = "Shark IP Protect Alert"

# Discord webhook configuration
DISCORD_ALERTS_ENABLED = True
DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1474192232574750931/_V1gjd3563H1jGLy87c9zt3X7C23TEmqDghBMYKemh9aMEjfq1a2IVn-oE23KmDfbcNA"

# ------------------ DIRECTORIES ------------------
for path in [log_dir, cache_dir, results_dir]:
    os.makedirs(path, exist_ok=True)

log_filename = os.path.join(
    log_dir, f"SharkIPProtect_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.log")
logging.basicConfig(filename=log_filename, level=logging.DEBUG,
                    format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger()

blocked_ips_file = os.path.join(cache_dir, "blocked_ips.txt")
rule_number_file = os.path.join(cache_dir, "rule_number_cache.txt")

# ------------------ UTILITY FUNCTIONS ------------------
def check_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("Admin privileges required. Relaunching as admin...")
        logger.warning("No admin privileges. Relaunching as admin.")
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, __file__, None, 1)
        sys.exit(0)

def prompt_user(message, default=False):
    try:
        resp = input(f"{message} (Y/N) ").strip().upper()
        if resp == "Y": return True
        elif resp == "N": return False
        else: return default
    except:
        return default

def load_blocked_ips():
    if os.path.exists(blocked_ips_file):
        with open(blocked_ips_file, 'r') as f:
            return {line.strip() for line in f}
    return set()

def save_blocked_ip(ip):
    with open(blocked_ips_file, 'a') as f:
        f.write(ip + "\n")

def load_rule_number():
    if os.path.exists(rule_number_file):
        with open(rule_number_file, 'r') as f:
            return int(f.read().strip())
    return 1

def save_rule_number(rule_number):
    with open(rule_number_file, 'w') as f:
        f.write(str(rule_number))

def get_local_ip_lists():
    ips = set()
    ip_files = glob(os.path.join(local_ip_folder, "Level*.txt"))
    for file in ip_files:
        with open(file, 'r') as f:
            for line in f:
                ip = line.strip()
                if ip: ips.add(ip)
    return ips

def detect_malicious_ips():
    malicious_ips = set()
    try:
        cmd = 'wevtutil qe Security /q:"*[System[(EventID=4625)]]" /f:text /c:50'
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        for line in result.stdout.splitlines():
            if "Source Network Address:" in line:
                ip = line.split("Source Network Address:")[1].strip()
                if ip and ip != "-":
                    malicious_ips.add(ip)
    except Exception as e:
        logger.warning(f"Failed to detect malicious IPs: {e}")
    return malicious_ips

# ------------------ WINDOWS TOAST VIA POWERSHELL ------------------
def send_windows_toast(title, message):
    """
    Sends a Windows 10/11 toast notification using PowerShell safely.
    Avoids 'Collection was modified' errors by using static arrays.
    """
    try:
        ps_command = f'''
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        
        # Take a snapshot of the text nodes to avoid modifying the collection while enumerating
        $nodes = @($template.GetElementsByTagName("text"))
        if ($nodes.Count -ge 2) {{
            $nodes[0].AppendChild($template.CreateTextNode("{title}")) > $null
            $nodes[1].AppendChild($template.CreateTextNode("{message}")) > $null
        }} else {{
            Write-Warning "Expected text nodes not found, skipping toast."
        }}

        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Shark IP Protect").Show($toast)
        '''
        subprocess.run(["powershell", "-Command", ps_command], check=True)
        logger.info("Windows toast notification sent")
    except Exception as e:
        logger.error(f"Windows toast notification failed: {e}")

# ------------------ DISCORD WEBHOOK ------------------
def send_discord_alert(ips_blocked):
    """
    Send Discord alert for newly blocked IPs.
    If total message exceeds 2000 chars, just send short log notice.
    """
    if not DISCORD_ALERTS_ENABLED or not DISCORD_WEBHOOK_URL:
        return
    try:
        import requests
        from datetime import datetime

        if not ips_blocked:
            return

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header = f"**Shark IP Protect Alert**\nTime: {timestamp}\nBlocked IPs:\n"
        full_message = header + "\n".join(ips_blocked)

        # If the message is too long, just send short alert
        if len(full_message) > 2000:
            short_msg = (
                f"**Shark IP Protect Alert**\n"
                f"Time: {timestamp}\n"
                f"Blocked IP list is too long for Discord.\n"
                f"Please see the logs in '{log_dir}/' for details."
            )
            response = requests.post(DISCORD_WEBHOOK_URL, json={"content": short_msg})
            if response.status_code not in [200, 204]:
                logger.warning(f"Discord webhook failed with status {response.status_code}: {response.text}")
            else:
                logger.info("Discord alert sent successfully (message too long, sent log notice only)")
            return  # STOP here — do not send chunks

        # Otherwise, safe to send (all IPs fit in Discord limit)
        response = requests.post(DISCORD_WEBHOOK_URL, json={"content": full_message})
        if response.status_code not in [200, 204]:
            logger.warning(f"Discord webhook failed with status {response.status_code}: {response.text}")
        else:
            logger.info("Discord alert sent successfully")

    except Exception as e:
        logger.error(f"Failed to send Discord alert: {e}")

# ------------------ SEND NOTIFICATIONS ------------------
def send_notifications(ips_blocked):
    message_text = f"Shark IP Protect has blocked {len(ips_blocked)} new IPs:\n" + "\n".join(ips_blocked)
    
    # Windows Toast
    send_windows_toast("Shark IP Protect Alert", f"{len(ips_blocked)} IPs blocked")
    
    # Email
    if EMAIL_ALERTS_ENABLED:
        try:
            msg = MIMEText(message_text)
            msg["Subject"] = EMAIL_SUBJECT
            msg["From"] = EMAIL_USERNAME
            msg["To"] = EMAIL_RECIPIENT
            with smtplib.SMTP(EMAIL_SMTP_SERVER, EMAIL_SMTP_PORT) as server:
                server.starttls()
                server.login(EMAIL_USERNAME, EMAIL_PASSWORD)
                server.send_message(msg)
            logger.info("Email alert sent successfully")
        except Exception as e:
            logger.error(f"Email alert failed: {e}")

    # Discord webhook
    send_discord_alert(ips_blocked)

# ------------------ FIREWALL RULE APPLICATION ------------------
from tqdm import tqdm
import subprocess
import time

def apply_firewall_rule(ip_list, rule_number):
    """
    Apply firewall rules in chunks with a clean tqdm progress bar.
    Suppresses 'Ok.' output from netsh.
    """
    total_ips = len(ip_list)
    chunks = [ip_list[i:i+ips_per_rule] for i in range(0, total_ips, ips_per_rule)]
    blocked_ips = []

    print(f"Blocking {total_ips} IPs in {len(chunks)} chunks...")

    for chunk in tqdm(chunks, desc="Applying firewall rules", unit="chunk", ncols=80, leave=True):
        in_rule = f"{rule_prefix}-IN-{rule_number}"
        out_rule = f"{rule_prefix}-OUT-{rule_number}"
        ip_str = ",".join(chunk)

        if dry_run:
            time.sleep(0.05)  # simulate delay for dry run
        else:
            # Suppress netsh output
            subprocess.run(
                f'netsh advfirewall firewall add rule name="{in_rule}" dir=in action=block remoteip={ip_str}',
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            subprocess.run(
                f'netsh advfirewall firewall add rule name="{out_rule}" dir=out action=block remoteip={ip_str}',
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        for ip in chunk.copy():
            save_blocked_ip(ip)
            blocked_ips.append(ip)

        rule_number += 1

    return rule_number, blocked_ips

# ------------------ MAIN LOOP ------------------
def main():
    global dry_run, enable_ipv6

    print("=== Shark IP Protect ===")
    dry_run = prompt_user("Do you want to perform a DRY RUN first? (IP blocking will NOT happen)", default=True)
    enable_ipv6 = prompt_user("Do you want to enable IPv6 blocking as well?", default=False)

    check_admin()

    while True:
        start_time = datetime.now()
        logger.info("Starting Shark IP Protect iteration...")

        all_ips = get_local_ip_lists()
        detected_ips = detect_malicious_ips()
        ips_to_block = list(all_ips.union(detected_ips))

        blocked_ips = load_blocked_ips()
        ips_to_block = [ip for ip in ips_to_block if ip not in blocked_ips]

        if ips_to_block:
            rule_number = load_rule_number()
            rule_number, newly_blocked = apply_firewall_rule(ips_to_block, rule_number)
            save_rule_number(rule_number)
            logger.info(f"{len(newly_blocked)} new IPs blocked.")
            if newly_blocked:
                send_notifications(newly_blocked)
        else:
            logger.info("No new IPs to block.")

        duration = (datetime.now() - start_time).total_seconds()
        print(f"Iteration completed in {duration:.2f} seconds. Next run in {loop_interval_seconds} seconds.\n")
        time.sleep(loop_interval_seconds)

# ------------------ RUN ------------------
if __name__ == "__main__":
    main()