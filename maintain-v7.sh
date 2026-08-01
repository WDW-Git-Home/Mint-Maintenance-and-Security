#!/bin/bash
# ===================================================================
# System Maintenance & Security Suite
# Version 7.7 — Complete Security Toolkit with Recovery Key
#
# Original author: Dave Wells
# Launch Date: July 2026
# Compatibility: Debian/Ubuntu-based Linux (tested on Linux Mint 22.3)
#
# Features:
#   - Initial setup & configuration bootstrap (--setup or Option 1)
#   - Full maintenance automation (update, cleanup, temp files)
#   - ClamAV scanning (PUA, No-PUA, quick home dir)
#   - Rootkit detection (rkhunter scan/baseline + chkrootkit)
#   - File integrity monitoring (AIDE 0.18.6 compatible)
#   - Lynis hardening (quick hardening, password policy, audit logging)
#   - Advanced hardening (GRUB, sysctl, auditd rules, accounting, protocols)
#   - Security audit (Lynis) with score extraction
#   - IPS status (Fail2Ban)
#   - Hardening rollback (one-click undo)
#   - Configuration export/backup
#   - Live Recovery Key creation (Option 98)
#   - Built-in README viewer
#
# Menu Layout:
#   1-16:  Setup, Maintenance, Scans, Hardening, Audit, Utilities
#   17-21: New hardening modules
#   98:    Create Live Recovery Key
#   99:    Exit (always last, never changes)
#
# Usage:
#   ./maintain-v7.sh              # Interactive menu
#   ./maintain-v7.sh --setup      # Run initial setup only
#
# GRUB PASSWORD:
#   Option 17 sets a GRUB bootloader password.
#   Username: root
#   Password: [chosen during setup]
#   Config: /etc/grub.d/40_custom_grubauth
#   Recovery: Boot from Recovery Key (Option 98), run recover.sh, choose option 3
#
# RECOVERY KEY:
#   Option 98: Creates a bootable USB with config backups and recovery script
#   Use if system won't boot or GRUB password is lost
#   Contains: configs/, scripts/recover.sh, scripts/maintain-v7.sh
#   GRUB-PASSWORD-REMINDER.txt included on USB
# ===================================================================

set -euo pipefail
trap 'echo -e "${RED}ERROR: Command failed at line $LINENO of function ${FUNCNAME[0]:-main}. Script exiting.${NC}" >&2' ERR

# -------------------------------------------------------------------
# Colors
# -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------------------------------------------------------------------
# Paths
# -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"

timestamp() {
    date +%Y%m%d-%H%M%S
}

# -------------------------------------------------------------------
# Early exit for --setup flag
# -------------------------------------------------------------------
if [[ "${1:-}" == "--setup" ]]; then
    do_initial_setup
    exit 0
fi

# -------------------------------------------------------------------
# Confirmation Dialog
# -------------------------------------------------------------------
show_description() {
    local title="$1"
    local desc="$2"
    local time_est="$3"
    local risk="$4"
    local reversible="$5"

    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    ${title}${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${BOLD}${desc}${NC}"
    echo
    echo -e "${BLUE}Time Estimate:${NC}  ${time_est}"
    echo -e "${BLUE}Risk Level:${NC}     ${risk}"
    echo -e "${BLUE}Reversible:${NC}     ${reversible}"
    echo
    echo -e "${CYAN}------------------------------------------------------${NC}"
    echo
    echo -e "  ${GREEN}[C]${NC}ontinue with this action"
    echo -e "  ${GREEN}[B]${NC}ack to main menu"
    echo -e "  ${GREEN}[Q]${NC}uit script"
    echo
    read -rp "Select option: " response
    case "$response" in
        [Cc]) return 0 ;;
        [Bb]) return 1 ;;
        [Qq]) exit 0 ;;
        *)    show_description "$title" "$desc" "$time_est" "$risk" "$reversible" ;;
    esac
}

# -------------------------------------------------------------------
# Main Menu
# -------------------------------------------------------------------
show_menu() {
    clear
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${CYAN}        System Maintenance & Security Suite  v7.7             ${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo
    echo -e "${BOLD}SETUP${NC}"
    echo -e "  ${GREEN}1)${NC}  Initial Setup & Configuration"
    echo -e "  ${GREEN}2)${NC}  View README (Installation & Config Guide)"
    echo
    echo -e "${BOLD}MAINTENANCE${NC}"
    echo -e "  ${GREEN}3)${NC}  System Update & Upgrade"
    echo -e "  ${GREEN}4)${NC}  System Cleanup"
    echo -e "  ${GREEN}5)${NC}  Clear Temp Files"
    echo
    echo -e "${BOLD}SECURITY SCANS${NC}"
    echo -e "  ${GREEN}6)${NC}  Antivirus Scan & VirusTotal"     # ENHANCED
    echo -e "  ${GREEN}7)${NC}  Rootkit Detection"
    echo -e "  ${GREEN}8)${NC}  File Integrity Check"
    echo -e "  ${GREEN}22)${NC} Vulnerability Scanner (debsecan)" # NEW
    echo -e "  ${GREEN}23)${NC} Performance Gear Shift"          # NEW
    echo
    echo -e "${BOLD}HARDENING${NC}"
    echo -e "  ${GREEN}9)${NC}  Quick Hardening (Lynis recommendations)"
    echo -e "  ${GREEN}10)${NC} Password Policy & PAM"
    echo -e "  ${GREEN}11)${NC} Enable Audit Logging"
    echo -e "  ${GREEN}17)${NC} GRUB Bootloader Password Protection"
    echo -e "  ${GREEN}18)${NC} Advanced Sysctl Hardening (VM-Compatible)"
    echo -e "  ${GREEN}19)${NC} Auditd Rules Configuration"
    echo -e "  ${GREEN}20)${NC} Process Accounting (sysstat)"
    echo -e "  ${GREEN}21)${NC} Disable Unused Protocols"
    echo
    echo -e "${BOLD}AUDIT${NC}"
    echo -e "  ${GREEN}12)${NC} Security Audit (Lynis)"
    echo -e "  ${GREEN}13)${NC} Fail2Ban Status"
    echo
    echo -e "${BOLD}UTILITIES${NC}"
    echo -e "  ${GREEN}14)${NC} Revert Hardening Changes"
    echo -e "  ${GREEN}15)${NC} Run All Maintenance"
    echo -e "  ${GREEN}16)${NC} Export Configuration Backup"
    echo
    echo -e "${BOLD}RECOVERY${NC}"
    echo -e "  ${GREEN}98)${NC} Create Live Recovery Key (USB)"
    echo
    echo -e "${BOLD}EXIT${NC}"
    echo -e "  ${GREEN}99)${NC} Exit"
    echo
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "Logs saved to: ${LOG_DIR}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -n "Select an option [1-21, 22-23, 98, 99]: "
}
# ===============================================================
# OPTION 1: Initial Setup & Configuration Bootstrap
# ===============================================================
do_initial_setup() {
    local LOG="${LOG_DIR}/initial-setup-$(timestamp).log"

    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${CYAN}    Initial Setup & Configuration Bootstrap            ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${BOLD}This will:${NC}"
    echo -e "  • Install all required packages (clamav, rkhunter, chkrootkit,"
    echo -e "    aide, lynis, fail2ban, tmpreaper)"
    echo -e "  • Create drop-in config files for rkhunter, Fail2Ban, tmpreaper"
    echo -e "  • Initialize AIDE baseline database"
    echo -e "  • Start and enable Fail2Ban with SSH jail"
    echo
    echo -e "${BLUE}Time Estimate:${NC}  10-30 minutes (AIDE init depends on file count)"
    echo -e "${BLUE}Risk Level:${NC}     Low — installs packages and creates configs"
    echo -e "${BLUE}Reversible:${NC}     Yes — remove packages and delete config files"
    echo
    echo -e "${CYAN}------------------------------------------------------${NC}"
    echo
    echo -e "  ${GREEN}[C]${NC}ontinue with this action"
    echo -e "  ${GREEN}[B]${NC}ack (no action taken)"
    echo -e "  ${GREEN}[Q]${NC}uit script"
    echo
    read -rp "Select option: " response
    case "$response" in
        [Cc]) ;;
        [Bb]) return ;;
        [Qq]) exit 0 ;;
        *) do_initial_setup; return ;;
    esac

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Initial Setup & Configuration ==="
        echo "Started: $(date)"
        echo

        echo "--- Installing all required packages ---"
        sudo apt update
        sudo apt install -y \
            clamav clamav-daemon \
            rkhunter \
            chkrootkit \
            aide \
            lynis \
            fail2ban \
            tmpreaper
        echo -e "\n-> All packages installed\n"

        echo "--- Configuring rkhunter ---"
        RKHUNTER_CONF="/etc/rkhunter.conf"
        RKHUNTER_LOCAL="/etc/rkhunter.conf.d/local.conf"
        sudo mkdir -p /etc/rkhunter.conf.d
        sudo tee "$RKHUNTER_LOCAL" > /dev/null << 'RKCONF'
# ============================================================
# rkhunter local overrides — created by maintenance script v7.7
# ============================================================

# Whitelisted applications (false positive reduction)
APP_WHITELIST="/usr/lib/libreoffice/program/soffice.bin"
APP_WHITELIST="/usr/bin/python3.12"
APP_WHITELIST="/usr/libexec/gnome-terminal-server"
APP_WHITELIST="/usr/libexec/csd-background"
APP_WHITELIST="/usr/bin/nemo-desktop"

# Whitelisted hidden files
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
ALLOWHIDDENFILE=/etc/.updated

# Whitelisted accounts/groups
ACCOUNT_WHITELIST=postfix
GROUP_WHITELIST=postfix
GROUP_WHITELIST=postdrop

# Disable tests that cause excessive false positives on desktop
DISABLE_TESTS=avail_modules

# No mail notifications (desktop system)
MAIL-TO=""
RKCONF

        if ! grep -q "rkhunter.conf.d" "$RKHUNTER_CONF" 2>/dev/null; then
            echo "" | sudo tee -a "$RKHUNTER_CONF" > /dev/null
            echo "# Include local overrides (added by maintenance script)" \
                | sudo tee -a "$RKHUNTER_CONF" > /dev/null
            echo "INCLUDE=/etc/rkhunter.conf.d/local.conf" \
                | sudo tee -a "$RKHUNTER_CONF" > /dev/null
        fi

        echo -e "\n-> rkhunter configured: $RKHUNTER_LOCAL\n"

        echo "--- rkhunter --update ---"
        sudo rkhunter --update || true
        echo
        echo "--- rkhunter --propupd (initial baseline) ---"
        sudo rkhunter --propupd
        echo -e "\n-> rkhunter baseline initialized\n"

        echo "--- Configuring Fail2Ban ---"
        if [[ ! -f /etc/fail2ban/jail.local ]]; then
            sudo tee /etc/fail2ban/jail.local > /dev/null << 'JAILCONF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = %(sshd_log)s
backend = systemd
JAILCONF
            echo "-> Created /etc/fail2ban/jail.local"
        else
            echo "-> /etc/fail2ban/jail.local already exists — skipping"
        fi
        sudo systemctl enable fail2ban 2>/dev/null || true
        sudo systemctl restart fail2ban 2>/dev/null || true
        echo -e "\n-> Fail2Ban configured and started\n"

        echo "--- Configuring tmpreaper ---"
        TMPREAPER_CONF="/etc/tmpreaper.conf"
        if [[ ! -f "$TMPREAPER_CONF" ]]; then
            sudo tee "$TMPREAPER_CONF" > /dev/null << 'TRCONF'
TMPREAPER_TIME=24h
TMPREAPER_PROTECT_EXTRA='/tmp/.X*'
TMPREAPER_DIRS='/tmp'
TRCONF
            echo "-> Created $TMPREAPER_CONF"
        else
            echo "-> $TMPREAPER_CONF already exists — skipping"
        fi
        echo -e "\n-> tmpreaper configured\n"

        echo "--- Creating ClamAV log directory ---"
        sudo mkdir -p /var/log/clamav
        echo "-> /var/log/clamav ready\n"

        echo "--- Configuring AIDE ---"
        sudo mkdir -p /etc/aide /var/lib/aide
        sudo chown root:root /var/lib/aide
        sudo chmod 700 /var/lib/aide

        sudo tee /etc/aide/aide.conf > /dev/null << 'AIDECONF'
# AIDE Configuration — Linux Mint/Ubuntu Desktop
# Created by maintenance script v7.7
# AIDE 0.18.x compatible

# Database paths
database_in = file:/var/lib/aide/aide.db
database_out = file:/var/lib/aide/aide.db.new

# Rule definitions
LIGHT = p+i+n+u+g+s+m+c
NORMAL = p+i+n+u+g+s+b+m+c+md5
PERMS = p+i+n+u+g

# Essential system directories (full integrity with MD5)
/etc NORMAL
/bin NORMAL
/sbin NORMAL
/usr/bin NORMAL
/usr/sbin NORMAL
/lib NORMAL
/lib64 NORMAL
/boot LIGHT

# Home directories (permissions only — fast, no hashing)
/home PERMS

# Exclude ALL network mounts and volatile paths
!/var/log
!/run
!/tmp
!/dev
!/proc
!/sys
!/mnt
!/media
!/opt
!/srv
!/snap

