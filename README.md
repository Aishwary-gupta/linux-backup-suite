# 🛡️ Linux Backup Automation Suite

![Bash](https://img.shields.io/badge/Language-Bash%20%2F%20Shell-4EAA25?logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Platform-Linux%20%2F%20POSIX-FCC624?logo=linux&logoColor=black)
![Automation](https://img.shields.io/badge/Scheduler-Cron%20%26%20Systemd-orange)
![Integrity](https://img.shields.io/badge/Security-SHA256%20Checksums-blue)
![License](https://img.shields.io/badge/License-MIT-green)

A modular, enterprise-ready Linux backup, disaster recovery, and system monitoring suite written in Bash. Designed with POSIX-compliant scripting best practices, concurrency locking, SHA256 integrity verification, automated retention pruning, webhook alerting, and automated cron scheduling.

---

## 📌 Architecture Overview

```
                        +----------------------------+
                        |   suite.sh (Master CLI)    |
                        +--------------+-------------+
                                       |
       +-------------------------------+-------------------------------+
       |               |               |               |               |
       v               v               v               v               v
+-------------+ +-------------+ +-------------+ +-------------+ +-------------+
|  backup.sh  | | restore.sh  | | cleanup.sh  | |health-chk.sh| | monitor.sh  |
+------+------+ +------+------+ +------+------+ +------+------+ +------+------+
       |               |               |               |               |
       | flock lock    | SHA256 verify | Retention cap | Disk usage %  | Error parsing
       | tar gzip      | Decompression | Space reclaim | Age warning   | Webhook post
       v               v               v               v               v
+-----------------------------------------------------------------------------+
|                  Storage Layer (backups/ & logs/ & config/)                 |
+-----------------------------------------------------------------------------+
                                       ^
                                       |
                     +-----------------+-----------------+
                     |                                   |
           +---------+---------+               +---------+---------+
           | cron/setup-cron.sh|               |  systemd timers   |
           | (Day 9 Automation)|               |  (Enterprise Alt) |
           +-------------------+               +-------------------+
```

---

## ✨ Features

- **Automated Compression & Archival:** Timestamped archives using `tar` and `gzip` with customizable compression levels.
- **Data Integrity Assurance:** Automatic `SHA-256` checksum calculation and verification prior to restore operations.
- **Cron-Safe Concurrency Locking:** File locking via `flock` prevents race conditions and corrupted overlaps when running automated jobs.
- **Intelligent Exclusion Engine:** Configurable exclusion rules via `config/exclude.txt` (skips `.git`, cache, temporary files, `node_modules`).
- **Automated Retention Management:** Automatically purges archives older than `$RETENTION_DAYS` (default 10 days) and enforces a maximum backup safety ceiling.
- **Automated Scheduling (Day 9 Milestone):**
  - Complete crontab automation suite with one-click installer (`cron/setup-cron.sh`).
  - Pre-configured `systemd` service and timer units for enterprise Linux environments.
- **Comprehensive Health Checks:** 5-step diagnostic monitoring disk usage, directory permissions, archive integrity, and schedule presence.
- **Centralized Master CLI (Day 10 Milestone):** Interactive terminal dashboard (`suite.sh`) to execute, test, and manage all functions.
- **Continuous Integration / Test Engine:** Automated end-to-end integration test (`tests/test_suite.sh`) to validate the entire lifecycle.

---

## 📁 Repository Structure

```text
linux-backup-suite/
├── suite.sh                   # Master interactive CLI Control Panel (Day 10)
├── backup.sh                  # Core automated backup engine with locking & SHA256
├── restore.sh                 # Interactive & CLI-driven disaster recovery engine
├── cleanup.sh                 # Retention policy engine (purges expired backups)
├── health-check.sh            # 5-phase health diagnostic and integrity verifier
├── monitor.sh                 # Metric aggregator & Discord/Slack webhook alerter
├── config/
│   ├── backup.conf            # Central configuration file (retention, paths, thresholds)
│   └── exclude.txt            # Patterns to exclude from backup archives
├── cron/                      # Automated Scheduling Suite (Day 9)
│   ├── crontab.sample         # Production cron job definitions
│   └── setup-cron.sh          # One-click interactive crontab installer & manager
├── systemd/                   # Modern Linux Systemd Alternative
│   ├── backup-suite.service   # Systemd unit file
│   └── backup-suite.timer     # Systemd daily timer
├── tests/                     # Automated Testing Suite (Day 10)
│   └── test_suite.sh          # End-to-end integration test runner
├── .gitignore                 # Excludes local test files, archives, and logs
└── README.md                  # Complete documentation
```

---

## 📅 10-Day Development Roadmap

| Day | Module / Milestone | Description | Status |
| :--- | :--- | :--- | :---: |
| **Day 1** | Project Architecture & Scaffolding | Established directory hierarchy, POSIX conventions, git setup, and `.gitignore`. | ✅ Complete |
| **Day 2** | Configuration Management | Built dynamic config loader (`backup.conf`) and exclusion rules (`exclude.txt`). | ✅ Complete |
| **Day 3** | Core Backup Engine | Implemented `backup.sh` with `flock` locking, `tar -czf`, and `sha256sum` generation. | ✅ Complete |
| **Day 4** | Disaster Recovery Engine | Developed `restore.sh` with interactive selector, destination validation, and checksum checks. | ✅ Complete |
| **Day 5** | Retention & Lifecycle Cleanup | Created `cleanup.sh` supporting 10-day retention policies, archive caps, and `--dry-run`. | ✅ Complete |
| **Day 6** | System Health Diagnostics | Engineered `health-check.sh` with 5 diagnostic checks for disk %, stale backups, and corruption. | ✅ Complete |
| **Day 7** | Monitoring & Alerting Engine | Developed `monitor.sh` with log parsing and Slack/Discord webhook alerts. | ✅ Complete |
| **Day 8** | Unified Master CLI Dashboard | Built `suite.sh` interactive TUI menu for streamlined operations. | ✅ Complete |
| **Day 9** | **Cron & Scheduling Automation** | **Engineered `cron/setup-cron.sh`, `crontab.sample`, and `systemd` timers for unattended operation.** | ✅ Complete |
| **Day 10**| **E2E Testing & Hardening** | **Built `tests/test_suite.sh`, sanitized code, created production documentation & portfolio showcase.** | ✅ Complete |

---

## 🚀 Quick Start Guide

### 1. Clone & Setup Permissions

```bash
git clone https://github.com/Aishwary-gupta/linux-backup-suite.git
cd linux-backup-suite
chmod +x *.sh cron/*.sh tests/*.sh
```

### 2. Configure Settings

Edit `config/backup.conf` to configure your target directories and retention policy:

```bash
nano config/backup.conf
```

Key variables:
- `RETENTION_DAYS=10` : Retain archives for 10 days before automated purge.
- `BACKUP_DIR="./backups"` : Destination storage path.
- `DISK_ALERT_THRESHOLD=85` : Warn if disk usage exceeds 85%.

### 3. Launch Master Suite Dashboard

Run the unified control panel:

```bash
./suite.sh
```

---

## ⚙️ Usage & Module Reference

### 1. Creating a Backup (`backup.sh`)

Manually back up a specific directory or use the default configured in `backup.conf`:

```bash
# Back up a specific directory
./backup.sh /var/www/html

# Back up default configured directory
./backup.sh
```

### 2. Restoring from Backup (`restore.sh`)

Supports both an **interactive menu** and **non-interactive CLI mode**:

```bash
# Interactive Mode (Prompts with a numbered list of available backups)
./restore.sh

# Non-Interactive CLI Mode (Ideal for scripts & automation)
./restore.sh backups/backup_project_2026-09-05.tar.gz /path/to/restore_folder
```

### 3. Automated Cleanup & Retention (`cleanup.sh`)

Purges expired backups past the retention threshold (default: 10 days):

```bash
# Test what would be deleted without making any changes
./cleanup.sh --dry-run

# Execute real cleanup
./cleanup.sh
```

### 4. Health Check & Diagnostics (`health-check.sh`)

Runs diagnostic checks across directories, disk capacity, freshness, and archive integrity:

```bash
./health-check.sh
```

### 5. Automated Monitoring & Alerts (`monitor.sh`)

Parses logs, checks for failures, and dispatches webhook alerts:

```bash
./monitor.sh
```

---

## ⏰ Day 9: Cron Automation & Scheduling

To ensure automated 24/7 operations without manual intervention, use the built-in scheduler manager:

### Option A: Interactive Cron Installer (Recommended)

```bash
./cron/setup-cron.sh
```
Select **Option 2** to automatically register the following schedule into your crontab:

```cron
# Daily Backup at 2:00 AM
0 2 * * * /path/to/linux-backup-suite/backup.sh >> /path/to/linux-backup-suite/logs/cron_backup.log 2>&1

# Weekly Retention Purge at 3:30 AM every Sunday
30 3 * * 0 /path/to/linux-backup-suite/cleanup.sh >> /path/to/linux-backup-suite/logs/cron_cleanup.log 2>&1

# Daily Health Diagnostic at 6:00 AM
0 6 * * * /path/to/linux-backup-suite/health-check.sh >> /path/to/linux-backup-suite/logs/cron_health.log 2>&1

# Daily Monitoring at 8:00 AM
0 8 * * * /path/to/linux-backup-suite/monitor.sh >> /path/to/linux-backup-suite/logs/cron_monitor.log 2>&1
```

### Option B: Modern Linux Systemd Timer

For environments using `systemd`:

```bash
# Copy unit files
sudo cp systemd/backup-suite.service /etc/systemd/system/
sudo cp systemd/backup-suite.timer /etc/systemd/system/

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable --now backup-suite.timer

# Verify timer status
systemctl list-timers | grep backup-suite
```

---

## 🧪 Day 10: Automated Integration Testing

Validate all components end-to-end within an isolated sandbox:

```bash
./tests/test_suite.sh
```

The test runner will:
1. Construct dummy directories with live data, exclusion candidates (`.tmp`, `node_modules`).
2. Trigger `backup.sh` and verify archive creation.
3. Validate that exclusion rules strictly filtered unnecessary files.
4. Verify SHA256 checksum matching.
5. Perform an extraction with `restore.sh` and assert data integrity.
6. Test `health-check.sh` diagnostics.
7. Clean up the test environment and report exit code `0`.

---

## 💼 Portfolio & Resume Highlights

When presenting this project to hiring managers or on your resume, you can highlight:

- **Linux & Bash Automation:** Designed and implemented an enterprise-grade automated backup and disaster recovery suite in Bash with strict error handling (`set -eo pipefail`), `flock` process concurrency protection, and signal traps.
- **Scheduled Orchestration:** Automated off-peak archival and weekly retention pruning via `crontab` and `systemd` timers, reducing manual maintenance overhead by 100%.
- **Data Integrity & Security:** Built automated SHA-256 cryptographic checksum generation and pre-restore validation to eliminate corrupted extractions.
- **Monitoring & Observability:** Implemented automated log rotation, disk space threshold alerts, and Discord/Slack webhook dispatching for proactive incident response.
- **Automated Testing:** Authored end-to-end integration test harness (`tests/test_suite.sh`) validating compression, retention policies, and file recovery.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
