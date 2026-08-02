# Changelog — maintain-v7.sh

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [7.7] — 2026-07-xx

### Added
- Vulnerability Scanner module (Option 22) with submenu:
  - Full vulnerability scan (22a)
  - High/Critical CVE filter (22b)
  - Security updates listing (22c)
  - Vulnerability report generation (22d)
  - Prerequisites installation/check (22e)
- Performance Gear Shift launcher (Option 23) — integrates `perf-tune.sh`
- VirusTotal upload quota tracking (daily limit enforcement)
- Extended README documentation with usage examples
- Man-page style documentation (`maintain-v7.8`)
- Comprehensive troubleshooting guide

### Changed
- Renamed Option 6 menu entries for clarity (6a-6i)
- Improved AIDE database recovery logic (handles `.gz` variants)
- Enhanced GRUB password lockout warnings with recovery instructions
- Updated rkhunter whitelists for LibreOffice and GNOME terminal
- Refactored `get_ubuntu_suite()` for better Linux Mint codename mapping

### Fixed
- Temp file cleanup now excludes `/tmp/.mount_*` (prevents Joplin FUSE mount errors)
- AIDE init timeout handling with descriptive error messages
- ClamAV deep scan log file path consistency
- Option 15 (Run All Maintenance) logging aggregation
- Syntax error in `do_revert_hardening()` sysctl removal

### Security
- AIDE config excludes ephemeral network mounts to prevent hangs
- VT API key storage enforces `0600` permissions
- VirusTotal uploads enforce daily quota limit (4/day free tier)
- GRUB password uses PBKDF2 hashing (strong encryption)

### Known Issues
- `apt-check` may return empty on Mint without ubuntu-advantage-tools installed
- AIDE still reports permission denied on active AppImage mounts (excluded post-scan)
- VirusTwo free tier rate limits: 4 uploads/day, ~4 queries/min

---

## [7.6] — 2026-06-xx

### Added
- Live Recovery Key creation (Option 98)
- Automated backup restore script (`restore-configs.sh`)
- GRUB bootloader password protection (Option 17)
- Advanced sysctl hardening with VM compatibility (Option 18)
- Auditd rules configuration (Option 19)
- Process accounting via sysstat (Option 20)
- Unused protocol disabling (Option 21)

### Changed
- Consolidated all security scans into single monolithic script
- Moved logs to `./logs/` relative to script location
- Standardized confirmation dialogs across all modules

### Fixed
- Fail2Ban SSH jail configuration persistence
- tmpreaper protection for X11 socket files
- Lynis score extraction after audit

---

## [7.5] — 2026-05-xx

### Added
- Initial script framework
- Option 1 initial setup bootstrap
- ClamAV integration (deep and quick scans)
- Rootkit detection (rkhunter + chkrootkit)
- AIDE file integrity monitoring
- Lynis security audit integration
- Fail2Ban SSH brute-force protection

### Changed
- Split antivirus into submenu (6a-6d)
- Improved logging to separate timestamped files

---

## [1.0] — 2024-xx-xx

### Added
- Initial release concept (separate scripts for each task)

---

## Version Legend

| Major.Minor | Type | Description |
|-------------|------|-------------|
| **7.x** | Feature releases | New modules, major enhancements |
| **7.0.x** | Patch releases | Bug fixes, security patches |

---

## Authors & Contributors

- **Dave Wells** — Lead developer, St. Louis, MO
- **Contributors** — None yet (open to PRs)

---

## License

Free software under GPL. NO WARRANTY. Use at your own risk.