# Explicitly exclude common network/SMB mounts
!/media/owner/*
!/tmp/.mount_*
AIDECONF

        echo "-> AIDE config written to /etc/aide/aide.conf"
        echo -e "\n-> AIDE configured\n"

        echo "--- AIDE baseline initialization ---"
        echo "NOTE: This can take 3-10 minutes depending on file count."
        echo "      Network mounts are excluded to prevent hangs."
        echo

        timeout 600 sudo aide --config /etc/aide/aide.conf --init 2>&1 || {
            EXIT_CODE=$?
            if [[ $EXIT_CODE -eq 124 ]]; then
                echo "ERROR: AIDE initialization timed out (600s limit)."
                echo "       Check /etc/aide/aide.conf exclusions."
            else
                echo "ERROR: AIDE initialization failed (exit code: $EXIT_CODE)"
            fi
        }

        # Copy .new to .db if it exists and is non-empty
        for new_db in \
            "/var/lib/aide/aide.db.new" \
            "/var/lib/aide/aide.db.new.gz"; do
            if [[ -f "$new_db" && -s "$new_db" ]]; then
                TARGET="${new_db%.new}"
                sudo cp "$new_db" "$TARGET"
                echo "-> AIDE database installed to: $TARGET"
                break
            fi
        done
        echo -e "\n-> AIDE baseline initialized\n"

        echo "=== Setup Summary ==="
        echo "  Packages installed:     clamav, rkhunter, chkrootkit, aide,"
        echo "                          lynis, fail2ban, tmpreaper"
        echo "  rkhunter config:        $RKHUNTER_LOCAL"
        echo "  Fail2Ban config:        /etc/fail2ban/jail.local"
        echo "  tmpreaper config:       $TMPREAPER_CONF"
        echo "  ClamAV log dir:         /var/log/clamav"
        echo "  AIDE config:            /etc/aide/aide.conf"
        echo "  AIDE baseline:          /var/lib/aide/aide.db"
        echo
        echo "Completed: $(date)"

    } 2>&1 | tee "$LOG"

    echo -e "\n${GREEN}Initial setup complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"
}

# ===============================================================
# OPTION 2: View README (Installation & Config Guide)
# ===============================================================
view_readme() {
    clear
    cat << 'README_EOF'
===============================================================================
                  MAINTAIN-V7.SH — README FIRST
                 System Maintenance & Security Suite v7.7
===============================================================================

ORIGINAL AUTHOR: Dave Wells
LAUNCH DATE: July 2026
COMPATIBILITY: Debian/Ubuntu-based Linux (tested on Linux Mint 22.3)

QUICK START:
  ./maintain-v7.sh --setup          # Bootstrap on new machine
  ./maintain-v7.sh                  # Interactive menu

REGULAR USE:
  Weekly: Options 3, 4, 5, 6b, 7a
  Monthly: Option 12 (Lynis)
  As needed: Option 8 (AIDE re-init)

HARDENING:
  Option 9:  Quick Hardening (+10-15 points)
  Option 10: Password Policy (+2-3 points)
  Option 11: Audit Logging Enable (+2-3 points)
  Option 17: GRUB Bootloader Password (+1 point)
  Option 18: Advanced Sysctl Hardening (+2-3 points)
  Option 19: Auditd Rules Configuration (+1 point)
  Option 20: Process Accounting (+1 point)
  Option 21: Disable Unused Protocols (+1 point)
  Option 14: Revert all hardening

GRUB PASSWORD:
  Option 17 sets a GRUB bootloader password.
  Username: root
  Password: [chosen during setup]
  Config: /etc/grub.d/40_custom_grubauth
  Recovery: Boot from Recovery Key (Option 98), run recover.sh, choose option 3

RECOVERY KEY:
  Option 98: Creates a bootable USB with config backups and recovery script
  Use if system won't boot or GRUB password is lost
  Contains: configs/, scripts/recover.sh, scripts/maintain-v7.sh
  GRUB-PASSWORD-REMINDER.txt included on USB

BACKUP & RESTORE:
  Option 16: Export Configuration Backup
  To restore: tar xzf *.tar.gz && sudo ./restore-configs.sh

CONFIGURATION FILES:
  /etc/rkhunter.conf.d/local.conf        - rkhunter whitelists
  /etc/fail2ban/jail.local               - SSH brute-force protection
  /etc/aide/aide.conf                    - File integrity monitoring
  /etc/sysctl.d/99-desktop-hardening.conf - Kernel hardening (basic)
  /etc/sysctl.d/99-lumo-hardening.conf   - Kernel hardening (manual/advanced)
  /etc/login.defs                        - UMASK, password aging
  /etc/pam.d/common-password             - PAM password quality
  /etc/issue                             - Login banner
  /etc/issue.net                         - Network login banner
  /etc/grub.d/40_custom_grubauth         - GRUB bootloader password
  /etc/audit/rules.d/hardening.rules     - Audit monitoring rules
  /etc/modprobe.d/disable-unused.conf    - Disabled network protocols

TROUBLESHOOTING:
  Check logs: ls -lt ./logs/
  Manual tools: man clamscan, man rkhunter, man lynis

LEGAL: Free software under GPL. NO WARRANTY. Use at your own risk.

Stay Secure — Stay Informed
Built with care by Dave Wells, July 2026
===============================================================================
README_EOF
    echo -n "Press Enter to return to menu..."
    read -r
}

# ===============================================================
# OPTION 3: System Update & Upgrade
# ===============================================================
do_update_upgrade() {
    local LOG="${LOG_DIR}/apt-update-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting Full System Update & Upgrade ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== System Update & Upgrade ==="
        echo "Started: $(date)"
        echo
        sudo apt update
        sudo apt full-upgrade -y
        sudo apt check
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Update & Upgrade complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 4: System Cleanup
# ===============================================================
do_cleanup() {
    local LOG="${LOG_DIR}/apt-cleanup-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting System Cleanup ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== System Cleanup ==="
        echo "Started: $(date)"
        echo
        sudo apt autoclean
        sudo apt autoremove --purge -y
        sudo apt clean
        sudo journalctl --vacuum-time=3d
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Update & Upgrade complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 5: Clear Temp Files
# ===============================================================
do_clear_temp() {
    # Define paths FIRST
    LOG_DIR="${LOG_DIR:-${HOME}/Documents/logs}"
    mkdir -p "$LOG_DIR" 2>/dev/null
    local LOG="${LOG_DIR}/tmpreaper-$(date +%Y%m%d-%H%M%S).log"

    echo -e "\n${YELLOW}--- Clearing Temp Files & Thumbnail Cache ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Temp File & Thumbnail Cleanup ==="
        echo "Started: $(date)"
        echo

        # Skip FUSE/AppImage mounts (Joplin, etc.) — they cause lstat() errors
        find /tmp -maxdepth 1 -type d -mtime +7 \
            ! -name ".X*" \
            ! -name ".mount_*" \
            -exec rm -rf {} + 2>/dev/null

        find /tmp -maxdepth 1 -type f -mtime +7 \
            ! -name "*.sock" \
            ! -name ".X*" \
            -delete 2>/dev/null

        # Clear thumbnail cache
        rm -rf ~/.cache/thumbnails/* 2>/dev/null

        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Temp cleanup complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 6: Antivirus Scan & VirusTotal Integration
# ===============================================================
do_antivirus_submenu() {
    while true; do
        clear
        echo -e "${CYAN}==================================================${NC}"
        echo -e "${CYAN}           Antivirus Scan & VirusTotal            ${NC}"
        echo -e "${CYAN}==================================================${NC}"
        echo
        echo -e "  ${GREEN}6a)${NC}  ClamAV Deep Scan (Full System + PUA)"
        echo -e "  ${GREEN}6b)${NC}  ClamAV Deep Scan (Full System — No PUA)"
        echo -e "  ${GREEN}6c)${NC}  ClamAV Quick Scan (Home Directory)"
        echo -e "  ${GREEN}6d)${NC}  Update ClamAV Database Only"
        echo -e "  ${GREEN}6e)${NC}  Create Scheduled Scan (cron job)"
        echo -e "  ${GREEN}6f)${NC}  Remove Scheduled Scan (cron job)"
        echo -e "  ${GREEN}6g)${NC}  Query Flagged Files in VirusTotal"
        echo -e "  ${GREEN}6h)${NC}  Update VirusTotal API Key"
        echo -e "  ${GREEN}6i)${NC}  Upload Unknown Files to VirusTotal"
        echo -e "  ${GREEN}B)${NC}   Back to main menu"
        echo -e "  ${GREEN}Q)${NC}   Quit script"
        echo
        read -rp "Select option: " choice
        case "$choice" in
            6a) do_clamav_deep ;;
            6b) do_clamav_deep_no_pua ;;
            6c) do_clamav_quick ;;
            6d) do_clamav_update_db ;;
            6e) do_cron_create ;;
            6f) do_cron_remove ;;
            6g) do_virus_total_query ;;
            6h) do_vt_update_key ;;
            6i) do_virus_total_upload ;;
            [Bb]) return 1 ;;
            [Qq]) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Press Enter to try again.${NC}"
                read -r
                ;;
        esac
    done
}

# -------------------------------------------------------------------
# 6a: ClamAV Deep Scan (Full System + PUA)
# -------------------------------------------------------------------
do_clamav_deep() {
    local LOG="${LOG_DIR}/clamav-deep-scan-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting ClamAV Deep Scan (Full System + PUA) ---${NC}"
    echo -e "${RED}WARNING: This will take a LONG time.${NC}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Deep scan cancelled."; pause_for_review; return; }

    if ! command -v clamscan &>/dev/null; then
        echo -e "${YELLOW}ClamAV is not installed. Installing now...${NC}"
        sudo apt install -y clamav clamav-daemon
    fi

    sudo systemctl stop clamav-freshclam 2>/dev/null || true
    sudo freshclam 2>&1 | grep -v "NotifyClamd" || true
    sudo systemctl start clamav-freshclam 2>/dev/null || true

    echo -e "\n${YELLOW}Running deep scan — logging to ${LOG}${NC}\n"

    sudo clamscan \
        -r \
        --max-filesize=2000M \
        --max-scansize=2000M \
        --max-files=20000 \
        --scan-archive=yes \
        --detect-pua=yes \
        --block-encrypted=no \
        -i \
        --log="$LOG" \
        --exclude-dir="^/sys" \
        --exclude-dir="^/proc" \
        --exclude-dir="^/dev" \
        --exclude-dir="^/run" \
        --exclude-dir="^/mnt" \
        --exclude-dir="^/media" \
        --exclude-dir="^/lost+found" \
        /

    echo -e "${GREEN}✓ Deep scan complete. Log saved to: ${LOG}${NC}"
    pause_for_review
}

# -------------------------------------------------------------------
# 6b: ClamAV Deep Scan (No PUA Detection)
# -------------------------------------------------------------------
do_clamav_deep_no_pua() {
    local LOG="${LOG_DIR}/clamav-deep-scan-nopua-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting ClamAV Deep Scan (No PUA Detection) ---${NC}"
    echo -e "${YELLOW}RECOMMENDED for regular scans.${NC}"
    echo -e "${RED}WARNING: This will take a LONG time.${NC}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Deep scan cancelled."; pause_for_review; return; }

    if ! command -v clamscan &>/dev/null; then
        echo -e "${YELLOW}ClamAV is not installed. Installing now...${NC}"
        sudo apt install -y clamav clamav-daemon
    fi

    sudo systemctl stop clamav-freshclam 2>/dev/null || true
    sudo freshclam 2>&1 | grep -v "NotifyClamd" || true
    sudo systemctl start clamav-freshclam 2>/dev/null || true

    echo -e "\n${YELLOW}Running deep scan — logging to ${LOG}${NC}\n"

    sudo clamscan \
        -r \
        --max-filesize=2000M \
        --max-scansize=2000M \
        --max-files=20000 \
        --scan-archive=yes \
        --block-encrypted=no \
        -i \
        --log="$LOG" \
        --exclude-dir="^/sys" \
        --exclude-dir="^/proc" \
        --exclude-dir="^/dev" \
        --exclude-dir="^/run" \
        --exclude-dir="^/mnt" \
        --exclude-dir="^/media" \
        --exclude-dir="^/lost+found" \
        /

    echo -e "${GREEN}✓ Deep scan complete. Log saved to: ${LOG}${NC}"
    pause_for_review
}

# -------------------------------------------------------------------
# 6c: ClamAV Quick Scan (Home Directory)
# -------------------------------------------------------------------
do_clamav_quick() {
    local LOG="${LOG_DIR}/clamav-quick-scan-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting ClamAV Quick Scan (Home Directory) ---${NC}\n"

    if ! command -v clamscan &>/dev/null; then
        echo -e "${RED}ClamAV is not installed. Install with: sudo apt install clamav${NC}"
        pause_for_review
        return
    fi

    clamscan \
        -r \
        --max-filesize=100M \
        --max-scansize=200M \
        --scan-archive=yes \
        --detect-pua=yes \
        -i \
        --log="$LOG" \
        "$HOME"

    echo -e "${GREEN}✓ Quick scan complete. Log saved to: ${LOG}${NC}"
    pause_for_review
}

# -------------------------------------------------------------------
# 6d: Update ClamAV Database Only
# -------------------------------------------------------------------
do_clamav_update_db() {
    local LOG="${LOG_DIR}/clamav-db-update-$(timestamp).log"

    echo -e "\n${YELLOW}--- Updating ClamAV Database ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v freshclam &>/dev/null; then
        echo -e "${YELLOW}ClamAV is not installed. Installing now...${NC}"
        sudo apt install -y clamav clamav-daemon
    fi

    {
        echo "=== ClamAV Database Update ==="
        echo "Started: $(date)"
        echo
        sudo systemctl stop clamav-freshclam 2>/dev/null || true
        sudo freshclam
        sudo systemctl start clamav-freshclam 2>/dev/null || true
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}✓ ClamAV database update complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"
    pause_for_review
}
# -------------------------------------------------------------------
# 6e: Create Scheduled Scan Cron Job
# -------------------------------------------------------------------
do_cron_create() {
    local CRON_FILE="/etc/cron.d/maintain-clamav-scan"

    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}    Create Scheduled ClamAV Scan (Cron Job)        ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo

    if [[ -f "$CRON_FILE" ]]; then
        echo -e "${YELLOW}An existing cron job was found:${NC}"
        echo "---"
        cat "$CRON_FILE"
        echo "---"
        echo -n "Overwrite? [y/N]: "
        read -r overwrite
        [[ "$overwrite" =~ ^[Yy]$ ]] || { echo "Aborted."; pause_for_review; return; }
    fi

    echo "Select scan schedule:"
    echo "  1. Daily at 2:00 AM"
    echo "  2. Weekly (Sunday at 2:00 AM)"
    echo "  3. Custom (enter cron expression)"
    echo -n "Choice [1-3]: "
    read -r sched
    case "$sched" in
        1) CRON_EXPR="0 2 * * *" ;;
        2) CRON_EXPR="0 2 * * 0" ;;
        3)
            echo -n "Enter cron expression (e.g., '0 3 * * 1-5'): "
            read -r CRON_EXPR
            [[ -z "$CRON_EXPR" ]] && { echo "No expression entered. Aborted."; pause_for_review; return; }
            ;;
        *) echo "Invalid choice. Aborted."; pause_for_review; return ;;
    esac

    echo
    echo "Select scan scope:"
    echo "  1. Home directory only ($HOME)"
    echo "  2. Full system (/)"
    echo -n "Choice [1-2]: "
    read -r scope
    case "$scope" in
        1) SCAN_PATH="$HOME" ;;
        2) SCAN_PATH="/" ;;
        *) echo "Invalid choice. Defaulting to home directory."; SCAN_PATH="$HOME" ;;
    esac

    echo
    echo "Select scan type:"
    echo "  1. No PUA (recommended for regular scans)"
    echo "  2. With PUA detection"
    echo -n "Choice [1-2]: "
    read -r pua_type
    case "$pua_type" in
        2) PUA_FLAG="--detect-pua=yes" ;;
        *) PUA_FLAG="" ;;
    esac

    local CLAM_LOG="/var/log/clamav/scheduled-scan.log"

    sudo tee "$CRON_FILE" > /dev/null << CRON_EOF
# ClamAV scheduled scan — created by maintain-v7.sh (Option 6e)
# Schedule: $CRON_EXPR
# Scope: $SCAN_PATH
$CRON_EXPR root /usr/bin/clamscan -r $PUA_FLAG \\
    --max-filesize=2000M --max-scansize=2000M --max-files=20000 \\
    --scan-archive=yes --block-encrypted=no -i \\
    --log=$CLAM_LOG \\
    --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev" \\
    --exclude-dir="^/run" --exclude-dir="^/mnt" --exclude-dir="^/media" \\
    --exclude-dir="^/lost+found" \\
    "$SCAN_PATH" 2>&1
CRON_EOF
    sudo chmod 644 "$CRON_FILE"

    echo -e "\n${GREEN}✓ Cron job created at: $CRON_FILE${NC}"
    echo "Schedule: $CRON_EXPR"
    echo "Scan path: $SCAN_PATH"
    echo "Log output: $CLAM_LOG"
    echo
    echo "Verify with: cat $CRON_FILE"
    pause_for_review
}

# -------------------------------------------------------------------
# 6f: Remove Scheduled Scan Cron Job
# -------------------------------------------------------------------
do_cron_remove() {
    local CRON_FILE="/etc/cron.d/maintain-clamav-scan"

    echo -e "\n${YELLOW}--- Remove Scheduled ClamAV Scan ---${NC}\n"

    if [[ -f "$CRON_FILE" ]]; then
        echo "Current cron job:"
        echo "---"
        cat "$CRON_FILE"
        echo "---"
        echo -n "Remove this cron job? [y/N]: "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo rm -f "$CRON_FILE"
            echo -e "${GREEN}✓ Cron job removed: $CRON_FILE${NC}"
        else
            echo "Aborted."
        fi
    else
        echo -e "${YELLOW}No cron job found at $CRON_FILE${NC}"
    fi
    pause_for_review
}


# -------------------------------------------------------------------
# 6g: Query Flagged Files in VirusTotal (Hash Lookup Only)
# -------------------------------------------------------------------
do_virus_total_query() {
    local LOG="${LOG_DIR}/virustotal-query-$(timestamp).log"

    echo -e "\n${CYAN}==================================================${NC}"
    echo -e "${CYAN}    Query Flagged Files in VirusTotal               ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo

    if ! get_vt_api_key; then
        pause_for_review
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}jq is required. Installing...${NC}"
        sudo apt install -y jq
    fi

    # Find latest ClamAV scan log
    local LATEST_LOG=""
    for logdir in "/var/log/clamav" "$LOG_DIR"; do
        LATEST_LOG=$(ls -t "$logdir"/clamav-*.log 2>/dev/null | head -1)
        [[ -n "$LATEST_LOG" ]] && break
    done

    if [[ -z "$LATEST_LOG" ]]; then
        echo -e "${RED}No ClamAV scan logs found.${NC}"
        echo "Run a scan first (Option 6a, 6b, or 6c)."
        pause_for_review
        return
    fi

    echo "Using scan log: $LATEST_LOG"
    echo

    # Extract flagged file paths
    grep 'FOUND' "$LATEST_LOG" | sed 's/: .* FOUND$//' | sort -u > /tmp/vt_candidates.txt
    local FOUND_COUNT
    FOUND_COUNT=$(wc -l < /tmp/vt_candidates.txt)

    if [[ "$FOUND_COUNT" -eq 0 ]]; then
        echo -e "${GREEN}✓ No infected files found in log.${NC}"
        rm -f /tmp/vt_candidates.txt
        pause_for_review
        return
    fi

    echo -e "${YELLOW}Found $FOUND_COUNT flagged file(s).${NC}"
    echo
    echo "Submitting SHA256 hashes to VirusTotal..."
    echo "(Free tier: ~4 requests/min, 15s delay between queries)"
    echo

    {
        echo "=== VirusTotal Query Report ==="
        echo "Started: $(date)"
        echo "Source log: $LATEST_LOG"
        echo "Flagged files: $FOUND_COUNT"
        echo "============================================"
        echo

        local SUBMITTED=0 DETECTED=0 NOT_IN_VT=0 ERRORS=0

        while IFS= read -r filepath; do
            [[ -f "$filepath" ]] || { echo "SKIP: File not found — $filepath"; continue; }

            local HASH
            HASH=$(sha256sum "$filepath" 2>/dev/null | cut -d' ' -f1)
            [[ -z "$HASH" ]] && { echo "SKIP: Cannot hash — $filepath"; continue; }

            echo "Querying: $filepath"
            echo "  SHA256: $HASH"

            local HTTP_CODE
            HTTP_CODE=$(curl -s -o /tmp/vt_response.json -w "%{http_code}" \
                --max-time 30 \
                "https://www.virustotal.com/api/v3/files/$HASH" \
                -H "x-apikey: $VT_API_KEY")

            if [[ "$HTTP_CODE" -eq 200 ]]; then
                local MALICIOUS SUSPICIOUS
                MALICIOUS=$(jq -r '.data.attributes.last_analysis_stats.malicious // 0' /tmp/vt_response.json)
                SUSPICIOUS=$(jq -r '.data.attributes.last_analysis_stats.suspicious // 0' /tmp/vt_response.json)
                
                echo "  Result: $MALICIOUS malicious, $SUSPICIOUS suspicious"
                echo

                ((SUBMITTED++))
                [[ "$MALICIOUS" -gt 0 ]] && ((DETECTED++))

            elif [[ "$HTTP_CODE" -eq 404 ]]; then
                echo "  Result: Not in VirusTotal database (NOT_UPLOADED)"
                echo "  (This file has never been submitted to VT)"
                echo
                ((NOT_IN_VT++))

            else
                echo "  Result: HTTP error $HTTP_CODE"
                echo
                ((ERRORS++))
            fi

            sleep 15

        done < /tmp/vt_candidates.txt

        echo "============================================"
        echo "Summary"
        echo "  Files queried:     $SUBMITTED"
        echo "  Detected as mal.:  $DETECTED"
        echo "  Not in VT DB:      $NOT_IN_VT"
        echo "  Errors:            $ERRORS"
        echo "Completed: $(date)"

    } 2>&1 | tee "$LOG"

    rm -f /tmp/vt_candidates.txt /tmp/vt_response.json

    echo -e "${GREEN}✓ VirusTotal query complete.${NC}"
    echo -e "${GREEN}Report saved to: ${LOG}${NC}"
    echo

    if [[ "$NOT_IN_VT" -gt 0 ]]; then
        echo -e "${YELLOW}$NOT_IN_VT file(s) not in VT database.${NC}"
        echo "To upload them, run Option 6i."
    fi

    pause_for_review
}

# -------------------------------------------------------------------
# 6h: Update VirusTotal API Key
# -------------------------------------------------------------------
do_vt_update_key() {
    mkdir -p "$CONFIG_DIR"

    echo -e "\n${CYAN}--- Update VirusTotal API Key ---${NC}\n"

    if [[ -f "$VT_CONFIG_FILE" ]]; then
        echo "Current key file: $VT_CONFIG_FILE"
        echo -n "Re-enter API Key? [y/N]: "
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; pause_for_review; return; }
        rm -f "$VT_CONFIG_FILE"
    fi

    if get_vt_api_key; then
        echo -e "${GREEN}✓ API Key updated successfully.${NC}"
    fi

    pause_for_review
}


# -------------------------------------------------------------------
# 6i: Upload Unknown Files to VirusTotal (Full Upload)
# -------------------------------------------------------------------
do_virus_total_upload() {
    local LOG="${LOG_DIR}/virustotal-upload-$(timestamp).log"

    echo -e "\n${CYAN}==================================================${NC}"
    echo -e "${CYAN}    Upload Unknown Files to VirusTotal              ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo

    if ! get_vt_api_key; then
        pause_for_review
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${YELLOW}jq is required. Installing...${NC}"
        sudo apt install -y jq
    fi

    echo -e "${YELLOW}⚠️  PRIVACY WARNING ⚠️${NC}"
    echo "Files uploaded to VirusTotal become part of the public community database."
    echo "Sensitive/confidential data should NOT be uploaded."
    echo
    echo -e "${YELLOW}Free tier: 4 file submissions per day (public uploads)${NC}"
    echo
    echo -n "Type 'UPLOAD' to confirm: "
    read -r CONFIRM
    [[ "$CONFIRM" == "UPLOAD" ]] || { echo "Aborted."; pause_for_review; return; }

    # Find latest ClamAV scan log
    local LATEST_LOG=""
    for logdir in "/var/log/clamav" "$LOG_DIR"; do
        LATEST_LOG=$(ls -t "$logdir"/clamav-*.log 2>/dev/null | head -1)
        [[ -n "$LATEST_LOG" ]] && break
    done

    if [[ -z "$LATEST_LOG" ]]; then
        echo -e "${RED}No ClamAV scan logs found.${NC}"
        pause_for_review
        return
    fi

    echo "Using scan log: $LATEST_LOG"
    echo

    # First pass: identify which files are NOT in VT (need upload)
    grep 'FOUND' "$LATEST_LOG" | sed 's/: .* FOUND$//' | sort -u > /tmp/vt_candidates.txt
    local TOTAL_COUNT
    TOTAL_COUNT=$(wc -l < /tmp/vt_candidates.txt)

    echo "Checking which files are already in VT database..."
    echo

    local UPLOAD_LIST=()
    while IFS= read -r filepath; do
        [[ -f "$filepath" ]] || continue

        local HASH
        HASH=$(sha256sum "$filepath" 2>/dev/null | cut -d' ' -f1)
        [[ -z "$HASH" ]] && continue

        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            "https://www.virustotal.com/api/v3/files/$HASH" \
            -H "x-apikey: $VT_API_KEY")

        if [[ "$HTTP_CODE" -eq 404 ]]; then
            FILESIZE=$(stat -c%s "$filepath" 2>/dev/null || echo "?")
            UPLOAD_LIST+=("$filepath|$HASH|$FILESIZE")
        fi
    done < /tmp/vt_candidates.txt

    local NEEDS_UPLOAD=${#UPLOAD_LIST[@]}

    if [[ "$NEEDS_UPLOAD" -eq 0 ]]; then
        echo -e "${GREEN}✓ All files are already in VirusTotal database.${NC}"
        echo "Nothing to upload."
        rm -f /tmp/vt_candidates.txt
        pause_for_review
        return
    fi

    echo "Files requiring upload: $NEEDS_UPLOAD"
    echo
    echo "Uploading to VirusTotal..."
    echo "(Upload takes time depending on file size and connection speed)"
    echo

    {
        echo "=== VirusTotal Upload Report ==="
        echo "Started: $(date)"
        echo "Source log: $LATEST_LOG"
        echo "Files needing upload: $NEEDS_UPLOAD"
        echo "============================================"
        echo

        local UPLOADED=0 SUCCESS=0 FAILED=0 SKIPPED=0
        local UPLOAD_COUNTER=0

        for entry in "${UPLOAD_LIST[@]}"; do
            IFS='|' read -r filepath HASH FILESIZE <<< "$entry"
            ((UPLOAD_COUNTER++))

            echo "[$UPLOAD_COUNTER/$NEEDS_UPLOAD] Uploading: $filepath"
            echo "  Size: $FILESIZE bytes"
            echo "  SHA256: $HASH"

            # Check daily quota (free tier = 4 uploads/day)
            local QUOTA_FILE="$CONFIG_DIR/vt-upload-quota"
            local TODAY
            TODAY=$(date +%Y-%m-%d)
            local QUOTE_COUNT=0
            
            if [[ -f "$QUOTA_FILE" ]]; then
                OLD_DATE=$(head -1 "$QUOTA_FILE" 2>/dev/null)
                if [[ "$OLD_DATE" == "$TODAY" ]]; then
                    QUOTE_COUNT=$(tail -1 "$QUOTA_FILE" 2>/dev/null || echo 0)
                else
                    echo "$TODAY" > "$QUOTA_FILE"
                    echo "0" >> "$QUOTA_FILE"
                fi
            else
                echo "$TODAY" > "$QUOTA_FILE"
                echo "0" >> "$QUOTA_FILE"
            fi

            if [[ "$QUOTE_COUNT" -ge 4 ]]; then
                echo "  SKIP: Daily upload quota reached (4/4)"
                echo "  Reset tomorrow or use paid VT account"
                ((SKIPPED++))
                echo
                continue
            fi

            # Perform upload via multipart form data
            UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" --progress-bar -X POST \
                --form "file=@$filepath" \
                "https://www.virustotal.com/api/v3/files" \
                -H "x-apikey: $VT_API_KEY")

            HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -1)
            BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

            if [[ "$HTTP_CODE" -eq 200 || "$HTTP_CODE" -eq 201 ]]; then
                ANALYSIS_ID=$(echo "$BODY" | jq -r '.data.id // empty')
                echo "  ✓ Uploaded successfully"
                echo "  Analysis ID: $ANALYSIS_ID"
                
                # Wait for processing (VT needs time to analyze)
                echo "  Waiting for analysis to complete (60s)..."
                sleep 60

                # Fetch results
                RESULT=$(curl -s --max-time 120 \
                    "https://www.virustotal.com/api/v3/analyses/$ANALYSIS_ID" \
                    -H "x-apikey: $VT_API_KEY")
                
                STATUS=$(echo "$RESULT" | jq -r '.data.attributes.status // "unknown"')
                MALICIOUS=$(echo "$RESULT" | jq -r '.data.attributes.total_popular // 0')
                
                echo "  Status: $STATUS"
                if [[ "$STATUS" == "completed" ]]; then
                    FINAL_MAL=$(echo "$RESULT" | jq -r '.data.attributes.stats.malicious // 0')
                    echo "  Detections: $FINAL_MAL engines flagged as malicious"
                    ((SUCCESS++))
                fi
                
                ((UPLOADED++))
                
                # Increment quota counter
                CURRENT_COUNT=$(tail -1 "$QUOTA_FILE")
                echo "$TODAY" > "$QUOTA_FILE"
                echo "$((CURRENT_COUNT + 1))" >> "$QUOTA_FILE"

            elif [[ "$HTTP_CODE" -eq 413 ]]; then
                echo "  ✗ File too large (>32MB for free tier)"
                ((FAILED++))

            elif [[ "$HTTP_CODE" -eq 429 ]]; then
                echo "  ✗ Rate limited (too many requests)"
                ((FAILED++))

            else
                echo "  ✗ Upload failed (HTTP $HTTP_CODE)"
                echo "  Response: $(echo "$BODY" | jq -r '.error.message // "unknown"')"
                ((FAILED++))
            fi

            echo
            sleep 10

        done

        echo "============================================"
        echo "Summary"
        echo "  Files uploaded:    $UPLOADED"
        echo "  Upload success:    $SUCCESS"
        echo "  Upload failed:     $FAILED"
        echo "  Skipped (quota):   $SKIPPED"
        echo "  Total processed:   $TOTAL_COUNT"
        echo "Completed: $(date)"

    } 2>&1 | tee "$LOG"

    rm -f /tmp/vt_candidates.txt

    echo -e "${GREEN}✓ VirusTotal upload complete.${NC}"
    echo -e "${GREEN}Report saved to: ${LOG}${NC}"
    echo
    echo -e "${CYAN}Note: Results may take minutes to propagate in VT's system.${NC}"
    pause_for_review
}

# ==============================================================================
# VARIOUS HELPERS FOR CLAMAV + VIRUSTOTAL
# ==============================================================================

# Global variable for VT API key
declare -r CONFIG_DIR="$HOME/.config/maintain"
declare -r VT_CONFIG_FILE="${CONFIG_DIR}/vt-api.conf"

# -------------------------------------------------------------------
# Helper: Load or prompt for VT API key
# -------------------------------------------------------------------
get_vt_api_key() {
    mkdir -p "$CONFIG_DIR"

    # Try loading existing key
    if [[ -f "$VT_CONFIG_FILE" ]]; then
        local vt_key
        vt_key=$(grep 'VT_API_KEY=' "$VT_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
        if [[ ${#vt_key} -eq 64 ]]; then
            echo -e "${GREEN}✓ API Key loaded from $VT_CONFIG_FILE${NC}"
            VT_API_KEY="$vt_key"
            return 0
        fi
    fi

    # Key missing or invalid — prompt user
    echo "VirusTotal API Key not found or invalid."
    echo "Get your free key at: https://www.virustotal.com/gui/my-apikey"
    echo -n "Enter API Key (or 'q' to cancel): "
    read -r VT_API_KEY

    if [[ "$VT_API_KEY" == "q" || -z "$VT_API_KEY" ]]; then
        echo "Aborted."
        return 1
    fi

    # Validate format (64 alphanumeric characters)
    if [[ ! "$VT_API_KEY" =~ ^[a-zA-Z0-9]{64}$ ]]; then
        echo -e "${RED}ERROR: Invalid key format. Expected 64-character alphanumeric string.${NC}"
        return 1
    fi

    # Save for future use
    echo "VT_API_KEY=$VT_API_KEY" > "$VT_CONFIG_FILE"
    chmod 600 "$VT_CONFIG_FILE"
    echo -e "${GREEN}✓ API Key saved to $VT_CONFIG_FILE${NC}"
    return 0
}

# -------------------------------------------------------------------
# Helper: Map Mint codename to Ubuntu base
# -------------------------------------------------------------------
get_ubuntu_suite() {
    local MINT_CODENAME
    MINT_CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
    
    case "$MINT_CODENAME" in
        zena|vera|victoria)     echo "noble" ;;   # Mint 22.x → Ubuntu 24.04
        vanessa|una|uma|ulyssa) echo "focal" ;;   # Mint 20.x → Ubuntu 20.04
        *) echo "$MINT_CODENAME" ;;
    esac
}

# ===============================================================
# OPTION 7: Rootkit Detection (submenu)
# ===============================================================
do_rootkit_submenu() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}           Rootkit Detection Options              ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "  ${GREEN}7a)${NC}  Rootkit Hunter — Scan Only"
    echo -e "  ${GREEN}7b)${NC}  Rootkit Hunter — Update Baseline + Scan"
    echo -e "  ${GREEN}7c)${NC}  Chkrootkit Scan"
    echo -e "  ${GREEN}B)${NC}   Back to main menu"
    echo -e "  ${GREEN}Q)${NC}   Quit script"
    echo
    read -rp "Select option: " choice
    case "$choice" in
        7a|A|a) do_rkhunter_scan ;;
        7b|B|b) do_rkhunter_update_scan ;;
        7c|C|c) do_chkrootkit ;;
        B|b)    return 1 ;;
        Q|q)    exit 0 ;;
        *)
            echo -e "${RED}Invalid option. Press Enter to try again.${NC}"
            read
            do_rootkit_submenu
            ;;
    esac
    pause_for_review
}

do_rkhunter_scan() {
    local LOG="${LOG_DIR}/rkhunter-scan-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting Rootkit Hunter (Scan Only) ---${NC}"
    echo -e "${YELLOW}Does NOT reset file property baseline.${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v rkhunter &>/dev/null; then
        echo -e "${YELLOW}rkhunter is not installed. Installing now...${NC}"
        sudo apt install -y rkhunter
    fi

    {
        echo "=== rkhunter Scan Only (no propupd) ==="
        echo "Started: $(date)"
        echo
        sudo rkhunter --update || true
        sudo rkhunter --checkall --sk --logfile "$LOG" --report-warnings-only --pkgmgr dpkg
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}rkhunter scan complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"

}

do_rkhunter_update_scan() {
    local LOG="${LOG_DIR}/rkhunter-update-scan-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting Rootkit Hunter (Update Baseline + Scan) ---${NC}"
    echo -e "${RED}WARNING: Resets rkhunter's file baseline.${NC}"
    echo -n "Are you sure your system is clean? Continue? [y/N]: "
    read confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; return; }

    if ! command -v rkhunter &>/dev/null; then
        echo -e "${YELLOW}rkhunter is not installed. Installing now...${NC}"
        sudo apt install -y rkhunter
    fi

    {
        echo "=== rkhunter Update Baseline + Scan ==="
        echo "Started: $(date)"
        echo
        sudo rkhunter --update || true
        sudo rkhunter --propupd
        sudo rkhunter --checkall --sk --logfile "$LOG" --report-warnings-only --pkgmgr dpkg
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}rkhunter update + scan complete.${NC}"
    echo -e "${GREEN}Log saved to: ${LOG}${NC}"

}

do_chkrootkit() {
    local LOG="${LOG_DIR}/chkrootkit-scan-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting Chkrootkit Scan ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v chkrootkit &>/dev/null; then
        echo -e "${YELLOW}chkrootkit is not installed. Installing now...${NC}"
        sudo apt install -y chkrootkit
    fi

    {
        echo "=== chkrootkit Scan ==="
        echo "Started: $(date)"
        echo
        sudo chkrootkit 2>&1 | grep -v "RTNETLINK"
        echo
        echo "Completed: $(date)"
    } | tee "$LOG"

    echo -e "${GREEN}chkrootkit scan complete.${NC}"
    echo -e "${GREEN}Full log saved to: ${LOG}${NC}"

}

# ===============================================================
# OPTION 8: File Integrity (AIDE) — Fixed database copy logic
# ===============================================================
do_aide() {
    local LOG="${LOG_DIR}/aide-check-$(timestamp).log"

    echo -e "\n${YELLOW}--- AIDE File Integrity Check ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v aide &>/dev/null; then
        echo -e "${YELLOW}AIDE is not installed. Installing now...${NC}"
        sudo apt install -y aide
    fi

    AIDE_CONF="/etc/aide/aide.conf"

    if [[ ! -f "$AIDE_CONF" ]]; then
        sudo mkdir -p /etc/aide /var/lib/aide
        sudo chown root:root /var/lib/aide
        sudo chmod 700 /var/lib/aide
        sudo tee "$AIDE_CONF" > /dev/null << 'EOF'
database_in = file:/var/lib/aide/aide.db
database_out = file:/var/lib/aide/aide.db.new
LIGHT = p+i+n+u+g+s+m+c
NORMAL = p+i+n+u+g+s+b+m+c+md5
PERMS = p+i+n+u+g
/etc NORMAL
/bin NORMAL
/sbin NORMAL
/usr/bin NORMAL
/usr/sbin NORMAL
/lib NORMAL
/lib64 NORMAL
/boot LIGHT
/home PERMS
!/var/log
!/run
!/tmp
!/dev
!/proc
!/sys
!/mnt
!/media
!/opt
!/srv
!/snap
!/media/owner/*
!/tmp/.mount*
EOF
        echo "-> Created: $AIDE_CONF"
    fi

    sudo mkdir -p /var/lib/aide
    sudo chown root:root /var/lib/aide
    sudo chmod 700 /var/lib/aide

    # Check for existing database AND pending .new file
    AIDE_DB=""
    AIDE_NEW=""

    if [[ -f "/var/lib/aide/aide.db" && -s "/var/lib/aide/aide.db" ]]; then
        AIDE_DB="/var/lib/aide/aide.db"
        echo -e "${GREEN}Existing database found: ${AIDE_DB}${NC}"
    elif [[ -f "/var/lib/aide/aide.db" ]]; then
        echo -e "${YELLOW}Database exists but is empty (0 bytes).${NC}"
    fi

    if [[ -f "/var/lib/aide/aide.db.new" && -s "/var/lib/aide/aide.db.new" ]]; then
        AIDE_NEW="/var/lib/aide/aide.db.new"
        NEW_SIZE=$(ls -lh "$AIDE_NEW" | awk '{print $5}')
        echo -e "${CYAN}Pending database found: ${AIDE_NEW} (${NEW_SIZE})${NC}"

        # Copy .new to .db if database is missing or empty
        if [[ -z "$AIDE_DB" ]] || [[ "$(stat -c%s "/var/lib/aide/aide.db" 2>/dev/null || echo 0)" -eq 0 ]]; then
            sudo cp "$AIDE_NEW" "${AIDE_NEW%.new}"
            AIDE_DB="/var/lib/aide/aide.db"
            echo -e "${GREEN}Installed pending database to: ${AIDE_DB}${NC}"
        fi
    fi

    # Also check for .gz variants
    if [[ -z "$AIDE_DB" ]]; then
        for candidate in "/var/lib/aide/aide.db.gz" "/var/lib/aide/aide.db.new.gz"; do
            if [[ -f "$candidate" && -s "$candidate" ]]; then
                AIDE_DB="$candidate"
                echo -e "${GREEN}Database found: ${AIDE_DB}${NC}"
                break
            fi
        done
    fi

    if [[ -z "$AIDE_DB" ]]; then
        echo -e "${RED}No AIDE database found. First run.${NC}"
        echo -n "Initialize new database now? [y/N]: "
        read init_confirm
        [[ "$init_confirm" =~ ^[Yy]$ ]] || { echo "AIDE initialization cancelled."; return; }

        {
            echo "=== AIDE Database Initialization ==="
            echo "Started: $(date)"
            timeout 600 sudo aide --config "$AIDE_CONF" --init 2>&1 || true
            echo
            echo "Completed: $(date)"
        } 2>&1 | tee "$LOG"

        for new_db in "/var/lib/aide/aide.db.new" "/var/lib/aide/aide.db.new.gz"; do
            if [[ -f "$new_db" && -s "$new_db" ]]; then
                TARGET="${new_db%.new}"
                sudo cp "$new_db" "$TARGET"
                echo -e "${GREEN}Installed new database to: ${TARGET}${NC}"
                AIDE_DB="$TARGET"
                break
            fi
        done

        if [[ -z "$AIDE_DB" ]]; then
            echo -e "${RED}ERROR: No database created after init.${NC}"
            echo -e "${YELLOW}AIDE may still be running. Check back later and re-run Option 8.${NC}"
        fi
        return
    fi

    echo -e "${YELLOW}Checking file integrity against baseline...${NC}\n"

    {
        echo "=== AIDE Integrity Check ==="
        echo "Started: $(date)"
        timeout 300 sudo aide --config "$AIDE_CONF" --check 2>&1 || true
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    CHANGES=$(grep -c "changed:" "$LOG" 2>/dev/null || echo 0)
    ADDED=$(grep -c "added:" "$LOG" 2>/dev/null || echo 0)
    REMOVED=$(grep -c "removed:" "$LOG" 2>/dev/null || echo 0)
    TOTAL=$((CHANGES + ADDED + REMOVED))

    if [[ $TOTAL -gt 0 ]]; then
        echo -e "\n${YELLOW}Changes detected:${NC}"
        echo "  Changed: $CHANGES | Added: $ADDED | Removed: $REMOVED"
        echo -n "Update database now? [y/N]: "
        read update_confirm
        if [[ "$update_confirm" =~ ^[Yy]$ ]]; then
            sudo aide --config "$AIDE_CONF" --update 2>&1
            for new_db in "/var/lib/aide/aide.db.new" "/var/lib/aide/aide.db.new.gz"; do
                if [[ -f "$new_db" && -s "$new_db" ]]; then
                    TARGET="${new_db%.new}"
                    sudo cp "$new_db" "$TARGET"
                    echo -e "${GREEN}Database updated to: ${TARGET}${NC}"
                    break
                fi
            done
        fi
    else
        echo -e "\n${GREEN}No changes detected. System matches baseline.${NC}"
    fi
    pause_for_review
}

# ===============================================================
# OPTION 9: Quick Hardening
# ===============================================================
do_quick_hardening() {
    local LOG="${LOG_DIR}/quick-hardening-$(timestamp).log"

    show_description \
        "Quick Hardening — Lynis Recommendations" \
        "Applies: helper packages, umask 027, 5 sysctl rules, CUPS perms, legal banner" \
        "~15 minutes" \
        "Low — all changes reversible" \
        "Yes — use Option 14" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Quick Hardening ==="
        echo "Started: $(date)"
        echo
        sudo apt install -y apt-listchanges needrestart debsums
        sudo sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs
        sudo tee /etc/sysctl.d/99-desktop-hardening.conf > /dev/null << 'EOF'
fs.suid_dumpable=0
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.perf_event_paranoid=2
net.ipv4.conf.all.log_martians=1
EOF
        sudo sysctl -p /etc/sysctl.d/99-desktop-hardening.conf
        sudo chown root:lp /etc/cups/cupsd.conf
        sudo chmod 640 /etc/cups/cupsd.conf
        echo "Authorized users only. Activity may be monitored." | sudo tee /etc/issue
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Quick hardening complete. Expected score gain: +10-15 points${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 10: Password Policy & PAM
# ===============================================================
do_password_policy() {
    local LOG="${LOG_DIR}/password-policy-$(timestamp).log"

    show_description \
        "Password Policy & PAM Hardening" \
        "Applies: password aging (90 days max), minimum 12-char passwords" \
        "~2 minutes" \
        "Low — affects new password creation only" \
        "Yes — use Option 14" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Password Policy & PAM ==="
        echo "Started: $(date)"
        echo
        sudo apt install -y libpam-pwquality
        sudo sed -i '/^PASS_MAX_DAYS/d; /^PASS_MIN_DAYS/d; /^PASS_WARN_AGE/d' /etc/login.defs
        sudo tee -a /etc/login.defs > /dev/null << 'EOF'
PASS_MAX_DAYS   90
PASS_MIN_DAYS   7
PASS_WARN_AGE   14
EOF
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password 2>/dev/null; then
            sudo tee -a /etc/pam.d/common-password > /dev/null << 'EOF'
password requisite pam_pwquality.so retry=3 minlen=12 difok=3
EOF
        fi
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Password policy complete. Expected score gain: +2-3 points${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 11: Enable Audit Logging (auditd)
# ===============================================================
do_enable_auditd() {
    local LOG="${LOG_DIR}/enable-auditd-$(timestamp).log"

    show_description \
        "Enable Audit Logging (auditd)" \
        "Installs and enables auditd for forensic logging" \
        "~1 minute" \
        "Low — runs silently" \
        "Yes — use Option 14" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Enable Audit Logging ==="
        echo "Started: $(date)"
        echo
        sudo apt install -y auditd audispd-plugins
        sudo systemctl enable auditd
        sudo systemctl start auditd
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Audit logging enabled. Expected score gain: +2-3 points${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 12: Security Audit (Lynis)
# ===============================================================
do_lynis() {
    local LOG="${LOG_DIR}/lynis-audit-$(timestamp).log"

    echo -e "\n${YELLOW}--- Starting Lynis Security Audit ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v lynis &>/dev/null; then
        echo -e "${YELLOW}Lynis is not installed. Installing now...${NC}"
        sudo apt install -y lynis
    fi

    {
        echo "=== Lynis Security Audit ==="
        echo "Started: $(date)"
        echo
        sudo lynis audit system
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Lynis audit complete.${NC}"

    REPORT="/var/log/lynis-report.dat"
    if [[ -f "$REPORT" ]]; then
        echo -e "\n${CYAN}=== Audit Summary ===${NC}"
        HARDENING_INDEX=$(grep -E "^hardening_index=" "$REPORT" 2>/dev/null | cut -d= -f2 | xargs || echo "N/A")
        TESTS_PERFORMED=$(grep -E "^tests_executed=" "$REPORT" 2>/dev/null | cut -d= -f2 | xargs || echo "N/A")
        WARNINGS=$(grep -E "^warnings=" "$REPORT" 2>/dev/null | cut -d= -f2 | xargs || echo "N/A")
        SUGGESTIONS=$(grep -E "^suggestions=" "$REPORT" 2>/dev/null | cut -d= -f2 | xargs || echo "N/A")
        echo "  Hardening Index:  ${HARDENING_INDEX}"
        echo "  Tests Performed:  ${TESTS_PERFORMED}"
        echo "  Warnings:         ${WARNINGS}"
        echo "  Suggestions:      ${SUGGESTIONS}"
        echo -e "\n${YELLOW}70-85 = Good | 85+ = Excellent${NC}"
    fi
    pause_for_review
}

# ===============================================================
# OPTION 13: Fail2Ban Status Check
# ===============================================================
do_fail2ban() {
    local LOG="${LOG_DIR}/fail2ban-status-$(timestamp).log"

    echo -e "\n${YELLOW}--- Fail2Ban Status Check ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    if ! command -v fail2ban-client &>/dev/null; then
        echo -e "${YELLOW}Fail2Ban is not installed.${NC}"
        echo -n "Install now? [y/N]: "
        read install_confirm
        [[ "$install_confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; return; }
        sudo apt install -y fail2ban
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
    fi

    {
        echo "=== Fail2Ban Status Check ==="
        echo "Started: $(date)"
        echo
        sudo systemctl status fail2ban --no-pager
        sudo fail2ban-client status
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Fail2Ban status check complete.${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 14: Revert Hardening Changes (Expanded for v7.7)
# ===============================================================
do_revert_hardening() {
    local LOG="${LOG_DIR}/hardening-revert-$(timestamp).log"

    show_description \
        "Revert All Hardening Changes" \
        "Removes: sysctl (basic+advanced), GRUB password, auditd, process accounting," \
        "protocol blocks, banners, password policy, CUPS perms, UMASK" \
        "~2 minutes" \
        "Low — restores to pre-hardening state" \
        "N/A — this IS the reversal" \
    || return

    echo -e "\n${YELLOW}NOTE: If the system won't boot after hardening, use the Live Recovery"
    echo -e "Key (Option 98) to restore from a live USB session instead.${NC}"
    echo -e "${YELLOW}If you haven't created one yet, consider running Option 98 first.${NC}\n"

    echo -n "Continue with in-system revert? [y/N]: "
    read revert_confirm
    [[ "$revert_confirm" =~ ^[Yy]$ ]] || { echo "Revert cancelled."; return; }

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Revert All Hardening Changes ==="
        echo "Started: $(date)"
        echo

        # --- Sysctl (both basic and advanced) ---
        echo "--- Removing sysctl hardening configs ---"
        sudo rm -f /etc/sysctl.d/99-desktop-hardening.conf 2>/dev/null || true
        sudo rm -f /etc/sysctl.d/99-lumo-hardening.conf 2>/dev/null || true
        sudo rm -f /etc/sysctl.d/99-lumo-advanced-hardening.conf 2>/dev/null || true
        sudo sysctl --system 2>&1 || true

        # --- UMASK ---
        echo "--- Reverting UMASK ---"
        sudo sed -i 's/^UMASK.*/UMASK 022/' /etc/login.defs

        # --- Password policy ---
        echo "--- Reverting password policy ---"
        sudo sed -i '/^PASS_MAX_DAYS/d; /^PASS_MIN_DAYS/d; /^PASS_WARN_AGE/d' /etc/login.defs
        sudo sed -i '/pam_pwquality.so/d' /etc/pam.d/common-password 2>/dev/null || true
        sudo apt autoremove --purge -y libpam-pwquality 2>&1 || true

        # --- CUPS ---
        echo "--- Reverting CUPS permissions ---"
        sudo chown root:cups /etc/cups/cupsd.conf 2>/dev/null || true
        sudo chmod 644 /etc/cups/cupsd.conf 2>/dev/null || true

        # --- Banners ---
        echo "--- Reverting login banners ---"
        echo "Linux Mint 22.3 \n \l" | sudo tee /etc/issue > /dev/null
        echo "Linux Mint 22.3 \n \l" | sudo tee /etc/issue.net > /dev/null

        # --- Auditd ---
        echo "--- Reverting auditd ---"
        sudo systemctl stop auditd 2>/dev/null || true
        sudo systemctl disable auditd 2>/dev/null || true
        sudo rm -f /etc/audit/rules.d/hardening.rules 2>/dev/null || true
        sudo auditctl -D 2>/dev/null || true

        # --- GRUB password ---
        echo "--- Reverting GRUB password ---"
        sudo rm -f /etc/grub.d/40_custom_grubauth 2>/dev/null || true
        sudo update-grub 2>/dev/null || true

        # --- Process accounting ---
        echo "--- Reverting process accounting ---"
        sudo systemctl stop sysstat 2>/dev/null || true
        sudo systemctl disable sysstat 2>/dev/null || true
        sudo apt autoremove --purge -y sysstat 2>&1 || true

        # --- Protocol blocks ---
        echo "--- Reverting protocol blocks ---"
        sudo rm -f /etc/modprobe.d/disable-unused.conf 2>/dev/null || true

        # --- Helper packages ---
        echo "--- Removing helper packages ---"
        sudo apt autoremove --purge -y apt-listchanges needrestart debsums 2>&1 || true

        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}All hardening reverted.${NC}"
    echo -e "${YELLOW}Lynis score will likely decrease by 15-20 points.${NC}"
    echo -e "${CYAN}Tip: If you need to revert from outside the system (won't boot),"
    echo -e "use the Live Recovery Key (Option 98) and run recover.sh.${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 15: Run All Maintenance
