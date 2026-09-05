#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Automated Backup Retention & Cleanup Script
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

LOG_FILE="$LOG_DIR/cleanup.log"
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

DRY_RUN=false
if [ "$1" == "--dry-run" ] || [ "$2" == "--dry-run" ]; then
    DRY_RUN=true
fi

# ---------- Header Banner ----------
echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}        LINUX BACKUP RETENTION & CLEANUP              ${RESET}"
echo -e "${BLUE}======================================================${RESET}"
echo -e "${CYAN}Backup Directory  :${RESET} $BACKUP_DIR"
echo -e "${CYAN}Retention Window  :${RESET} $RETENTION_DAYS days"
echo -e "${CYAN}Max Retained Cap  :${RESET} $MAX_BACKUP_COUNT archives"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Mode              : DRY RUN (No files will be deleted)${RESET}"
fi
echo -e "${BLUE}------------------------------------------------------${RESET}"

if [ ! -d "$BACKUP_DIR" ]; then
    log_message "ERROR" "Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

DELETED_COUNT=0
FREED_BYTES=0

# ==============================================================================
# PHASE 1: Purge Backups Exceeding RETENTION_DAYS
# ==============================================================================
log_message "INFO" "Searching for backups older than $RETENTION_DAYS days..."

# Use find to list archives older than RETENTION_DAYS
while IFS= read -r -d '' archive; do
    [ -z "$archive" ] && continue
    
    FILE_SIZE=$(stat -c%s "$archive" 2>/dev/null || stat -f%z "$archive" 2>/dev/null || echo 0)
    CHECKSUM_FILE="${archive}.sha256"
    ARCHIVE_NAME=$(basename "$archive")
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN WOULD DELETE]${RESET} $ARCHIVE_NAME ($FILE_SIZE bytes)"
    else
        rm -f "$archive"
        [ -f "$CHECKSUM_FILE" ] && rm -f "$CHECKSUM_FILE"
        log_message "INFO" "Deleted expired archive: $ARCHIVE_NAME"
        DELETED_COUNT=$((DELETED_COUNT + 1))
        FREED_BYTES=$((FREED_BYTES + FILE_SIZE))
    fi
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -print0)

# ==============================================================================
# PHASE 2: Enforce MAX_BACKUP_COUNT Safety Ceiling
# ==============================================================================
shopt -s nullglob
CURRENT_BACKUPS=($(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || true))
shopt -u nullglob

TOTAL_CURRENT=${#CURRENT_BACKUPS[@]}

if [ "$TOTAL_CURRENT" -gt "$MAX_BACKUP_COUNT" ]; then
    EXCESS_COUNT=$((TOTAL_CURRENT - MAX_BACKUP_COUNT))
    log_message "WARN" "Total backups ($TOTAL_CURRENT) exceed MAX_BACKUP_COUNT ($MAX_BACKUP_COUNT). Purging $EXCESS_COUNT oldest."
    
    # ls -1t sorts newest first; slice oldest items at the tail
    OLDEST_BACKUPS=("${CURRENT_BACKUPS[@]:$MAX_BACKUP_COUNT}")
    for old_archive in "${OLDEST_BACKUPS[@]}"; do
        FILE_SIZE=$(stat -c%s "$old_archive" 2>/dev/null || stat -f%z "$old_archive" 2>/dev/null || echo 0)
        CHECKSUM_FILE="${old_archive}.sha256"
        ARCHIVE_NAME=$(basename "$old_archive")
        
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY-RUN WOULD PURGE]${RESET} $ARCHIVE_NAME ($FILE_SIZE bytes) to enforce cap"
        else
            rm -f "$old_archive"
            [ -f "$CHECKSUM_FILE" ] && rm -f "$CHECKSUM_FILE"
            log_message "INFO" "Deleted excess archive: $ARCHIVE_NAME"
            DELETED_COUNT=$((DELETED_COUNT + 1))
            FREED_BYTES=$((FREED_BYTES + FILE_SIZE))
        fi
    done
fi

FREED_HUMAN=$(numfmt --to=iec-i --suffix=B "$FREED_BYTES" 2>/dev/null || echo "${FREED_BYTES} Bytes")

echo -e "${GREEN}======================================================${RESET}"
echo -e "${GREEN}${BOLD}[SUMMARY] Cleanup finished.${RESET}"
echo -e "Archives Deleted : $DELETED_COUNT"
echo -e "Disk Space Freed : $FREED_HUMAN"
echo -e "${GREEN}======================================================${RESET}"

log_message "INFO" "Cleanup complete. Deleted: $DELETED_COUNT archives, Freed: $FREED_HUMAN."
exit 0
