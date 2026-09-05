#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Master Control Panel (CLI Dashboard)
# Author: Aishwary Gupta
# Project: Linux Backup Suite
# Version: 2.0 
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- ANSI Colors ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"
RESET="\e[0m"

# Ensure execution permissions for all suite scripts
chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/cron/*.sh "$SCRIPT_DIR"/tests/*.sh 2>/dev/null || true

show_banner() {
    clear
    echo -e "${BLUE}======================================================================${RESET}"
    echo -e "${BLUE}${BOLD}             LINUX BACKUP AUTOMATION SUITE v2.0                       ${RESET}"
    echo -e "${CYAN}             Production Backup, Recovery, Monitoring & Cron           ${RESET}"
    echo -e "${BLUE}======================================================================${RESET}"
    echo -e "Host: $(hostname) | User: $(whoami) | Date: $(date +"%Y-%m-%d %H:%M")"
    echo -e "${BLUE}----------------------------------------------------------------------${RESET}"
}

pause() {
    echo
    read -rp "Press [Enter] to return to menu..."
}

while true; do
    show_banner
    echo -e "${BOLD}Select an operation:${RESET}"
    echo
    echo -e "  ${GREEN}1)${RESET} Create New Backup (${CYAN}./backup.sh${RESET})"
    echo -e "  ${GREEN}2)${RESET} Restore Data from Backup (${CYAN}./restore.sh${RESET})"
    echo -e "  ${GREEN}3)${RESET} System Health & Integrity Check (${CYAN}./health-check.sh${RESET})"
    echo -e "  ${GREEN}4)${RESET} Run Retention Cleanup (${CYAN}./cleanup.sh${RESET})"
    echo -e "  ${GREEN}5)${RESET} System Monitoring & Alerts (${CYAN}./monitor.sh${RESET})"
    echo -e "  ${MAGENTA}6)${RESET} Manage Automated Cron Scheduling (${CYAN}./cron/setup-cron.sh${RESET})"
    echo -e "  ${MAGENTA}7)${RESET} Run End-to-End Automated Test Suite (${CYAN}./tests/test_suite.sh${RESET})"
    echo -e "  ${YELLOW}8)${RESET} View Recent Activity Logs"
    echo -e "  ${RED}9)${RESET} Exit"
    echo
    read -rp "Enter choice [1-9]: " OPTION
    echo

    case "$OPTION" in
        1)
            read -rp "Enter directory path to backup (Leave empty for default): " SRC
            "$SCRIPT_DIR/backup.sh" "$SRC"
            pause
            ;;
        2)
            "$SCRIPT_DIR/restore.sh"
            pause
            ;;
        3)
            "$SCRIPT_DIR/health-check.sh" || true
            pause
            ;;
        4)
            read -rp "Simulate dry-run first? (y/n) [y]: " DRY_CHOICE
            if [[ "$DRY_CHOICE" =~ ^[Nn]$ ]]; then
                "$SCRIPT_DIR/cleanup.sh"
            else
                "$SCRIPT_DIR/cleanup.sh" --dry-run
            fi
            pause
            ;;
        5)
            "$SCRIPT_DIR/monitor.sh"
            pause
            ;;
        6)
            "$SCRIPT_DIR/cron/setup-cron.sh"
            pause
            ;;
        7)
            "$SCRIPT_DIR/tests/test_suite.sh"
            pause
            ;;
        8)
            echo -e "${CYAN}Available logs in $SCRIPT_DIR/logs:${RESET}"
            ls -lh "$SCRIPT_DIR/logs" 2>/dev/null || echo "No logs found yet."
            echo
            read -rp "Enter log filename to view (e.g., backup.log, health-check.log): " LOG_NAME
            if [ -f "$SCRIPT_DIR/logs/$LOG_NAME" ]; then
                echo -e "${BLUE}--- Last 25 lines of $LOG_NAME ---${RESET}"
                tail -n 25 "$SCRIPT_DIR/logs/$LOG_NAME"
            else
                echo -e "${RED}File not found.${RESET}"
            fi
            pause
            ;;
        9)
            echo -e "${GREEN}Exiting Linux Backup Suite. Goodbye!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose 1-9.${RESET}"
            sleep 1
            ;;
    esac
done