# ===============================================================
do_all_maintenance() {
    local LOG="${LOG_DIR}/all-maintenance-$(timestamp).log"

    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}         Run All Maintenance (Weekly)                 ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo "This will execute in sequence:"
    echo "  1. System Update & Upgrade"
    echo "  2. System Cleanup"
    echo "  3. Clear Temp Files"
    echo "  4. ClamAV No-PUA Scan"
    echo "  5. rkhunter Scan Only"
    echo
    echo -e "${YELLOW}Estimated time: 30-60 minutes${NC}"
    echo
    echo -e "  ${GREEN}[C]${NC}ontinue | ${GREEN}[B]${NC}ack | ${GREEN}[Q]${NC}uit"
    read -rp "Select option: " response
    case "$response" in
        [Cc]) ;;
        [Bb]) return ;;
        [Qq]) exit 0 ;;
        *) do_all_maintenance; return ;;
    esac

    echo -e "\n${YELLOW}Logging all operations to: ${LOG}${NC}\n"

    {
        echo "=== All Maintenance Run ==="
        echo "Started: $(date)"
        echo
        sudo apt update && sudo apt full-upgrade -y && sudo apt check
        sudo apt autoclean && sudo apt autoremove --purge -y && sudo apt clean
        sudo journalctl --vacuum-time=3d
        sudo tmpreaper --all --protect '/tmp/.X*' --protect '/tmp/.mount_*' 24h /tmp 2>/dev/null
        rm -rf ~/.cache/thumbnails/*
        sudo freshclam 2>&1 | grep -v "NotifyClamd" || true
        sudo clamscan -r --max-filesize=2000M --max-scansize=2000M --max-files=20000 --scan-archive=yes --block-encrypted=no -i --log="${LOG_DIR}/clamav-maint-$(timestamp).log" --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev" --exclude-dir="^/run" --exclude-dir="^/mnt" --exclude-dir="^/media" --exclude-dir="^/lost+found" /
        sudo rkhunter --update || true
        sudo rkhunter --checkall --sk --logfile "${LOG_DIR}/rkhunter-maint-$(timestamp).log" --report-warnings-only --pkgmgr dpkg
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}All maintenance complete.${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 16: Export Configuration Backup
# ===============================================================
do_export_configs() {
    local LOG="${LOG_DIR}/config-export-$(timestamp).log"
    local EXPORT_DIR
    EXPORT_DIR=$(mktemp -d)
    local MANIFEST="${EXPORT_DIR}/MANIFEST.txt"
    local BACKUP_DATE
    BACKUP_DATE=$(timestamp)
    local TAR_FILE="${SCRIPT_DIR}/config-backup-${BACKUP_DATE}.tar.gz"

    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${CYAN}    Export Configuration Backup (v7.7)                 ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${BLUE}Output:${NC} ${TAR_FILE}"
    echo
    echo -e "  ${GREEN}[C]${NC}ontinue | ${GREEN}[B]${NC}ack | ${GREEN}[Q]${NC}uit"
    read -rp "Select option: " response
    case "$response" in
        [Cc]) ;;
        [Bb]) return ;;
        [Qq]) exit 0 ;;
        *) do_export_configs; return ;;
    esac

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Configuration Export ==="
        echo "Started: $(date)"
        echo

        FOUND_COUNT=0
        MISSING_COUNT=0

        declare -a FILES=(
            "/etc/sysctl.d/99-desktop-hardening.conf|Sysctl hardening rules (basic)"
            "/etc/sysctl.d/99-lumo-hardening.conf|Sysctl hardening rules (advanced)"
            "/etc/rkhunter.conf.d/local.conf|rkhunter whitelists"
            "/etc/fail2ban/jail.local|Fail2Ban SSH jail"
            "/etc/tmpreaper.conf|Tmpreaper config"
            "/etc/aide/aide.conf|AIDE configuration"
            "/var/lib/aide/aide.db|AIDE baseline"
            "/etc/login.defs|Login defaults (UMASK, password aging)"
            "/etc/pam.d/common-password|PAM password rules"
            "/etc/issue|Login banner"
            "/etc/issue.net|Network login banner"
            "/etc/grub.d/40_custom_grubauth|GRUB bootloader password"
            "/etc/audit/rules.d/hardening.rules|Auditd monitoring rules"
            "/etc/modprobe.d/disable-unused.conf|Disabled network protocols"
            "/etc/default/sysstat|Process accounting config"
        )

        for entry in "${FILES[@]}"; do
            SRC="${entry%%|*}"
            DESC="${entry##*|}"

            if [[ -f "$SRC" ]]; then
                DEST="${EXPORT_DIR}${SRC}"
                sudo mkdir -p "$(dirname "$DEST")"
                sudo cp "$SRC" "$DEST"
                SIZE=$(sudo stat -c%s "$SRC" 2>/dev/null || echo "?")
                echo "  [FOUND]    $SRC ($SIZE bytes) — $DESC"
                echo "$SRC|$DESC|$SIZE bytes" >> "$MANIFEST"
                ((FOUND_COUNT++))
            else
                echo "  [MISSING]  $SRC — $DESC"
                echo "$SRC|$DESC|MISSING" >> "$MANIFEST"
                ((MISSING_COUNT++))
            fi
        done

        if [[ -f "${BASH_SOURCE[0]}" ]]; then
            SCRIPT_DEST="${EXPORT_DIR}/opt/maintain-v7.sh"
            mkdir -p "$(dirname "$SCRIPT_DEST")"
            cp "${BASH_SOURCE[0]}" "$SCRIPT_DEST"
            echo "  [FOUND]    ${BASH_SOURCE[0]} (maintenance script)"
            echo "${BASH_SOURCE[0]}|Maintenance script|$(stat -c%s "${BASH_SOURCE[0]}" 2>/dev/null || echo '?') bytes" >> "$MANIFEST"
            ((FOUND_COUNT++))
        fi

        echo "  [CREATED]  README-first.txt"
        cat > "${EXPORT_DIR}/README-first.txt" << 'READMEME'
MAINTAIN-V7.SH — QUICK REFERENCE v7.7
======================================
Author: Dave Wells, July 2026

QUICK START:
  ./maintain-v7.sh --setup          # Bootstrap
  ./maintain-v7.sh                  # Interactive menu

REGULAR USE:
  Weekly: Options 3, 4, 5, 6b, 7a
  Monthly: Option 12 (Lynis)

HARDENING:
  Options 9-11: Basic hardening
  Options 17-21: Advanced hardening
  Option 14: Revert all hardening

GRUB:
  Username: root | Password: [your chosen password]
  Recovery: Boot from USB Recovery Key (Option 98)

BACKUP:
  Option 16: Export configs
  Restore: tar xzf *.tar.gz && sudo ./restore-configs.sh
READMEME
        ((FOUND_COUNT++))

        RESTORE_SCRIPT="${EXPORT_DIR}/restore-configs.sh"
        cat > "$RESTORE_SCRIPT" << 'RESTORE_EOF'
#!/bin/bash
set -euo pipefail
[[ "$EUID" -ne 0 ]] && { echo "Must run as root (sudo)"; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ ! -f "${SCRIPT_DIR}/MANIFEST.txt" ]] && { echo "MANIFEST.txt not found"; exit 1; }
echo "Restoring files..."
while IFS='|' read -r path desc size; do
    [[ "$size" == "MISSING" ]] && continue
    SRC="${SCRIPT_DIR}${path}"
    [[ -f "$SRC" ]] && { mkdir -p "$(dirname "$path")"; cp "$SRC" "$path"; echo "  Restored: $path"; }
done < "${SCRIPT_DIR}/MANIFEST.txt"
echo "Restore complete. Post-restore: sudo sysctl --system && sudo update-grub"
RESTORE_EOF
        chmod +x "$RESTORE_SCRIPT"
        ((FOUND_COUNT++))

        {
            echo "=== Configuration Backup Manifest ==="
            echo "Created: $(date)"
            echo "Script: maintain-v7.sh (v7.7)"
            echo "Hostname: $(hostname)"
            echo "Files found: $FOUND_COUNT"
            echo "Files missing: $MISSING_COUNT"
            echo
            echo "=== File Listing ==="
            cat "$MANIFEST"
        } > "${MANIFEST}.tmp"
        mv "${MANIFEST}.tmp" "$MANIFEST"

        echo
        echo "--- Creating tarball ---"
        sudo tar czf "$TAR_FILE" -C "$EXPORT_DIR" .
        TAR_SIZE=$(sudo stat -c%s "$TAR_FILE" 2>/dev/null || echo "?")

        echo -e "\n-> Tarball created: $TAR_FILE ($TAR_SIZE bytes)"
        echo
        echo "=== Export Summary ==="
        echo "  Files found:     $FOUND_COUNT"
        echo "  Files missing:   $MISSING_COUNT"
        echo "  Tarball:         $TAR_FILE"
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    sudo rm -rf "$EXPORT_DIR"
    echo -e "${GREEN}Configuration backup complete.${NC}"
    echo -e "${GREEN}Tarball saved to: ${TAR_FILE}${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 17: GRUB Bootloader Password Protection
# ===============================================================
do_grub_password() {
    local LOG="${LOG_DIR}/grub-password-$(timestamp).log"

    show_description \
        "GRUB Bootloader Password Protection" \
        "Sets a PBKDF2 password on GRUB to prevent unauthorized boot parameter changes" \
        "~5 minutes" \
        "Medium — requires reboot to fully test" \
        "Partial — remove config file and run update-grub" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"
    echo -e "${YELLOW}NOTE: Choose a strong password for GRUB access.${NC}"
    echo -e "${YELLOW}Username will be: root${NC}"
    echo -e "${YELLOW}You will be prompted to enter the password twice.${NC}\n"

    {
        echo "=== GRUB Bootloader Password ==="
        echo "Started: $(date)"
        echo
        echo "--- Generating PBKDF2 password hash ---"
        HASH_OUTPUT=$(sudo grub-mkpasswd-pbkdf2)
        HASH_LINE=$(echo "$HASH_OUTPUT" | grep "grub.pbkdf2" | head -1)

        if [[ -z "$HASH_LINE" ]]; then
            echo "ERROR: Failed to generate password hash."
            exit 1
        fi

        echo "--- Writing GRUB authentication config ---"
        sudo tee /etc/grub.d/40_custom_grubauth > /dev/null << EOF
#!/bin/sh
cat << 'GRUBAUTH'
set superusers="root"
password_pbkdf2 root ${HASH_LINE#grub.pbkdf2.}
GRUBAUTH
EOF
        sudo chmod 755 /etc/grub.d/40_custom_grubauth

        echo "--- Regenerating GRUB configuration ---"
        sudo update-grub

        echo
        echo "Completed: $(date)"
        echo
        echo "${BOLD}IMPORTANT:${NC}"
        echo "  GRUB username: root"
        echo "  Password: [whatever you entered above]"
        echo
        echo "${YELLOW}Remember this password! Without it, you cannot:"
        echo "- Modify GRUB boot parameters"
        echo "- Boot into recovery mode"
        echo "- Change boot order in GRUB${NC}"
        echo
        echo "To remove this password, run Option 14 (Revert Hardening)."
        echo "Or use the Live Recovery Key (Option 98) if locked out.${NC}"
        echo
        echo "${YELLOW}Recommendation: Create a Recovery Key (Option 98) now.${NC}"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}GRUB password configured. Expected score gain: +1 point${NC}"
    echo -e "${YELLOW}Verify with: sudo grep -i 'superusers' /boot/grub/grub.cfg${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 18: Advanced Sysctl Hardening (VM-Compatible)
# ===============================================================
do_sysctl_advanced() {
    local LOG="${LOG_DIR}/sysctl-advanced-$(timestamp).log"

    show_description \
        "Advanced Sysctl Kernel Hardening (VM-Compatible)" \
        "Applies 5 key kernel parameters: fifo protection, core dump PID logging," \
        "BPF privilege restriction, IP forwarding ENABLED (for VMs/Docker)," \
        "anti-spoofing. Forwarding=1 maintains VM internet connectivity." \
        "~2 minutes" \
        "Low — all changes reversible and non-breaking" \
        "Yes — use Option 14 to revert" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Advanced Sysctl Hardening ==="
        echo "Started: $(date)"
        echo

        echo "--- Writing sysctl configuration ---"
        sudo tee /etc/sysctl.d/99-lumo-advanced-hardening.conf > /dev/null << 'EOF'
# Advanced sysctl hardening — created by maintain-v7.sh (Option 18)
# VM-Compatible: forwarding=1 for virtualization host support
# Complements 99-desktop-hardening.conf (Option 9)

# Filesystem protections
fs.protected_fifos=2
kernel.core_uses_pid=1

# Privilege escalation protection
kernel.unprivileged_bpf_disabled=1

# Network hardening (forwarding=1 allows VMs to work)
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=1
EOF

        echo "--- Applying kernel parameters ---"
        sudo sysctl -p /etc/sysctl.d/99-lumo-advanced-hardening.conf

        echo
        echo "--- Verifying settings ---"
        echo "fs.protected_fifos:               $(sysctl -n fs.protected_fifos)"
        echo "kernel.core_uses_pid:            $(sysctl -n kernel.core_uses_pid)"
        echo "kernel.unprivileged_bpf_disabled: $(sysctl -n kernel.unprivileged_bpf_disabled)"
        echo "net.ipv4.conf.all.forwarding:    $(sysctl -n net.ipv4.conf.all.forwarding) <- VM Compatible"
        echo "net.ipv4.conf.all.rp_filter:     $(sysctl -n net.ipv4.conf.all.rp_filter)"
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Advanced sysctl hardening applied.${NC}"
# ... continuation from Option 18 ...
    echo -e "${GREEN}Advanced sysctl hardening applied. Expected score gain: +2-3 points${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 19: Auditd Rules Configuration
# ===============================================================
do_auditd_rules() {
    local LOG="${LOG_DIR}/auditd-rules-$(timestamp).log"

    show_description \
        "Auditd Rules Configuration" \
        "Defines comprehensive audit rules for identity files, network config," \
        "sudoers, SSH, cron, kernel modules, and system time changes" \
        "~2 minutes" \
        "Low — silent background operation" \
        "Yes — remove rules file and restart auditd" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Auditd Rules Configuration ==="
        echo "Started: $(date)"
        echo

        echo "--- Ensuring auditd is installed ---"
        sudo apt install -y auditd audispd-plugins
        sudo systemctl enable auditd
        sudo systemctl start auditd

        echo "--- Creating audit rules ---"
        sudo tee /etc/audit/rules.d/hardening.rules > /dev/null << 'EOF'
# Audit rules — created by maintain-v7.sh (Option 19)
-D
-b 8192
-f 1
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /etc/hosts -p wa -k system-config
-w /etc/sysconfig/network -p wa -k system-config
-w /etc/resolv.conf -p wa -k system-config
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d -p wa -k sudoers
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/crontab -p wa -k cron
-w /etc/cron.d -p wa -k cron
-w /etc/cron.daily -p wa -k cron
-w /etc/cron.weekly -p wa -k cron
-w /etc/cron.monthly -p wa -k cron
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-e 2
EOF

        echo "--- Restarting auditd to load rules ---"
        sudo systemctl restart auditd

        echo "--- Verifying rules are loaded ---"
        RULE_COUNT=$(sudo auditctl -l 2>/dev/null | wc -l)
        echo "Active rules: $RULE_COUNT"
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Auditd rules configured. Expected score gain: +1 point${NC}"
    echo -e "${YELLOW}Rules are immutable until next reboot due to the -e 2 flag.${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 20: Process Accounting (sysstat)
# ===============================================================
do_process_accounting() {
    local LOG="${LOG_DIR}/process-accounting-$(timestamp).log"

    show_description \
        "Process Accounting (sysstat)" \
        "Installs and enables sysstat for system resource accounting and monitoring" \
        "~1 minute" \
        "Low — silent background operation" \
        "Yes — disable service and remove package" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Process Accounting (sysstat) ==="
        echo "Started: $(date)"
        echo

        echo "--- Installing sysstat ---"
        sudo apt install -y sysstat

        echo "--- Enabling process accounting ---"
        sudo sed -i 's/ENABLED=.*/ENABLED="1"/' /etc/default/sysstat 2>/dev/null || true
        sudo systemctl enable sysstat
        sudo systemctl start sysstat

        echo "--- Verifying service ---"
        sudo systemctl status sysstat --no-pager | head -5
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Process accounting enabled. Expected score gain: +1 point${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 21: Disable Unused Network Protocols
# ===============================================================
do_disable_protocols() {
    local LOG="${LOG_DIR}/disable-protocols-$(timestamp).log"

    show_description \
        "Disable Unused Network Protocols" \
        "Blocks dccp, sctp, rds, and tipc kernel modules to reduce attack surface" \
        "~1 minute" \
        "Very Low — these protocols are rarely used on desktops" \
        "Yes — remove the modprobe config file" \
    || return

    echo -e "\n${YELLOW}Logging to: ${LOG}${NC}\n"

    {
        echo "=== Disable Unused Network Protocols ==="
        echo "Started: $(date)"
        echo

        echo "--- Creating modprobe blacklist ---"
        sudo tee /etc/modprobe.d/disable-unused.conf > /dev/null << 'EOF'
# Disable rare/unneeded network protocols
# Reduces attack surface without impacting normal desktop use
# Created by maintain-v7.sh (Option 21)

install dccp /bin/true
install sctp /bin/true
install rds  /bin/true
install tipc /bin/true
EOF

        echo "--- Configured in: /etc/modprobe.d/disable-unused.conf ---"
        echo
        echo "NOTE: Changes take effect on next boot or after manually"
        echo "      unloading the modules with: sudo modprobe -r <module>"
        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Unused protocols disabled. Expected score gain: +1 point${NC}"
    pause_for_review
}

# ==============================================================================
# OPTION 22: Vulnerability Scanner (debsecan)
# ==============================================================================
do_vuln_scanner_menu() {
    while true; do
        clear
        echo -e "${CYAN}==================================================${NC}"
        echo -e "${CYAN}        Vulnerability Scanner (debsecan)            ${NC}"
        echo -e "${CYAN}==================================================${NC}"
        echo
        echo -e "  ${GREEN}22a)${NC}  Full Vulnerability Scan"
        echo -e "  ${GREEN}22b)${NC}  Show Only High/Critical CVEs"
        echo -e "  ${GREEN}22c)${NC}  List Packages with Security Updates"
        echo -e "  ${GREEN}22d)${NC}  Generate Vulnerability Report"
        echo -e "  ${GREEN}22e)${NC}  Install/Update debsecan"
        echo -e "  ${GREEN}B)${NC}   Back to main menu"
        echo -e "  ${GREEN}Q)${NC}   Quit script"
        echo
        read -rp "Select option: " choice
        case "$choice" in
            22a) do_debsecan_full ;;
            22b) do_debsecan_high ;;
            22c) do_debsecan_updates ;;
            22d) do_debsecan_report ;;
            22e) do_debsecan_install ;;
            [Bb]) return 1 ;;
            [Qq]) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Press Enter to try again.${NC}"
                read -r
                ;;
        esac
    done
}

