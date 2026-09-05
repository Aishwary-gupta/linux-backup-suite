#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# System Health & Integrity Diagnostic Script
# Author: Aishwary Gupta
# Project: Linux Backup Suite
# Version: 2.0
# ==============================================================================

set -eo pipefail

# ---------- Resolve Base Directory ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- Configuration ----------
CONFIG_FILE="$SCRIPT_DIR/config/backup.conf"

# ---------- ANSI Color Codes ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ---------- Check Configuration File ----------
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[ERROR] Configuration file not found: $CONFIG_FILE${RESET}" >&2
    exit 1
fi

source "$CONFIG_FILE"

[[ "$BACKUP_DIR" != /* ]] && BACKUP_DIR="$SCRIPT_DIR/$BACKUP_DIR"
[[ "$LOG_DIR" != /* ]] && LOG_DIR="$SCRIPT_DIR/$LOG_DIR"

LOG_FILE="$LOG_DIR/health-check.log"
mkdir -p "$LOG_DIR"

log_message() {
    local level="$1"
    local message="$2"
    local log_entry="[$(date +"%Y-%m-%d %H:%M:%S")] [$level] $message"
    echo "$log_entry" >> "$LOG_FILE"
}

TOTAL_CHECKS=5
PASSED_CHECKS=0
WARNINGS=0
ERRORS=0

echo
echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}          LINUX BACKUP SUITE - HEALTH CHECK           ${RESET}"
echo -e "${BLUE}======================================================${RESET}"
echo

log_message "INFO" "Health check started."

# ==============================================================================
# CHECK 1: Storage & Log Directory Permissions
# ==============================================================================
echo -e "${CYAN}[1/5] Checking Directories and Permissions...${RESET}"

if [ -d "$BACKUP_DIR" ] && [ -w "$BACKUP_DIR" ]; then
    echo -e "  ${GREEN}[PASS]${RESET} Backup directory exists and is writable: $BACKUP_DIR"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}[FAIL]${RESET} Backup directory is missing or not writable: $BACKUP_DIR"
    ERRORS=$((ERRORS + 1))
    log_message "ERROR" "Directory permission failure: $BACKUP_DIR"
fi

if [ -d "$LOG_DIR" ] && [ -w "$LOG_DIR" ]; then
    echo -e "  ${GREEN}[PASS]${RESET} Log directory exists and is writable: $LOG_DIR"
else
    echo -e "  ${YELLOW}[WARN]${RESET} Log directory issue: $LOG_DIR"
    WARNINGS=$((WARNINGS + 1))
fi

# ==============================================================================
# CHECK 2: Disk Space & Capacity
# ==============================================================================
echo -e "${CYAN}[2/5] Checking Disk Usage Threshold (${DISK_ALERT_THRESHOLD}% limit)...${RESET}"

DISK_USAGE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {gsub("%","",$5); print $5}')
DISK_AVAIL=$(df -h -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')

if [ -n "$DISK_USAGE" ]; then
    if [ "$DISK_USAGE" -ge "$DISK_ALERT_THRESHOLD" ]; then
        echo -e "  ${RED}[WARN]${RESET} Disk capacity critical! Current usage: ${DISK_USAGE}% (Available: $DISK_AVAIL)"
        WARNINGS=$((WARNINGS + 1))
        log_message "WARN" "Disk usage exceeded threshold: ${DISK_USAGE}%"
    else
        echo -e "  ${GREEN}[PASS]${RESET} Disk usage healthy: ${DISK_USAGE}% utilized ($DISK_AVAIL available)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
else
    echo -e "  ${YELLOW}[WARN]${RESET} Unable to query disk usage."
fi

# ==============================================================================
# CHECK 3: Backup Freshness & Recency
# ==============================================================================
echo -e "${CYAN}[3/5] Checking Backup Freshness (Within ${MAX_BACKUP_AGE_WARNING_DAYS} days)...${RESET}"

shopt -s nullglob
BACKUPS=($(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || true))
shopt -u nullglob

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}[WARN]${RESET} No backup archives found in $BACKUP_DIR. Run a backup first."
    WARNINGS=$((WARNINGS + 1))
    log_message "WARN" "No backups found during health check."
else
    LATEST_BACKUP="${BACKUPS[0]}"
    LATEST_TIMESTAMP=$(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || stat -f %m "$LATEST_BACKUP" 2>/dev/null)
    CURRENT_TIMESTAMP=$(date +%s)
    AGE_HOURS=$(( (CURRENT_TIMESTAMP - LATEST_TIMESTAMP) / 3600 ))
    MAX_AGE_HOURS=$(( MAX_BACKUP_AGE_WARNING_DAYS * 24 ))
    
    if [ "$AGE_HOURS" -gt "$MAX_AGE_HOURS" ]; then
        echo -e "  ${YELLOW}[WARN]${RESET} Most recent backup is $AGE_HOURS hours old (Exceeds ${MAX_AGE_HOURS}h threshold): $(basename "$LATEST_BACKUP")"
        WARNINGS=$((WARNINGS + 1))
        log_message "WARN" "Stale backup detected: $AGE_HOURS hours old"
    else
        echo -e "  ${GREEN}[PASS]${RESET} Fresh backup detected: $(basename "$LATEST_BACKUP") (${AGE_HOURS}h ago)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
fi

# ==============================================================================
# CHECK 4: Archive Integrity & Checksum Verification
# ==============================================================================
echo -e "${CYAN}[4/5] Verifying Archive Integrity (Tar gzip test)...${RESET}"

if [ ${#BACKUPS[@]} -gt 0 ]; then
    LATEST_ARCHIVE="${BACKUPS[0]}"
    if tar -tzf "$LATEST_ARCHIVE" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${RESET} Latest archive integrity verified: $(basename "$LATEST_ARCHIVE")"
        
        # Check SHA256 if present
        if [ -f "${LATEST_ARCHIVE}.sha256" ]; then
            if (cd "$BACKUP_DIR" && sha256sum -c "$(basename "${LATEST_ARCHIVE}.sha256")" >/dev/null 2>&1); then
                echo -e "  ${GREEN}[PASS]${RESET} SHA256 checksum matched."
            else
                echo -e "  ${RED}[FAIL]${RESET} SHA256 checksum MISMATCH!"
                ERRORS=$((ERRORS + 1))
            fi
        fi
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}[FAIL]${RESET} Corrupted archive detected: $(basename "$LATEST_ARCHIVE")"
        ERRORS=$((ERRORS + 1))
        log_message "ERROR" "Archive corruption in $LATEST_ARCHIVE"
    fi
else
    echo -e "  ${YELLOW}[SKIP]${RESET} No archive available to test integrity."
fi

# ==============================================================================
# CHECK 5: Cron / Automation Schedule Verification
# ==============================================================================
echo -e "${CYAN}[5/5] Checking Automated Cron Schedule...${RESET}"

if crontab -l 2>/dev/null | grep -qE "backup\.sh|linux-backup-suite"; then
    echo -e "  ${GREEN}[PASS]${RESET} Automated cron jobs detected in user crontab."
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${YELLOW}[INFO]${RESET} No active crontab entry for backup-suite. (Run ./cron/setup-cron.sh to enable)"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo
echo -e "${BLUE}======================================================${RESET}"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}[STATUS: HEALTHY] All system checks passed successfully!${RESET}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}[STATUS: ATTENTION] Checks passed with $WARNINGS warning(s).${RESET}"
else
    echo -e "${RED}${BOLD}[STATUS: UNHEALTHY] Encountered $ERRORS error(s) and $WARNINGS warning(s).${RESET}"
fi
echo -e "Passed: $PASSED_CHECKS | Warnings: $WARNINGS | Errors: $ERRORS"
echo -e "${BLUE}======================================================${RESET}"
echo

log_message "INFO" "Health check finished. Passed: $PASSED_CHECKS, Warnings: $WARNINGS, Errors: $ERRORS."

if [ "$ERRORS" -gt 0 ]; then
    exit 2
elif [ "$WARNINGS" -gt 0 ]; then
    exit 1
fi
exit 0
