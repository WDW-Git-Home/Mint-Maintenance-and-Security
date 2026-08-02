# Contributing to maintain-v7.sh

Thank you for your interest in contributing! This is a personal system maintenance and security toolkit designed for Debian/Ubuntu-based Linux distributions.

---

## Ways to Contribute

| Type | How |
|------|-----|
| **Bug Reports** | Open an issue with reproduction steps, OS version, and log output |
| **Feature Requests** | Open an issue with a clear description and use case |
| **Code Contributions** | Fork, branch, test, submit a pull request |
| **Documentation** | Fix typos, improve clarity, add examples |
| **Testing** | Test on other Debian/Ubuntu distros and report results |

---

## Before You Start

### Requirements

- Bash 4.0+
- Debian/Ubuntu-based Linux (Mint, Ubuntu, Debian, Pop!_OS, etc.)
- Root/sudo access for testing
- Familiarity with: `clamav`, `rkhunter`, `aide`, `lynis`, `fail2ban`, `auditd`

### Code Style

| Rule | Detail |
|------|--------|
| **Shell** | Bash, no sh/dash compatibility required |
| **Error handling** | `set -euo pipefail` is already at the top — honor it |
| **Functions** | Prefix with `do_` for menu actions, lowercase for helpers |
| **Variables** | Local variables inside functions, uppercase for globals |
| **Comments** | Section headers use `# =====` dividers, inline comments for logic |
| **Menus** | New modules get sequential numbers; Exit stays at 99 |
| **Logs** | Every module writes to `$LOG_DIR` with timestamped filenames |
| **Confirmation** | Use `show_description()` for destructive or risky actions |

---

## Pull Request Process

1. **Fork** the repository
2. **Create a branch:**
   ```bash
   git checkout -b fix/aide-timeout-handling
   # or
   git checkout -b feature/new-scanner-module
   ```
3. **Make your changes** — keep commits focused and atomic
4. **Test locally:**
   ```bash
   # Run the script and test your module
   sudo ./maintain-v7.sh

   # Verify no syntax errors
   bash -n maintain-v7.sh

   # Check for shellcheck issues (if installed)
   shellcheck maintain-v7.sh
   ```
5. **Update documentation** if needed:
   - `README.md` — new menu options, config files, usage examples
   - `TROUBLESHOOTING.md` — any new known issues
   - `CHANGELOG.md` — add your changes under `[Unreleased]`
   - `man/maintain-v7.8` — update man page for new options
6. **Submit a pull request** with:
   - Clear title describing the change
   - Description of what and why
   - Tested OS/distros listed
   - Screenshots or log output if applicable

---

## Issue Guidelines

### Bug Reports

Include the following:
OS/Distro: Linux Mint 22.3 "Zena" Script Version: 7.7 Module/Option: Option 8 (AIDE) Description: [What happened] Reproduction Steps:

    [Step 1]
    [Step 2] Expected Behavior: [What should have happened] Actual Behavior: [What actually happened] Log Output: ``` [paste relevant log snippet] ```


### Feature Requests

Feature: [Short title] Use Case: [Why is this needed?] Proposed Implementation: [How should it work?] Affected Module: [Which option(s) would this impact?]



---

## Testing Matrix

If you can test on additional distributions, that's hugely valuable:

| Distribution | Status |
|--------------|--------|
| Linux Mint 22.3 Zena | ✅ Primary (tested) |
| Linux Mint 21.x | ⬜ Untested |
| Ubuntu 24.04 Noble | ⬜ Untested |
| Ubuntu 22.04 Jammy | ⬜ Untested |
| Debian 12 Bookworm | ⬜ Untested |
| Pop!_OS 22.04 | ⬜ Untested |
| KDE neon | ⬜ Untested |

Mark with ✅ (works), ❌ (broken), or ⚠️ (partial) in your issue or PR.

---

## Module Numbering Convention

| Range | Purpose |
|-------|---------|
| 1-16 | Core modules (setup, maintenance, scans, hardening, audit) |
| 17-21 | Advanced hardening modules |
| 22-97 | Reserved for future expansion |
| 98 | Recovery Key (fixed position) |
| 99 | Exit (always last, never changes) |

New modules should be added sequentially within the appropriate range. Never reuse retired module numbers.

---

## Questions?

Open an issue with the `question` label, or contact the repository owner.

---

**License:** By contributing, you agree that your contributions will be licensed under the GPL.

**Code of Conduct:** Be respectful. Be constructive. No BS.



































