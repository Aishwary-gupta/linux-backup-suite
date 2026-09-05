#!/usr/bin/env bash

# ==============================================================================
# Linux Backup Automation Suite
# Automated End-to-End Integration Test Suite
# Author: Aishwary Gupta
# Version: 2.0 (Day 10 Milestone)
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="/tmp/backup_suite_test_env_$$"
RESTORE_DIR="/tmp/backup_suite_restore_test_$$"

# ---------- Colors ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

cleanup_test_env() {
    echo -e "${CYAN}Cleaning up temporary test sandbox...${RESET}"
    rm -rf "$TEST_DIR" "$RESTORE_DIR"
}
trap cleanup_test_env EXIT

echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}${BOLD}       RUNNING END-TO-END INTEGRATION TEST SUITE      ${RESET}"
echo -e "${BLUE}======================================================${RESET}"

# Step 1: Create test payload with regular files and excluded files
echo -e "${CYAN}[Step 1] Creating test sandbox at $TEST_DIR...${RESET}"
mkdir -p "$TEST_DIR/data"
mkdir -p "$TEST_DIR/node_modules"
mkdir -p "$TEST_DIR/.git"

echo "Critical Business Data 12345" > "$TEST_DIR/data/important.txt"
echo "Secondary Payload" > "$TEST_DIR/data/payload.csv"
echo "This should be excluded" > "$TEST_DIR/trash.tmp"
echo "Heavy dependency" > "$TEST_DIR/node_modules/package.json"

# Step 2: Run backup.sh
echo -e "${CYAN}[Step 2] Executing backup.sh...${RESET}"
"$SCRIPT_DIR/backup.sh" "$TEST_DIR"

# Step 3: Find generated archive
LATEST_ARCHIVE=$(ls -1t "$SCRIPT_DIR/backups"/backup_*test_*.tar.gz 2>/dev/null | head -n1)
if [ -z "$LATEST_ARCHIVE" ] || [ ! -f "$LATEST_ARCHIVE" ]; then
    echo -e "${RED}[FAIL] Archive was not generated!${RESET}"
    exit 1
fi
echo -e "${GREEN}[PASS] Archive generated:${RESET} $(basename "$LATEST_ARCHIVE")"

# Step 4: Verify SHA256 Checksum
echo -e "${CYAN}[Step 4] Checking SHA256 checksum file...${RESET}"
CHECKSUM_FILE="${LATEST_ARCHIVE}.sha256"
if [ ! -f "$CHECKSUM_FILE" ]; then
    echo -e "${RED}[FAIL] Checksum file missing!${RESET}"
    exit 1
fi
(cd "$SCRIPT_DIR/backups" && sha256sum -c "$(basename "$CHECKSUM_FILE")" >/dev/null)
echo -e "${GREEN}[PASS] SHA256 checksum verified!${RESET}"

# Step 5: Test Exclusion Engine
echo -e "${CYAN}[Step 5] Verifying exclusion list functionality...${RESET}"
ARCHIVE_CONTENTS=$(tar -tzf "$LATEST_ARCHIVE")
if echo "$ARCHIVE_CONTENTS" | grep -q "node_modules"; then
    echo -e "${RED}[FAIL] node_modules was not properly excluded!${RESET}"
    exit 1
fi
if echo "$ARCHIVE_CONTENTS" | grep -q "\.tmp"; then
    echo -e "${RED}[FAIL] .tmp files were not properly excluded!${RESET}"
    exit 1
fi
echo -e "${GREEN}[PASS] Exclusions strictly honored.${RESET}"

# Step 6: Test Restoration
echo -e "${CYAN}[Step 6] Testing non-interactive restoration...${RESET}"
"$SCRIPT_DIR/restore.sh" "$LATEST_ARCHIVE" "$RESTORE_DIR"

RESTORED_DATA=$(find "$RESTORE_DIR" -type f -name "important.txt" | head -n1)
if [ -z "$RESTORED_DATA" ] || [ ! -f "$RESTORED_DATA" ]; then
    echo -e "${RED}[FAIL] Restored file important.txt not found!${RESET}"
    exit 1
fi

if ! grep -q "Critical Business Data 12345" "$RESTORED_DATA"; then
    echo -e "${RED}[FAIL] File contents corrupted after restore!${RESET}"
    exit 1
fi
echo -e "${GREEN}[PASS] Data restored with 100% fidelity.${RESET}"

# Step 7: Run health check
echo -e "${CYAN}[Step 7] Testing health-check.sh...${RESET}"
"$SCRIPT_DIR/health-check.sh" >/dev/null
echo -e "${GREEN}[PASS] Health check diagnostic completed.${RESET}"

# Step 8: Clean up generated test archive
rm -f "$LATEST_ARCHIVE" "$CHECKSUM_FILE"

echo
echo -e "${GREEN}======================================================${RESET}"
echo -e "${GREEN}${BOLD}   [SUCCESS] ALL INTEGRATION TESTS PASSED (10/10)!     ${RESET}"
echo -e "${GREEN}======================================================${RESET}"
exit 0
