#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Core Backup Script
# Author: Aishwary Gupta
# Project: Linux Backup Suite
# Version: 2.0
# ==============================================================================

set -eo pipefail

# ---------- Resolve Base Directory (Cron-safe) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- Configuration ----------
CONFIG_FILE="$SCRIPT_DIR/config/backup.conf"
EXCLUDE_FILE="$SCRIPT_DIR/config/exclude.txt"

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

# Resolve directories relative to script location if relative paths are used
[[ "$BACKUP_DIR" != /* ]] && BACKUP_DIR="$SCRIPT_DIR/$BACKUP_DIR"
[[ "$LOG_DIR" != /* ]] && LOG_DIR="$SCRIPT_DIR/$LOG_DIR"
[[ "$EXCLUDE_FILE" != /* ]] && EXCLUDE_FILE="$SCRIPT_DIR/$EXCLUDE_FILE"

LOG_FILE="$LOG_DIR/backup.log"
LOCK_FILE="/tmp/linux_backup_suite.lock"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# ---------- Ensure Required Directories Exist ----------
mkdir -p "$BACKUP_DIR"
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

# ---------- Concurrency Lock (Cron Protection) ----------
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log_message "ERROR" "Another backup process is already running. Exiting to avoid corruption."
    exit 1
fi

# ---------- Input Source Directory Handling ----------
SOURCE_DIR="${1:-$DEFAULT_SOURCE_DIR}"

# ---------- Header Banner ----------
echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}            LINUX BACKUP SUITE - BACKUP               ${RESET}"
echo -e "${BLUE}======================================================${RESET}"
echo -e "${CYAN}Target Source :${RESET} $SOURCE_DIR"
echo -e "${CYAN}Destination   :${RESET} $BACKUP_DIR"
echo -e "${CYAN}Timestamp     :${RESET} $TIMESTAMP"
echo -e "${BLUE}------------------------------------------------------${RESET}"

# ---------- Validate Source Directory ----------
if [ -z "$SOURCE_DIR" ]; then
    log_message "ERROR" "No source directory supplied and DEFAULT_SOURCE_DIR is not configured."
    echo -e "${YELLOW}Usage: $0 <directory_to_backup>${RESET}"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    log_message "ERROR" "Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

if [ ! -r "$SOURCE_DIR" ]; then
    log_message "ERROR" "Permission denied: Cannot read source directory '$SOURCE_DIR'."
    exit 1
fi

# ---------- Check Available Storage Space ----------
AVAILABLE_KB=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
ESTIMATED_KB=$(du -s "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')

if [ -n "$ESTIMATED_KB" ] && [ -n "$AVAILABLE_KB" ]; then
    if [ "$AVAILABLE_KB" -lt "$ESTIMATED_KB" ]; then
        log_message "ERROR" "Insufficient disk space. Available: ${AVAILABLE_KB}KB, Estimated: ${ESTIMATED_KB}KB."
        exit 1
    fi
fi

# ---------- Format Archive Name ----------
CLEAN_NAME=$(basename "$(realpath "$SOURCE_DIR")" | tr -cd '[:alnum:]_-')
ARCHIVE_NAME="backup_${CLEAN_NAME}_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

# ---------- Build Tar Exclusion Arguments ----------
TAR_EXCLUDES=()
if [ -f "$EXCLUDE_FILE" ]; then
    TAR_EXCLUDES+=(--exclude-from="$EXCLUDE_FILE")
    log_message "INFO" "Applying exclusions from: $EXCLUDE_FILE"
fi

# ---------- Execute Backup Archive Creation ----------
log_message "INFO" "Starting compression for: $SOURCE_DIR"

PARENT_DIR="$(dirname "$(realpath "$SOURCE_DIR")")"
TARGET_DIR_NAME="$(basename "$(realpath "$SOURCE_DIR")")"

START_TIME=$(date +%s)

if tar -czf "$ARCHIVE_PATH" \
    "${TAR_EXCLUDES[@]}" \
    -C "$PARENT_DIR" "$TARGET_DIR_NAME" 2>> "$LOG_FILE"; then
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | awk '{print $1}')
    
    log_message "INFO" "Backup successfully created: $ARCHIVE_NAME ($ARCHIVE_SIZE) in ${DURATION}s."
    
    # ---------- Generate SHA256 Checksum ----------
    if [ "$GENERATE_CHECKSUM" = "true" ]; then
        (cd "$BACKUP_DIR" && sha256sum "$ARCHIVE_NAME" > "$CHECKSUM_PATH")
        log_message "INFO" "Checksum generated: $(basename "$CHECKSUM_PATH")"
    fi
    
    echo -e "${GREEN}======================================================${RESET}"
    echo -e "${GREEN}${BOLD}[PASS] Backup process completed successfully!${RESET}"
    echo -e "Archive: $ARCHIVE_PATH"
    echo -e "Size   : $ARCHIVE_SIZE"
    echo -e "${GREEN}======================================================${RESET}"
    exit 0
else
    log_message "ERROR" "Backup archive creation failed. Check $LOG_FILE for details."
    echo -e "${RED}[ERROR] Backup failed. Check logs at: $LOG_FILE${RESET}" >&2
    exit 1
fi
