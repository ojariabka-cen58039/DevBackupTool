#!/bin/zsh

# Developer Environment Restore Script for macOS
# Author: ojariabka@csas.cz
# Date: May 2025
# Version: 1.2

BACKUP_DIR="$PWD"
LOG_FILE="$BACKUP_DIR/restore_summary.log"

echo "==> Starting restore from: $BACKUP_DIR"
echo "Developer Environment Restore - $(date)" > "$LOG_FILE"
echo "Restore log saved to $LOG_FILE"

restore_item() {
  SRC_PATH="$1"
  REL_PATH="${SRC_PATH#$BACKUP_DIR/}"
  DEST_PATH="$HOME/$REL_PATH"

  # If running as root, adjust destination for system paths
  if [ "$(id -u)" -eq 0 ]; then
    if [[ "$REL_PATH" == etc/* ]]; then
      DEST_PATH="/$REL_PATH"
    elif [[ "$REL_PATH" == var-lib/* ]]; then
      DEST_PATH="/var/lib/${REL_PATH#var-lib/}"
    fi
  fi

  mkdir -p "$(dirname "$DEST_PATH")"
  if cp -Rp "$SRC_PATH" "$DEST_PATH"; then
    echo "  [RESTORED] $REL_PATH" >> "$LOG_FILE"
  else
    echo "  [ERROR] $REL_PATH (failed to restore)" >> "$LOG_FILE"
  fi
}

# Change to backup directory (the mounted DMG or extracted folder)
cd "$BACKUP_DIR" || exit 1

# Restore all files except logs, script, Brewfile, and package lists
find "$BACKUP_DIR" \( \
  -path "$BACKUP_DIR/restore_summary.log" -o \
  -path "$BACKUP_DIR/backup_summary.log" -o \
  -path "$BACKUP_DIR/dev_env_restore.sh" -o \
  -path "$BACKUP_DIR/Brewfile" -o \
  -name '*.txt' \
\) -prune -o -type f -print | while read -r FILE; do
  restore_item "$FILE"
done

# Optional: Restore Homebrew packages from Brewfile if available
if [ -f "$BACKUP_DIR/Brewfile" ] && command -v brew &>/dev/null; then
  echo "==> Restoring Homebrew packages from Brewfile..."
  brew bundle --file="$BACKUP_DIR/Brewfile" >> "$LOG_FILE" 2>&1
  echo "  [OK] Brewfile restored" >> "$LOG_FILE"
else
  echo "  [INFO] Brewfile not found or brew not available" >> "$LOG_FILE"
fi

# Note about keychains restored with -OLD suffix
if find "$HOME/Library/Keychains" -type f -name "*.keychain-db-OLD" 2>/dev/null | grep -q .; then
  echo "==> Note: Keychain files were restored with '-OLD' suffix to avoid overwriting current keychains."
  echo "  [INFO] Keychains restored with -OLD suffix" >> "$LOG_FILE"
fi

echo
echo "==> Restore complete. See $LOG_FILE for details."
exit 0
