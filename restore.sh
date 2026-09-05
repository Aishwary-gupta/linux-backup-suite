#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Restore Script
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

LOG_FILE="$LOG_DIR/restore.log"
mkdir -p "$LOG_DIR"

# ---------- Logging Function ----------
log_message() {
    local level="$1"
    local message="$2"
    local log_entry="[$(date +"%Y-%m-%d %H:%M:%S")] [$level] $message"
    echo "$log_entry" >> "$LOG_FILE"
    
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${RESET} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${RESET} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${RESET} $message" >&2 ;;
        *)       echo "$message" ;;
    esac
}

# ---------- Header Banner ----------
echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}       LINUX BACKUP SUITE - RESTORE SYSTEM            ${RESET}"
echo -e "${BLUE}======================================================${RESET}"

# ---------- Check Backup Directory ----------
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "ERROR" "Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

# ---------- Identify Available Backups ----------
shopt -s nullglob
BACKUP_FILES=("$BACKUP_DIR"/*.tar.gz)
shopt -u nullglob

if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
    log_message "ERROR" "No backup archive files (.tar.gz) found in $BACKUP_DIR."
    echo -e "${RED}[!] No backups available to restore.${RESET}"
    exit 1
fi

SELECTED_ARCHIVE=""
TARGET_DIR="${2:-}"

# Check if archive path was provided as first argument
if [ -n "$1" ]; then
    if [ -f "$1" ]; then
        SELECTED_ARCHIVE="$1"
    elif [ -f "$BACKUP_DIR/$1" ]; then
        SELECTED_ARCHIVE="$BACKUP_DIR/$1"
    else
        log_message "ERROR" "Specified archive '$1' not found."
        exit 1
    fi
else
    # Interactive selection mode
    echo -e "${CYAN}Available Backups:${RESET}"
    echo -e "${BLUE}------------------------------------------------------${RESET}"
    printf "%-5s | %-40s | %-10s\n" "No." "Archive Name" "Size"
    echo -e "${BLUE}------------------------------------------------------${RESET}"
    
    for i in "${!BACKUP_FILES[@]}"; do
        ARCHIVE_BASENAME=$(basename "${BACKUP_FILES[$i]}")
        ARCHIVE_SIZE=$(du -h "${BACKUP_FILES[$i]}" | awk '{print $1}')
        printf "%-5s | %-40s | %-10s\n" "[$((i + 1))]" "$ARCHIVE_BASENAME" "$ARCHIVE_SIZE"
    done
    echo -e "${BLUE}------------------------------------------------------${RESET}"
    
    read -rp "Select backup number to restore (1-${#BACKUP_FILES[@]}): " USER_CHOICE
    
    if ! [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] || [ "$USER_CHOICE" -lt 1 ] || [ "$USER_CHOICE" -gt "${#BACKUP_FILES[@]}" ]; then
        echo -e "${RED}[ERROR] Invalid selection.${RESET}"
        exit 1
    fi
    
    SELECTED_ARCHIVE="${BACKUP_FILES[$((USER_CHOICE - 1))]}"
fi

# ---------- Prompt for Destination Directory if not supplied ----------
if [ -z "$TARGET_DIR" ]; then
    DEFAULT_RESTORE_TARGET="$SCRIPT_DIR/restored_data"
    read -rp "Enter destination directory [$DEFAULT_RESTORE_TARGET]: " INPUT_TARGET
    TARGET_DIR="${INPUT_TARGET:-$DEFAULT_RESTORE_TARGET}"
fi

mkdir -p "$TARGET_DIR"

log_message "INFO" "Restore target archive: $(basename "$SELECTED_ARCHIVE")"
log_message "INFO" "Restore destination directory: $TARGET_DIR"

# ---------- Verify Checksum Integrity ----------
CHECKSUM_FILE="${SELECTED_ARCHIVE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo -e "${CYAN}Verifying archive SHA256 checksum...${RESET}"
    if (cd "$(dirname "$SELECTED_ARCHIVE")" && sha256sum -c "$(basename "$CHECKSUM_FILE")" > /dev/null 2>&1); then
        log_message "INFO" "SHA256 checksum verification: PASSED"
    else
        log_message "ERROR" "SHA256 checksum verification: FAILED! File may be corrupt or tampered."
        echo -e "${RED}[ERROR] Integrity check failed. Aborting restore to prevent corrupted extraction.${RESET}" >&2
        exit 1
    fi
else
    log_message "WARN" "No SHA256 checksum file found. Proceeding with tar test extraction..."
fi

# ---------- Test Archive Integrity with Tar ----------
if ! tar -tzf "$SELECTED_ARCHIVE" >/dev/null 2>&1; then
    log_message "ERROR" "Corrupt archive: tar integrity test failed."
    echo -e "${RED}[ERROR] Archive cannot be decompressed.${RESET}" >&2
    exit 1
fi

# ---------- Execute Restoration ----------
echo -e "${CYAN}Extracting archive to $TARGET_DIR...${RESET}"
START_TIME=$(date +%s)

if tar -xzf "$SELECTED_ARCHIVE" -C "$TARGET_DIR" 2>> "$LOG_FILE"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_message "INFO" "Restore completed successfully in ${DURATION}s to $TARGET_DIR"
    echo -e "${GREEN}======================================================${RESET}"
    echo -e "${GREEN}${BOLD}[PASS] Restore process completed successfully!${RESET}"
    echo -e "Files restored to: $TARGET_DIR"
    echo -e "${GREEN}======================================================${RESET}"
    exit 0
else
    log_message "ERROR" "Failed to extract archive. See $LOG_FILE for details."
    echo -e "${RED}[ERROR] Restore failed.${RESET}" >&2
    exit 1
fi