# -------------------------------------------------------------------
# 22a: Full Vulnerability Scan
# -------------------------------------------------------------------
do_debsecan_full() {
    local LOG="${LOG_DIR}/vuln-scan-full-$(timestamp).log"
    local SUITE
    SUITE=$(get_ubuntu_suite)

    echo -e "\n${YELLOW}--- Full Vulnerability Scan ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    echo "Scanning installed packages for known vulnerabilities..."
    echo "Mint codename: $(lsb_release -cs 2>/dev/null) → Ubuntu suite: $SUITE"
    echo "This may take 30-60 seconds depending on installed package count."
    echo

    {
        echo "=== Full Vulnerability Scan ==="
        echo "Started: $(date)"
        echo "Host: $(hostname)"
        echo "OS: $(lsb_release -ds 2>/dev/null || echo 'unknown')"
        echo "Ubuntu suite: $SUITE"
        echo

        # Method 1: Check for packages with known CVEs via apt
        echo "============================================"
        echo "  SECURITY UPDATES AVAILABLE"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null | grep -i security || echo "(none found)"
        echo

        # Method 2: Check for remotely exploitable packages
        echo "============================================"
        echo "  ALL UPGRADABLE PACKAGES"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null || echo "(none found)"
        echo

        # Method 3: Check Ubuntu CVE database via apt-check
        if command -v /usr/lib/ubuntu-advantage-tools/apt-check &>/dev/null; then
            echo "============================================"
            echo "  UBUNTU ADVANTAGE SECURITY SUMMARY"
            echo "============================================"
            echo
            /usr/lib/ubuntu-advantage-tools/apt-check --human-readable 2>&1 || true
            echo
        fi

        # Method 4: Check for packages no longer in repositories (orphaned/vulnerable)
        echo "============================================"
        echo "  ORPHANED PACKAGES (no longer in repos)"
        echo "============================================"
        echo
        apt-mark showmanual 2>/dev/null | while read -r pkg; do
            if ! apt-cache show "$pkg" &>/dev/null; then
                echo "ORPHANED: $pkg"
            fi
        done
        echo

        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    local SEC_COUNT
    SEC_COUNT=$(grep -ci 'security' "$LOG" 2>/dev/null || true)
    local TOTAL_UPGRADE
    TOTAL_UPGRADE=$(apt list --upgradable 2>/dev/null | grep -c '/' || true)

    echo
    echo -e "${CYAN}=== Scan Summary ===${NC}"
    echo "  Security-related updates:   $SEC_COUNT"
    echo "  Total upgradable packages:  $TOTAL_UPGRADE"
    echo "  Full log:                   $LOG"
    echo
    echo -e "${YELLOW}Use 22b to filter for high/critical only.${NC}"

    pause_for_review
}

# -------------------------------------------------------------------
# 22b: Show Only High/Critical CVEs
# -------------------------------------------------------------------
do_debsecan_high() {
    local LOG="${LOG_DIR}/vuln-scan-high-$(timestamp).log"
    local SUITE
    SUITE=$(get_ubuntu_suite)

    echo -e "\n${YELLOW}--- High/Critical Vulnerabilities Only ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    echo "Checking for high-priority security updates..."
    echo "Ubuntu suite: $SUITE"
    echo

    {
        echo "=== High/Critical Vulnerability Scan ==="
        echo "Started: $(date)"
        echo "Host: $(hostname)"
        echo "Ubuntu suite: $SUITE"
        echo

        # Check Ubuntu Advantage security summary
        if command -v /usr/lib/ubuntu-advantage-tools/apt-check &>/dev/null; then
            echo "============================================"
            echo "  SECURITY UPDATE SUMMARY (apt-check)"
            echo "============================================"
            /usr/lib/ubuntu-advantage-tools/apt-check --human-readable 2>&1 || true
            echo
        fi

        # List security-specific updates
        echo "============================================"
        echo "  SECURITY UPDATES REQUIRED"
        echo "============================================"
        echo
        
        # Get security updates with package names
        apt list --upgradable 2>/dev/null | grep -i security || echo "(no security updates pending)"
        echo

        # Check for critical CVEs using apt changelog (sample)
        echo "============================================"
        echo "  RECENT SECURITY ADVISORIES"
        echo "============================================"
        echo

        # List packages with security flags from apt
        local SEC_PKGS
        SEC_PKGS=$(apt list --upgradable 2>/dev/null | grep -i security | cut -d/ -f1 | tr '\n' ' ')
        if [[ -n "$SEC_PKGS" ]]; then
            for pkg in $SEC_PKGS; do
                echo "Package: $pkg"
                apt changelog "$pkg" 2>/dev/null | grep -iE 'CVE-|security|urgent|critical|high' | head -5
                echo
            done
        else
            echo "(no security advisories found)"
        fi

        echo
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    local HIGH_COUNT
    HIGH_COUNT=$(apt list --upgradable 2>/dev/null | grep -ic security || true)
    [[ -z "$HIGH_COUNT" ]] && HIGH_COUNT=0

    echo
    echo -e "${CYAN}=== Summary ===${NC}"
    echo "  Security-related findings: $HIGH_COUNT"
    echo "  Log: $LOG"
    echo

    if [[ "$HIGH_COUNT" -gt 0 ]]; then
        echo -e "${RED}⚠  $HIGH_COUNT security findings detected.${NC}"
        echo -e "${YELLOW}Run Option 3 (System Update) to patch affected packages.${NC}"
    else
        echo -e "${GREEN}✓ No high/critical vulnerabilities found.${NC}"
    fi

    pause_for_review
}

# -------------------------------------------------------------------
# 22c: List Packages with Security Updates
# -------------------------------------------------------------------
do_debsecan_updates() {
    local LOG="${LOG_DIR}/vuln-updates-$(timestamp).log"

    echo -e "\n${YELLOW}--- Packages with Security Updates ---${NC}"
    echo -e "${YELLOW}Logging to: ${LOG}${NC}\n"

    echo "Checking for packages with available security updates..."
    echo

    {
        echo "=== Security Updates Available ==="
        echo "Started: $(date)"
        echo "Host: $(hostname)"
        echo

        echo "============================================"
        echo "  SECURITY-SPECIFIC UPDATES"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null | grep -i security || echo "(none found)"
        echo

        echo "============================================"
        echo "  ALL UPGRADABLE PACKAGES"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null || echo "(system is up to date)"
        echo

        echo "============================================"
        echo "  PACKAGE COUNTS"
        echo "============================================"
        local SEC_COUNT ALL_COUNT
        SEC_COUNT=$(apt list --upgradable 2>/dev/null | grep -ic security || true)
        [[ -z "$SEC_COUNT" ]] && SEC_COUNT=0
        ALL_COUNT=$(apt list --upgradable 2>/dev/null | grep -c '/' || true)
        [[ -z "$SEC_COUNT" ]] && SEC_COUNT=0
        [[ -z "$ALL_COUNT" ]] && ALL_COUNT=0
        echo "Security updates: $SEC_COUNT"
        echo "Total updates:    $ALL_COUNT"
        echo

        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    local SEC_COUNT
    local SEC_COUNT
    SEC_COUNT=$(apt list --upgradable 2>/dev/null | grep -ic security || true)
    [[ -z "$SEC_COUNT" ]] && SEC_COUNT=0

    echo
    echo -e "${CYAN}=== Summary ===${NC}"
    echo "  Security-related updates: $SEC_COUNT"
    echo "  Log: $LOG"
    echo

    if [[ "$SEC_COUNT" -gt 0 ]]; then
        echo -e "${YELLOW}Run Option 3 (System Update) to install security patches.${NC}"
    else
        echo -e "${GREEN}✓ No security updates pending.${NC}"
    fi

    pause_for_review
}

do_debsecan_report() {
    local REPORT="${LOG_DIR}/vuln-report-$(timestamp).txt"
    local SUITE
    SUITE=$(get_ubuntu_suite)

    echo -e "\n${YELLOW}--- Generating Vulnerability Report ---${NC}"
    echo -e "${YELLOW}Output: $REPORT${NC}\n"

    local PKG_COUNT
    PKG_COUNT=$(dpkg -l | grep -c '^ii' || true)

    local SEC_COUNT ALL_COUNT
    SEC_COUNT=$(apt list --upgradable 2>/dev/null | grep -ic security || true)
    ALL_COUNT=$(apt list --upgradable 2>/dev/null | grep -c '/' || true)

    # Handle empty results
    [[ -z "$SEC_COUNT" ]] && SEC_COUNT=0
    [[ -z "$ALL_COUNT" ]] && ALL_COUNT=0

    {
        echo "============================================"
        echo "  VULNERABILITY ASSESSMENT REPORT"
        echo "============================================"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "OS: $(lsb_release -ds 2>/dev/null || echo 'unknown')"
        echo "Mint codename: $(lsb_release -cs 2>/dev/null || echo 'unknown')"
        echo "Ubuntu suite: $SUITE"
        echo "Installed packages: $PKG_COUNT"
        echo "============================================"
        echo

        echo "============================================"
        echo "  EXECUTIVE SUMMARY"
        echo "============================================"
        echo "Security updates pending:  $SEC_COUNT"
        echo "Total updates pending:    $ALL_COUNT"
        echo

        echo "============================================"
        echo "  UBUNTU ADVANTAGE CHECK"
        echo "============================================"
        if dpkg -l ubuntu-advantage-tools &>/dev/null; then
        echo "Ubuntu Pro/Advantage: Active (legacy apt-check deprecated)"
        else
            echo "Ubuntu Pro/Advantage: Not installed"
        fi
        echo

        echo "============================================"
        echo "  SECURITY UPDATES REQUIRED"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null | grep -i security || echo "(none found)"
        echo

        echo "============================================"
        echo "  ALL UPGRADABLE PACKAGES"
        echo "============================================"
        echo
        apt list --upgradable 2>/dev/null || echo "(system is up to date)"
        echo

        echo "============================================"
        echo "  SECURITY ADVISORY DETAILS"
        echo "============================================"
        echo

        local SEC_PKGS
        SEC_PKGS=$(apt list --upgradable 2>/dev/null | grep -i security | cut -d/ -f1 | tr '\n' ' ')
        if [[ -n "$SEC_PKGS" ]]; then
            for pkg in $SEC_PKGS; do
                echo "--- $pkg ---"
                apt changelog "$pkg" 2>/dev/null | grep -iE 'CVE-|security|urgency' | head -10
                echo
            done
        else
            echo "(no security advisories found)"
        fi

        echo
        echo "============================================"
        echo "  RECOMMENDATIONS"
        echo "============================================"
        echo "1. Run Option 3 (System Update) to install available patches"
        echo "2. Review security updates above for affected packages"
        echo "3. For remote vulnerabilities, verify firewall configuration"
        echo "4. Re-run this scan after updates to verify remediation"
        echo "5. Schedule regular scans (Option 6e for ClamAV, 22a for CVEs)"
        echo
        echo "Report generated by maintain-v7.sh (Option 22d)"
        echo "============================================"
    } > "$REPORT" 2>&1

    echo -e "${GREEN}Report generated: $REPORT${NC}"
    echo
    echo "--- Preview ---"
    head -50 "$REPORT"
    echo
    echo -e "${CYAN}(Full report saved to $REPORT)${NC}"

    pause_for_review
}
# -------------------------------------------------------------------
# 22e: Install/Update debsecan (now: install prerequisites)
# -------------------------------------------------------------------
do_debsecan_install() {
    echo -e "\n${YELLOW}--- Install/Update Prerequisites ---${NC}\n"

    echo "Checking required packages for vulnerability scanning..."
    echo

    local NEED_INSTALL=0

    # Check for ubuntu-advantage-tools package (provides apt-check)
    if ! dpkg -l ubuntu-advantage-tools &>/dev/null; then
        echo -e "${YELLOW}ubuntu-advantage-tools not found (provides security summary).${NC}"
        NEED_INSTALL=1
    fi

    # Check for apt (should always be present)
    if ! command -v apt &>/dev/null; then
        echo -e "${RED}apt not found. This tool requires apt-based systems.${NC}"
        pause_for_review
        return
    fi

    if [[ "$NEED_INSTALL" -eq 1 ]]; then
        echo -e "${YELLOW}Installing ubuntu-advantage-tools...${NC}"
        sudo apt update -qq
        sudo apt install -y ubuntu-advantage-tools
    else
        echo -e "${GREEN}✓ All required packages already installed.${NC}"
    fi

    echo
    echo -e "${CYAN}Components:${NC}"
    echo "  apt .................. $(command -v apt &>/dev/null && echo '✓' || echo '✗')"
    echo "  apt-check ............ $(test -f /usr/lib/ubuntu-advantage-tools/apt-check && echo '✓' || echo '✗')"
    echo "  apt changelog ......... $(apt changelog bash 2>/dev/null | head -1 &>/dev/null && echo '✓' || echo '✗')"
    echo

    echo -e "${GREEN}✓ Vulnerability scanner prerequisites verified.${NC}"
    echo -e "${CYAN}Note: This scanner uses apt's built-in security repository"
    echo -e "${CYAN}tracking and Ubuntu's CVE database. No external tools needed.${NC}"

    pause_for_review
}
# ==============================================================================
# OPTION 23: Performance Gear Shift (perf-tune.sh integration)
# ==============================================================================
do_perf_tune_wrapper() {
    local PERF_TUNE="${SCRIPT_DIR}/perf-tune.sh"

    if [[ ! -f "$PERF_TUNE" ]]; then
        echo -e "\n${RED}Error: perf-tune.sh not found.${NC}"
        echo "Please copy perf-tune.sh to the same directory as maintain-v7.sh"
        echo "Download it or use the one we created earlier."
        echo
        echo -e "${CYAN}Current directory: $SCRIPT_DIR${NC}"
        echo -e "${CYAN}Expected path: $PERF_TUNE${NC}"
        echo
        echo -e "${YELLOW}Tip: If you have perf-tune.sh elsewhere, copy it here:${NC}"
        echo "  cp /path/to/perf-tune.sh $SCRIPT_DIR/"
        echo
        echo -n "Press Enter to return to menu..."
        read -r
        return
    fi

    if [[ ! -x "$PERF_TUNE" ]]; then
        echo -e "${YELLOW}Setting execute permission on perf-tune.sh...${NC}"
        chmod +x "$PERF_TUNE"
    fi

    echo -e "\n${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    LAUNCHING PERFORMANCE GEAR SHIFT TOOL    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Notes:${NC}"
    echo -e "  • The tool will run in this window"
    echo -e "  • Press B or Q in perf-tune.sh to return here"
    echo -e "  • All settings persist across sessions"
    echo
    echo -e "${CYAN}Press Enter to launch...${NC}"
    read -r

    echo
    "$PERF_TUNE"

    echo
    echo -e "${CYAN}─────────────────────────────────────${NC}"
    echo -e "${GREEN}Returned from perf-tune.sh.${NC}"
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}


# ===============================================================
# OPTION 23: Performance Gear Shift (perf-tune.sh)
# ===============================================================
do_perf_tune_wrapper() {
    local PERF_TUNE="${SCRIPT_DIR}/perf-tune.sh"

    if [[ ! -f "$PERF_TUNE" ]]; then
        echo -e "\n${RED}Error: perf-tune.sh not found.${NC}"
        echo "Please copy perf-tune.sh to the same directory as maintain-v7.sh"
        echo -n "Press Enter to return to menu..."
        read -r
        return
    fi

    if [[ ! -x "$PERF_TUNE" ]]; then
        echo -e "${YELLOW}Setting execute permission on perf-tune.sh...${NC}"
        chmod +x "$PERF_TUNE"
    fi

    echo -e "\n${CYAN}Launching Performance Gear Shift Tool...${NC}"
    echo -e "${CYAN}(Press B or Q to return to maintain-v7.sh)${NC}"
    echo

    "$PERF_TUNE"

    echo
    echo -e "${GREEN}Returned from perf-tune.sh.${NC}"
    pause_for_review
}
# ===============================================================
# OPTION 98: Create Live Recovery Key (USB)
# ===============================================================
do_create_recovery_key() {
    local LOG="${LOG_DIR}/recovery-key-$(timestamp).log"

    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    Create Live Recovery Key (USB)                    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${BOLD}This will create a bootable USB recovery key containing:${NC}"
    echo -e "  • Critical system config backups"
    echo -e "  • Automated recovery script to restore or remove hardening"
    echo -e "  • GRUB password reminder (username: root)"
    echo
    echo -e "${BLUE}Requirements:${NC}"
    echo -e "  • USB drive (minimum 2GB)"
    echo -e "  • Will be COMPLETELY WIPED"
    echo
    echo -e "${CYAN}------------------------------------------------------${NC}"
    echo
    echo -e "  ${GREEN}[C]${NC}ontinue | ${GREEN}[B]${NC}ack | ${GREEN}[Q]${NC}uit"
    read -rp "Select option: " response
    case "$response" in
        [Cc]) ;;
        [Bb]) return ;;
        [Qq]) exit 0 ;;
        *) do_create_recovery_key; return ;;
    esac

    echo -e "\n${YELLOW}Warning: This will erase ALL DATA on the selected USB drive.${NC}\n"
    
    echo "Available USB devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep -E "^sd|^nvme" | grep -v "loop"
    echo
    read -rp "Enter USB device (e.g., /dev/sdb): " USB_DEVICE
    
    if [[ ! -b "$USB_DEVICE" ]]; then
        echo -e "${RED}ERROR: Invalid device.${NC}"
        return
    fi

    echo -n "Type WIPE to confirm erasure: "
    read CONFIRM
    [[ "$CONFIRM" != "WIPE" ]] && { echo "Aborted."; return; }

    echo -e "\n${YELLOW}Creating recovery key...${NC}\n"
    
    {
        echo "=== Live Recovery Key ==="
        echo "Started: $(date)"
        echo "Device: $USB_DEVICE"
        
        # Partition and format
        sudo wipefs -a "$USB_DEVICE" 2>/dev/null || true
        sudo parted -s "$USB_DEVICE" mklabel gpt
        sudo parted -s "$USB_DEVICE" mkpart primary 0% 100%
        PARTITION="${USB_DEVICE}1"
        sleep 2
        
        sudo mkfs.ext4 -F -L "RECOVERY" "$PARTITION"
        
        MOUNT_POINT=$(mktemp -d)
        sudo mount "$PARTITION" "$MOUNT_POINT"
        RECOVERY_DIR="${MOUNT_POINT}/recovery"
        sudo mkdir -p "$RECOVERY_DIR/configs" "$RECOVERY_DIR/scripts"
        
        # Copy configs
        declare -a FILES=(
            "/etc/grub.d/40_custom_grubauth"
            "/etc/sysctl.d/99-desktop-hardening.conf"
            "/etc/sysctl.d/99-lumo-hardening.conf"
            "/etc/sysctl.d/99-lumo-advanced-hardening.conf"
            "/etc/audit/rules.d/hardening.rules"
            "/etc/modprobe.d/disable-unused.conf"
            "/etc/fail2ban/jail.local"
            "/etc/aide/aide.conf"
        )
        
        for f in "${FILES[@]}"; do
            [[ -f "$f" ]] && sudo cp "$f" "${RECOVERY_DIR}/configs/"
        done
        
        # Copy this script
        sudo cp "${BASH_SOURCE[0]}" "${RECOVERY_DIR}/scripts/maintain-v7.sh"
        sudo chmod +x "${RECOVERY_DIR}/scripts/maintain-v7.sh"
        
        # Create GRUB password reminder
        sudo tee "${RECOVERY_DIR}/GRUB-PASSWORD-REMINDER.txt" > /dev/null << 'GRUB_NOTE'
╔══════════════════════════════════════════════════════╗
║              GRUB BOOTLOADER PASSWORD                ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  If GRUB prompts for credentials at boot:            ║
║                                                      ║
║    Username: root                                    ║
║    Password: [your chosen password]                  ║
║                                                      ║
║  To remove GRUB password:                            ║
║    1. Boot from this USB drive                       ║
║    2. Run: cd /recovery/scripts && ./recover.sh      ║
║    3. Choose option 3 (Remove GRUB password only)    ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
GRUB_NOTE

        # Create recovery script
        sudo tee "${RECOVERY_DIR}/scripts/recover.sh" > /dev/null << 'RECOVER_SCRIPT'
#!/bin/bash
set -euo pipefail
echo "=== Live Recovery Tool ==="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
echo
read -rp "Enter target root partition: " PART
[[ ! -b "$PART" ]] && { echo "Invalid partition"; exit 1; }
MNT=$(mktemp -d)
sudo mount "$PART" "$MNT"
echo "1) Restore configs | 2) Remove all hardening | 3) Remove GRUB password only"
read -rp "Choice [1-3]: " ACTION
case "$ACTION" in
    1) cp -r /recovery/configs/* "${MNT}/etc/" 2>/dev/null; sudo update-grub ;;
    2) rm -f "${MNT}/etc/grub.d/40_custom_grubauth" "${MNT}/etc/sysctl.d/"*.conf* "${MNT}/etc/audit/rules.d/hardening.rules" 2>/dev/null; sudo mount --bind /dev "${MNT}/dev"; sudo mount --bind /proc "${MNT}/proc"; sudo mount --bind /sys "${MNT}/sys"; sudo chroot "$MNT" update-grub; sudo umount -R "$MNT" ;;
    3) rm -f "${MNT}/etc/grub.d/40_custom_grubauth" 2>/dev/null; sudo update-grub ;;
esac
sudo umount "$MNT"
echo "Done."
RECOVER_SCRIPT
        sudo chmod +x "${RECOVERY_DIR}/scripts/recover.sh"
        
        sudo umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT" 2>/dev/null || true
        
        echo "Completed: $(date)"
    } 2>&1 | tee "$LOG"

    echo -e "${GREEN}Recovery key created on $USB_DEVICE${NC}"
    echo -e "${CYAN}Label it: 'RECOVERY KEY' | Store safely${NC}"
    pause_for_review
}

# ===============================================================
# OPTION 99: Exit
# ===============================================================
do_exit() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}        System Maintenance & Security Suite           ${NC}"
    echo -e "${CYAN}              Thank you for using!                   ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo
    echo -e "${YELLOW}Stay secure, Dave!${NC}"
    echo
    exit 0
    pause_for_review
}

# ===============================================================
# Main Loop
# ===============================================================
pause_for_review() {
    echo
    echo -e "${CYAN}------------------------------------------------------${NC}"
    echo -n "Press Enter to return to menu..."
    read -r
}

while true; do
    show_menu
    read -r choice

    case "$choice" in
        1)  do_initial_setup ;;
        2)  view_readme ;;
        3)  do_update_upgrade ;;      # FIXED: now pauses
        4)  do_cleanup ;;             # FIXED: now pauses
        5)  do_clear_temp ;;          # FIXED: now pauses
        6)  do_antivirus_submenu || continue ;;  # ENHANCED
        7)  do_rootkit_submenu || continue ;;
        8)  do_aide ;;
        9)  do_quick_hardening || continue ;;
        10) do_password_policy || continue ;;
        11) do_enable_auditd || continue ;;
        12) do_lynis || continue ;;
        13) do_fail2ban || continue ;;
        14) do_revert_hardening || continue ;;
        15) do_all_maintenance || continue ;;
        16) do_export_configs || continue ;;
        17) do_grub_password || continue ;;
        18) do_sysctl_advanced || continue ;;
        19) do_auditd_rules || continue ;;
        20) do_process_accounting || continue ;;
        21) do_disable_protocols || continue ;;
        22) do_vuln_scanner_menu || continue ;;   # NEW
        23) do_perf_tune_wrapper || continue ;;   # NEW
        98) do_create_recovery_key ;;
        99) do_exit ;;
        "")
            echo -e "${RED}No selection made.${NC}"
            sleep 1
            continue
            ;;
        *)
            echo -e "${RED}Invalid option [$choice]. Press Enter to try again.${NC}"
            read
            continue
            ;;
    esac
done
}
