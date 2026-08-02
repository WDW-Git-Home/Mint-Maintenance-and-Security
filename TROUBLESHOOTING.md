Troubleshooting — maintain-v7.sh
Common Issues & Solutions
1. AIDE Initialization Timeouts

Symptom:
ERROR: AIDE initialization timed out (600s limit).
Check /etc/aide/aide.conf exclusions.

Cause: Too many files on system, or network mounts hanging the scan.

Fix:
# Reduce timeout or expand exclusions
sudo nano /etc/aide/aide.conf

# Add more exclusions:
!/snap
!/var/cache/apt
!/var/lib/docker  # If Docker installed

# Re-initialize
sudo ./maintain-v7.sh → Option 1 (includes AIDE init)
2. AIDE Permission Denied on /tmp/.mount_*

Symptom:
aide: lstat: Permission denied: /tmp/.mount_JoplinXYZ/

Cause: GUI applications (AppImages) create ephemeral FUSE mounts that AIDE can't traverse.

Fix: Already handled in v7.7 default config (!/tmp/.mount_*). If errors persist:
# Check active mounts
mount | grep /tmp

# Kill offending application
pkill -f joplin

# Retry AIDE check
sudo ./maintain-v7.sh → Option 8
3. ClamAV Database Update Failures

Symptom:
ERROR: Can't assign requested address
freshclam: ERROR: Can't connect to port 80 of mirror db.clamav.net

Cause: Firewall blocking, DNS issues, or IPv6 preference.

Fix:
# Force IPv4 in freshclam config
sudo nano /etc/freshclam.conf
# Add or modify:
DNSLookup no
IPv4 yes

# Restart service
sudo systemctl restart clamav-freshclam

# Manual update
sudo freshclam
4. VirusTotal API Key Not Persisting Under sudo

Symptom:
VirusTotal API Key not found or invalid.

Cause: Script runs under sudo but config path differs.

Fix:
# Verify config location (script uses HOME resolved via SUDO_USER)
ls -la ~/.config/maintain/
sudo ls -la /root/.config/maintain/

# Permissions should be 0600
chmod 600 ~/.config/maintain/vt-api.conf

# Re-enter key via Option 6h
5. apt-check Suite Name Mismatch on Linux Mint

Symptom:
debsecan: Unknown suite 'zena'

Cause: Debian security tracker doesn't recognize Linux Mint codenames.

Fix:
# Script automatically maps Mint → Ubuntu (zena → noble). If mapping fails:

# Manual workaround during scan:
export DEBSECAN_SUITE="noble"
sudo ./maintain-v7.sh → Option 22a
6. GRUB Password Lockout

Symptom: System boots to GRUB password prompt, password forgotten.

Fix: Boot from USB Recovery Key (Option 98):
# From recovery menu:
cd /recovery/scripts
sudo ./recover.sh
# Choice 3: Remove GRUB password only

Alternative (if system boots):
sudo ./maintain-v7.sh → Option 14 (Revert All Hardening)
7. Lynis Score Unexpectedly Low After Hardening

Symptom: Applied all hardening options but score < 70.

Cause: Some hardening checks require reboot to take effect.

Fix:
# After applying hardening, reboot
sudo reboot

# Re-run audit
sudo ./maintain-v7.sh → Option 12
8. Fail2Ban SSH Jail Not Active

Symptom:
Status: 0 total jails, 0 banned IPs.

Cause: Jail configuration not loaded, or sshd log path incorrect.

Fix:
# Check jail status
sudo fail2ban-client status sshd

# Verify jail.local
cat /etc/fail2ban/jail.local

# If missing, recreate via Option 1
sudo ./maintain-v7.sh → Option 1
9. rkhunter False Positives After Software Installation

Symptom:
Warning: File '/usr/bin/newbinary' has been modified

Cause: Legitimate software installation changed file checksums.

Fix:
# Update baseline AFTER verifying change is legitimate
sudo ./maintain-v7.sh → Option 7b (Rootkit Hunter — Update Baseline + Scan)

# Or manually whitelist specific file:
echo 'APP_WHITELIST="/usr/bin/newbinary"' >> /etc/rkhunter.conf.d/local.conf
10. sysctl Settings Not Persisting Across Reboots

Symptom: Hardening applied, but sysctl values reset after reboot.

Cause: /etc/sysctl.d/*.conf files not loaded early enough or overridden.

Fix:
# Verify sysctl drops are in correct directory
ls /etc/sysctl.d/

# Force reload
sudo sysctl --system

# Make sysctl load at early boot (add to /etc/rc.local or initramfs)
echo "sysctl --system" | sudo tee -a /etc/rc.local
chmod +x /etc/rc.local
11. apt list --upgradable Returns Empty on Mint

Symptom: Vulnerability scan shows no security updates, but system clearly needs patches.

Cause: Mint uses different package metadata than Ubuntu.

Fix:
# Use Ubuntu advantage tools directly
sudo ua status

# Or check changelogs manually
apt changelog firefox | grep -i security

# Report as bug if persistent
12. Config Export Missing Files

Symptom: Option 16 shows several files as [MISSING].

Cause: Those hardening modules were never applied (Options 9-21 not executed).

Fix:
# Apply desired hardening first
sudo ./maintain-v7.sh → Options 9, 11, 17-21

# Then re-export
sudo ./maintain-v7.sh → Option 16
Performance Tuning Issues (Option 23 / perf-tune.sh)
13. perf-tune.sh Not Found

Symptom:
Error: perf-tune.sh not found.

Fix:
# Copy perf-tune.sh to same directory as maintain-v7.sh
cp /path/to/perf-tune.sh ./maintain-v7.sh/
chmod +x perf-tune.sh

# Or download latest version
wget https://github.com/davewells/perf-tune.sh
14. Sysctl Profile Causes System Instability

Symptom: After applying "Desktop" or "Aggressive" gear profile, system becomes unresponsive.

Fix:
# Boot into recovery mode
# Mount root filesystem
# Remove sysctl configs
rm /etc/sysctl.d/99-lumo-hardening.conf
rm /etc/sysctl.d/99-lumo-advanced-hardening.conf

# Or use Option 14 to revert all hardening
sudo ./maintain-v7.sh → Option 14
Recovery Procedures
System Won't Boot After Hardening

    Boot from USB Recovery Key (created via Option 98)
    Run:

   cd /recovery/scripts
   sudo ./recover.sh
   ```
3. Choose option 2: Remove all hardening
4. Reboot

### AIDE Database Corrupted

bash
Delete corrupted database

sudo rm /var/lib/aide/aide.db*
Re-initialize

sudo ./maintain-v7.sh → Option 1 (includes AIDE init)

### GRUB Bootloader Broken After Password Set

bash
From live USB, chroot into installed system

sudo mount /dev/sda1 /mnt sudo mount --bind /dev /mnt/dev sudo mount --bind /proc /mnt/proc sudo mount --bind /sys /mnt/sys sudo chroot /mnt
Remove GRUB auth config

rm /etc/grub.d/40_custom_grubauth update-grub exit sudo reboot

---

## Getting Help

| Resource | How to Access |
|----------|---------------|
| Check logs | `ls -lt ./logs/` |
| Review README | `sudo ./maintain-v7.sh → Option 2` |
| Manual tool docs | `man clamscan`, `man rkhunter`, `man lynis` |
| Contact author | Dave Wells |

---

**Legal:** Free software under GPL. NO WARRANTY. Use at your own risk.
