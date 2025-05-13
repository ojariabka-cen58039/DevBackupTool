#!/bin/zsh

# Developer Environment Restore Script for macOS
# Restores configuration/state from an extracted backup directory.
#
# Author: ojariabka@csas.cz
# Date: May 2025
# Version: 1.0

# --------------------------- SETUP ----------------------------------------

BACKUP_DIR="$PWD"
LOG_FILE="$BACKUP_DIR/restore_summary.log"

echo "==> Starting restore from: $BACKUP_DIR"
echo "Developer Environment Restore - $(date)" > "$LOG_FILE"
echo "Restore log saved to $LOG_FILE"

# ------------------------- RESTORE FUNCTION -------------------------------

restore_item() {
  SRC_PATH="$1"
  REL_PATH="${SRC_PATH#$BACKUP_DIR/}"
  DEST_PATH="$HOME/$REL_PATH"

  mkdir -p "$(dirname "$DEST_PATH")"
  cp -Rp "$SRC_PATH" "$DEST_PATH"
  echo "  [RESTORED] $REL_PATH" | tee -a "$LOG_FILE"
}
# ------------------------- WALK BACKUP DIR -------------------------------

cd "$BACKUP_DIR" || exit 1

find "$BACKUP_DIR" \( \
  -path "$BACKUP_DIR/restore_summary.log" -o \
  -path "$BACKUP_DIR/dev_env_restore.sh" -o \
  -name '*.txt' \
  \) -prune -o -type f -print | while read -r FILE; do
  restore_item "$FILE"
done

# ------------------------- COMPLETION ------------------------------------

echo
echo "==> Restore complete. See $LOG_FILE for details."
exit 0
