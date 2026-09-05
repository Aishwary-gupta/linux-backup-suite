#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Log Analyzer & Alert Monitoring Script
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

BACKUP_LOG="$LOG_DIR/backup.log"
MONITOR_LOG="$LOG_DIR/monitor.log"
mkdir -p "$LOG_DIR"

log_monitor() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> "$MONITOR_LOG"
}

# ---------- Header Banner ----------
echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}       LINUX BACKUP SUITE - MONITORING & ALERTS       ${RESET}"
echo -e "${BLUE}======================================================${RESET}"

# ---------- Compute Backup Metrics ----------
shopt -s nullglob
ALL_BACKUPS=("$BACKUP_DIR"/backup_*.tar.gz)
shopt -u nullglob

BACKUP_COUNT=${#ALL_BACKUPS[@]}
TOTAL_STORAGE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "0B")

if [ "$BACKUP_COUNT" -gt 0 ]; then
    LATEST_BACKUP=$(ls -1t "$BACKUP_DIR"/backup_*.tar.gz | head -n1)
    LATEST_NAME=$(basename "$LATEST_BACKUP")
    LATEST_DATE=$(date -r "$LATEST_BACKUP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c "%y" "$LATEST_BACKUP" 2>/dev/null | cut -d'.' -f1)
else
    LATEST_NAME="None"
    LATEST_DATE="N/A"
fi

# ---------- Scan Logs for Recent Errors (Last 24 hours) ----------
ERROR_COUNT=0
if [ -f "$BACKUP_LOG" ]; then
    ERROR_COUNT=$(grep -c "\[ERROR\]" "$BACKUP_LOG" || echo 0)
fi

# ---------- Print Dashboard Summary ----------
echo -e "${CYAN}System Status Overview:${RESET}"
echo -e "  - Total Archives  : ${BOLD}$BACKUP_COUNT${RESET}"
echo -e "  - Total Size      : ${BOLD}$TOTAL_STORAGE${RESET}"
echo -e "  - Latest Backup   : ${BOLD}$LATEST_NAME${RESET}"
echo -e "  - Last Run Date   : $LATEST_DATE"
echo -e "  - Error Logs (Tot): $ERROR_COUNT"
echo -e "${BLUE}------------------------------------------------------${RESET}"

# ---------- Webhook Alert Function ----------
send_webhook_alert() {
    local status="$1"
    local message="$2"
    
    if [ "$WEBHOOK_NOTIFICATIONS_ENABLED" = "true" ] && [ -n "$WEBHOOK_URL" ]; then
        echo -e "${CYAN}Dispatching webhook alert to endpoint...${RESET}"
        
        # Format JSON payload compatible with Discord / Slack
        PAYLOAD=$(cat <<EOF
{
  "username": "BackupSuite Monitor",
  "content": "**[Backup Suite Alert - $status]**\n$message\n*Host:* $(hostname) | *Time:* $(date)"
}
EOF
)
        if curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL" >/dev/null; then
            echo -e "${GREEN}[PASS] Webhook notification dispatched.${RESET}"
            log_monitor "Alert successfully sent to webhook: $status"
        else
            echo -e "${RED}[WARN] Failed to send webhook alert.${RESET}"
            log_monitor "Webhook delivery failure: $status"
        fi
    fi
}

# ---------- Alert Condition Check ----------
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}[ALERT] Found $ERROR_COUNT error entries in $BACKUP_LOG!${RESET}"
    echo -e "${YELLOW}Recent log failures:${RESET}"
    grep "\[ERROR\]" "$BACKUP_LOG" | tail -n 3
    send_webhook_alert "CRITICAL" "Warning: Backup Suite detected $ERROR_COUNT error log entries on $(hostname)."
elif [ "$BACKUP_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}[ALERT] Zero backups found in storage!${RESET}"
    send_webhook_alert "WARNING" "Warning: No backups exist in storage directory."
else
    echo -e "${GREEN}[OK] All services normal. No recent critical errors detected.${RESET}"
fi

echo -e "${BLUE}======================================================${RESET}"
log_monitor "Monitoring executed. Archives: $BACKUP_COUNT, Storage: $TOTAL_STORAGE, Errors: $ERROR_COUNT"
exit 0
