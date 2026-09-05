#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Automated Cron Scheduler Installer
# Author: Aishwary Gupta
# Project: Linux Backup Suite
# Version: 2.0 (Day 9 Milestone)
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- Colors ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}       CRON AUTOMATION INSTALLER (DAY 9 WORK)         ${RESET}"
echo -e "${BLUE}======================================================${RESET}"
echo -e "${CYAN}Suite Root Directory:${RESET} $SCRIPT_DIR"
echo -e "${BLUE}------------------------------------------------------${RESET}"

CRON_TAG="# LINUX_BACKUP_SUITE_SCHEDULE"

show_current_cron() {
    echo -e "${CYAN}Current User Crontab Entries:${RESET}"
    echo -e "${BLUE}------------------------------------------------------${RESET}"
    crontab -l 2>/dev/null || echo "(No crontab installed for current user)"
    echo -e "${BLUE}------------------------------------------------------${RESET}"
}

install_cron() {
    echo -e "${CYAN}Generating automated cron schedules...${RESET}"
    
    # Generate schedule entries using current project absolute path
    NEW_CRON_BLOCK=$(cat <<EOF
$CRON_TAG - BEGIN
# Automated Daily Backup at 02:00 AM
0 2 * * * "$SCRIPT_DIR/backup.sh" >> "$SCRIPT_DIR/logs/cron_backup.log" 2>&1
# Automated Retention Cleanup every Sunday at 03:30 AM
30 3 * * 0 "$SCRIPT_DIR/cleanup.sh" >> "$SCRIPT_DIR/logs/cron_cleanup.log" 2>&1
# Daily Health Integrity Check at 06:00 AM
0 6 * * * "$SCRIPT_DIR/health-check.sh" >> "$SCRIPT_DIR/logs/cron_health.log" 2>&1
# Daily Monitoring & Alerts at 08:00 AM
0 8 * * * "$SCRIPT_DIR/monitor.sh" >> "$SCRIPT_DIR/logs/cron_monitor.log" 2>&1
$CRON_TAG - END
EOF
)

    # Read existing crontab without existing suite block
    EXISTING_CRON=$(crontab -l 2>/dev/null | sed "/$CRON_TAG - BEGIN/,/$CRON_TAG - END/d" || true)

    # Combine
    COMBINED_CRON=$(printf "%s\n\n%s\n" "$EXISTING_CRON" "$NEW_CRON_BLOCK" | sed '/^[[:space:]]*$/N;/^[[:space:]]*\n[[:space:]]*$/D')

    # Install to crontab
    echo "$COMBINED_CRON" | crontab -

    echo -e "${GREEN}${BOLD}[PASS] Automated Cron jobs installed successfully!${RESET}"
    echo -e "Scheduled jobs:"
    echo -e "  - Daily Backup           : 02:00 AM every night"
    echo -e "  - Weekly Retention Purge : 03:30 AM every Sunday"
    echo -e "  - Daily Health Check     : 06:00 AM daily"
    echo -e "  - Daily Monitor & Alerts : 08:00 AM daily"
}

remove_cron() {
    echo -e "${YELLOW}Removing Linux Backup Suite schedules from crontab...${RESET}"
    EXISTING_CRON=$(crontab -l 2>/dev/null || true)
    
    if [ -z "$EXISTING_CRON" ]; then
        echo -e "${YELLOW}Crontab is already empty.${RESET}"
        return
    fi
    
    FILTERED_CRON=$(echo "$EXISTING_CRON" | sed "/$CRON_TAG - BEGIN/,/$CRON_TAG - END/d")
    echo "$FILTERED_CRON" | crontab -
    echo -e "${GREEN}[PASS] Backup Suite cron jobs removed from crontab.${RESET}"
}

echo "1) View current crontab"
echo "2) Install automated cron schedules"
echo "3) Remove backup suite cron schedules"
echo "4) Exit"
echo

read -rp "Select an option [1-4]: " CHOICE

case "$CHOICE" in
    1) show_current_cron ;;
    2) install_cron ;;
    3) remove_cron ;;
    4) echo "Exiting."; exit 0 ;;
    *) echo -e "${RED}Invalid choice.${RESET}"; exit 1 ;;
esac
