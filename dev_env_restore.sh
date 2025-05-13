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

  echo
  read "CONFIRM?Restore '$REL_PATH' to original location? [y/N]: "
  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    mkdir -p "$(dirname "$DEST_PATH")"
    cp -Rp "$SRC_PATH" "$DEST_PATH"
    echo "  [RESTORED] $REL_PATH" | tee -a "$LOG_FILE"
  else
    echo "  [SKIPPED] $REL_PATH" | tee -a "$LOG_FILE"
  fi
}

# ------------------------- WALK BACKUP DIR -------------------------------

cd "$BACKUP_DIR" || exit 1

find . \( \
  -path ./restore_summary.log -o \
  -path ./dev_env_restore.sh -o \
  -name '*.txt' \
  \) -prune -o -type f -print | while read -r FILE; do
  FILE_PATH="$BACKUP_DIR/${FILE#./}"
  restore_item "$FILE_PATH"
done

# ------------------------- RESTORE HOMEBREW PACKAGES ---------------------

echo
if [ -f "$BACKUP_DIR/Brewfile" ]; then
  echo "==> Brewfile found. Attempting to restore Homebrew packages..."
  
  if ! command -v brew &>/dev/null; then
    echo "  [ERROR] Homebrew is not installed. Please install it first: https://brew.sh/" | tee -a "$LOG_FILE"
  else
    brew bundle --file="$BACKUP_DIR/Brewfile"
    if [ $? -eq 0 ]; then
      echo "  [OK] Homebrew packages restored from Brewfile" | tee -a "$LOG_FILE"
    else
      echo "  [FAIL] Brew bundle encountered an error" | tee -a "$LOG_FILE"
    fi
  fi
else
  echo "  [SKIPPED] No Brewfile found, skipping Homebrew restore" | tee -a "$LOG_FILE"
fi


# ------------------------- COMPLETION ------------------------------------

echo
echo "==> Restore complete. See $LOG_FILE for details."
exit 0
