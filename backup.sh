#!/bin/bash

# ==========================================
# Linux Backup Automation Script
# Author: Aishwary Gupta
# Project: Linux Backup Suite
# Version: 1.0
# ==========================================

# ---------- Variables ----------

BACKUP_DIR="./backups"
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/backup.log"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

SOURCE_DIR="$1"

# ---------- Create Required Directories ----------

mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# ---------- Logging Function ----------

log_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# ---------- Input Validation ----------

if [ -z "$SOURCE_DIR" ]; then
    log_message "ERROR: No directory supplied."

    echo
    echo "Usage:"
    echo "./backup.sh <directory>"
    echo

    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    log_message "ERROR: Directory '$SOURCE_DIR' does not exist."

    echo "Directory does not exist."

    exit 1
fi

# ---------- Backup Filename ----------

SOURCE_NAME=$(basename "$SOURCE_DIR")

BACKUP_FILE="$BACKUP_DIR/${SOURCE_NAME}_${TIMESTAMP}.tar.gz"

# ---------- Start Backup ----------

log_message "=============================================="
log_message "Backup Started"
log_message "Source Directory : $SOURCE_DIR"
log_message "Backup File      : $BACKUP_FILE"

# ---------- Create Backup ----------

tar -czf "$BACKUP_FILE" "$SOURCE_DIR" >>"$LOG_FILE" 2>&1

# ---------- Verify Backup ----------

if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then

    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    log_message "Backup Created Successfully."
    log_message "Backup Size : $FILE_SIZE"
    log_message "Backup Completed."

    echo
    echo "======================================"
    echo " Backup Successful"
    echo "======================================"
    echo " Backup File : $BACKUP_FILE"
    echo " Size        : $FILE_SIZE"
    echo "======================================"

    exit 0

else

    log_message "ERROR: Backup Failed."

    echo
    echo "Backup Failed."

    exit 1

fi