# maintain-v7.sh v7.7 — System Maintenance & Security Suite

**Author:** Dave Wells  
**Launch Date:** July 2026  
**Compatibility:** Debian/Ubuntu-based Linux (tested on Linux Mint 22.3 "Zena")  
**License:** GPL — Free software, NO WARRANTY. Use at your own risk.

---

## Quick Start

```bash
# Bootstrap on new machine (installs all tools)
./maintain-v7.sh --setup

# Interactive menu
./maintain-v7.sh
```

## Recommended Usage Cadence

| Frequency  | Actions                                              | Menu Options    |
|------------|------------------------------------------------------|-----------------|
| Weekly     | Update, cleanup, temp clear, ClamAV No-PUA, rkhunter | 3, 4, 5, 6b, 7a |
| Monthly    | Full security audit, AIDE check                     | 12, 8           |
| Quarterly  | Vulnerability scan, config export backup             | 22a, 16         |
| As needed  | Hardening changes, recovery key creation              | 9-21, 98        |

---

## Menu Layout Overview

### SETUP

| Option | Description                                                                                                      |
|--------|------------------------------------------------------------------------------------------------------------------|
| 1      | Initial Setup & Configuration Bootstrap (clamav, rkhunter, chkrootkit, aide, lynis, fail2ban, tmpreaper)          |
| 2      | View README (Installation & Config Guide)                                                                         |

### MAINTENANCE

| Option | Description                                                                |
|--------|----------------------------------------------------------------------------|
| 3      | System Update & Upgrade (`apt full-upgrade`)                               |
| 4      | System Cleanup (`apt autoclean`, `autoremove`, journal vacuum)             |
| 5      | Clear Temp Files (protects FUSE mounts like Joplin AppImage)               |

### SECURITY SCANS

| Option | Description                                      |
|--------|--------------------------------------------------|
| 6      | Antivirus Scan & VirusTotal (submenu: 6a-6i)     |
| 7      | Rootkit Detection (submenu: 7a-7c)               |
| 8      | File Integrity Check (AIDE)                      |
| 22     | Vulnerability Scanner (`apt-check`)              |
| 23     | Performance Gear Shift (launches `perf-tune.sh`) |

#### Antivirus Submenu (Option 6)

| Option | Description                                                                |
|--------|----------------------------------------------------------------------------|
| 6a     | ClamAV Deep Scan (Full System + PUA)                                       |
| 6b     | ClamAV Deep Scan (Full System — No PUA) — **Recommended for regular use**  |
| 6c     | ClamAV Quick Scan (Home Directory)                                         |
| 6d     | Update ClamAV Database Only                                                |
| 6e     | Create Scheduled Scan (cron job)                                           |
| 6f     | Remove Scheduled Scan (cron job)                                           |
| 6g     | Query Flagged Files in VirusTotal (hash lookup only)                      |
| 6h     | Update VirusTotal API Key                                                  |
| 6i     | Upload Unknown Files to VirusTotal (4/day free tier limit)                |

#### Rootkit Detection Submenu (Option 7)

| Option | Description                              |
|--------|------------------------------------------|
| 7a     | Rootkit Hunter — Scan Only               |
| 7b     | Rootkit Hunter — Update Baseline + Scan  |
| 7c     | Chkrootkit Scan                          |

### HARDENING

| Option | Description                                          | Score Gain  |
|--------|------------------------------------------------------|-------------|
| 9      | Quick Hardening (Lynis recommendations)               | +10-15 pts  |
| 10     | Password Policy & PAM                                 | +2-3 pts    |
| 11     | Enable Audit Logging (auditd)                         | +2-3 pts    |
| 17     | GRUB Bootloader Password Protection                   | +1 pt       |
| 18     | Advanced Sysctl Hardening (VM-Compatible)             | +2-3 pts    |
| 19     | Auditd Rules Configuration                            | +1 pt       |
| 20     | Process Accounting (sysstat)                          | +1 pt       |
| 21     | Disable Unused Protocols (dccp, sctp, rds, tipc)     | +1 pt       |

**Total Potential Hardening:** +21-27 points

### AUDIT

| Option | Description                                    |
|--------|------------------------------------------------|
| 12     | Security Audit (Lynis with score extraction)   |
| 13     | Fail2Ban Status                                |

### UTILITIES

| Option | Description                               |
|--------|-------------------------------------------|
| 14     | Revert All Hardening Changes              |
| 15     | Run All Maintenance (weekly automation)   |
| 16     | Export Configuration Backup (tarball)     |

### RECOVERY

| Option | Description                              |
|--------|------------------------------------------|
| 98     | Create Live Recovery Key (bootable USB)  |

### EXIT

| Option | Description                        |
|--------|------------------------------------|
| 99     | Exit (always last, never changes)  |

---

## Configuration Files Managed

| Path                                              | Purpose                                    |
|---------------------------------------------------|--------------------------------------------|
| `/etc/rkhunter.conf.d/local.conf`                  | rkhunter whitelists (false positive reduction) |
| `/etc/fail2ban/jail.local`                        | SSH brute-force protection                  |
| `/etc/aide/aide.conf`                              | File integrity monitoring rules             |
| `/var/lib/aide/aide.db`                            | AIDE baseline database                      |
| `/etc/sysctl.d/99-desktop-hardening.conf`          | Kernel hardening (basic)                    |
| `/etc/sysctl.d/99-lumo-hardening.conf`             | Kernel hardening (manual/advanced)          |
| `/etc/sysctl.d/99-lumo-advanced-hardening.conf`     | Kernel hardening (VM-compatible)            |
| `/etc/login.defs`                                  | UMASK, password aging                       |
| `/etc/pam.d/common-password`                       | PAM password quality                        |
| `/etc/issue`                                       | Login banner                                |
| `/etc/issue.net`                                   | Network login banner                        |
| `/etc/grub.d/40_custom_grubauth`                    | GRUB bootloader password                    |
| `/etc/audit/rules.d/hardening.rules`               | Audit monitoring rules                      |
| `/etc/modprobe.d/disable-unused.conf`              | Disabled network protocols                  |
| `/etc/cups/cupsd.conf`                              | CUPS permissions                            |
| `~/.config/maintain/vt-api.conf`                    | VirusTotal API key (perms 0600)             |

---

## Hardening Score Impact (Lynis)

| Score Range | Rating          |
|-------------|-----------------|
| 70-85       | Good            |
| 85+         | Excellent       |
| < 70        | Needs hardening |

---

## GRUB Password Protection

Option 17 sets a GRUB bootloader password.

| Item     | Value                                                                  |
|----------|------------------------------------------------------------------------|
| Username | `root`                                                                 |
| Password | chosen during setup                                                    |
| Config   | `/etc/grub.d/40_custom_grubauth`                                      |
| Recovery | Boot from Recovery Key (Option 98), run `recover.sh`, option 3        |

> ⚠️ **Without the GRUB password, you cannot:** modify boot parameters, boot into recovery mode, or change boot order in GRUB.
>
> **Recommendation:** Create a Recovery Key (Option 98) immediately after setting GRUB password.

---

## Recovery Key (Option 98)

Creates a bootable USB recovery drive containing:

- Critical system config backups
- Automated recovery script (`recover.sh`)
- GRUB password reminder file (`GRUB-PASSWORD-REMINDER.txt`)
- Copy of `maintain-v7.sh`

**Use when:**

- System won't boot
- GRUB password is lost
- Need to restore configs from another system

---

## Backup & Restore

### Backup (Option 16)

```bash
# Creates tarball in script directory
./maintain-v7.sh  # select Option 16
# Output: config-backup-YYYYMMDD-HHMMSS.tar.gz
```

### Restore

```bash
tar xzf config-backup-YYYYMMDD-HHMMSS.tar.gz -C /target/root
cd extracted-configs
sudo ./restore-configs.sh
# Post-restore:
sudo sysctl --system && sudo update-grub
```

---

## Logs

All operations log to `./logs/` with timestamped filenames:

```
logs/
├── initial-setup-20260801-143022.log
├── apt-update-20260801-143500.log
├── clamav-deep-scan-20260801-150000.log
├── rkhunter-scan-20260801-160000.log
├── lynis-audit-20260801-170000.log
└── ...
```

---

## Safety Notes

| Feature              | Note                                                                  |
|----------------------|-----------------------------------------------------------------------|
| AIDE Initialization  | First-run baseline may take 3-10 minutes                               |
| VirusTotal Free Tier | 4 file submissions/day, ~4 queries/minute, 15s delay enforced         |
| GRUB Password        | Cannot be removed without Option 14 or USB Recovery Key               |
| AIDE Exclusions      | `/tmp/.mount_*`, `/var/log`, `/run`, `/dev`, `/proc`, `/sys`, `/mnt`, `/media` |

---

*Stay Secure — Stay Informed*  
Built with care by Dave Wells, July 2026
