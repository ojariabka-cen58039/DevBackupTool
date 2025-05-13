#!/bin/zsh

# Developer Environment Backup Script for macOS
# Author: ojariabka@csas.cz
# Date: May 2025
# Version: 1.2

STAGE_DIR="$HOME/dev_configs_backup_stage"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DMG_NAME="$HOME/dev-backup-$TIMESTAMP.dmg"
LOG_FILE="$STAGE_DIR/backup_summary.log"

files=(
  zsh .zshrc .bashrc .bash_profile .profile .zprofile
  .gitconfig .git-credentials
  .config
  "Library/Application Support/Code"
  .docker "Library/Group Containers/group.com.docker"
  .ssh
  "/usr/local/etc/brew" "/opt/homebrew/etc/brew"
  .vimrc .vim
  .aws .azure
  .cargo .rustup
  .gradle
  .nvm .npm .npmrc
  .gem .ruby-version
  .pythonrc
  "Library/Developer/Xcode"
  "Library/Keychains"
)

GEMFILES=( $(find "$HOME" -maxdepth 3 -type f \( -name "Gemfile" -o -name "Gemfile.lock" \) 2>/dev/null) )

echo "==> Preparing staging directory: $STAGE_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
echo "Developer Environment Backup - $(date)" > "$LOG_FILE"
echo "Backup includes:" >> "$LOG_FILE"
echo "  DMG filename: $(basename "$DMG_NAME")" >> "$LOG_FILE"

copy_item() {
  SRC="$1"
  DST="$STAGE_DIR/$SRC"
  SRC_PATH="$HOME/$SRC"
  if [ -e "$SRC_PATH" ]; then
    mkdir -p "$(dirname "$DST")"
    cp -Rp "$SRC_PATH" "$DST"
    echo "  [OK] $SRC" >> "$LOG_FILE"
  else
    echo "  [MISSING] $SRC" >> "$LOG_FILE"
  fi
}

for ITEM in "${files[@]}"; do
  copy_item "$ITEM"
done

echo "==> Renaming keychain files in backup to avoid overwrite"
KEYCHAIN_DIR="$STAGE_DIR/Library/Keychains"
if [ -d "$KEYCHAIN_DIR" ]; then
  find "$KEYCHAIN_DIR" -type f -name "*.keychain-db" | while read -r KEYCHAIN_FILE; do
    mv "$KEYCHAIN_FILE" "${KEYCHAIN_FILE}-OLD"
    echo "  [RENAMED] $(basename "$KEYCHAIN_FILE") -> $(basename "$KEYCHAIN_FILE")-OLD" >> "$LOG_FILE"
  done
else
  echo "  [MISSING] Library/Keychains" >> "$LOG_FILE"
fi

for GF in "${GEMFILES[@]}"; do
  DST="$STAGE_DIR${GF#$HOME}"
  mkdir -p "$(dirname "$DST")"
  cp -p "$GF" "$DST"
  echo "  [OK] ${GF#$HOME/}" >> "$LOG_FILE"
done

[ -d "$HOME/.local/share/containers" ] && cp -a "$HOME/.local/share/containers" "$STAGE_DIR/.local/share/"
[ -d "$HOME/.config/containers" ] && cp -a "$HOME/.config/containers" "$STAGE_DIR/.config/"
if [ "$(id -u)" -eq 0 ]; then
  [ -d /etc/containers ] && cp -a /etc/containers "$STAGE_DIR/etc/"
  [ -d /var/lib/containers ] && cp -a /var/lib/containers "$STAGE_DIR/var-lib/"
else
  echo "  [INFO] Skipping system Podman dirs (run as root to include)" >> "$LOG_FILE"
fi

echo "Exporting Homebrew, pip, npm, gem package lists..."
if command -v brew &>/dev/null; then
  brew list --formula > "$STAGE_DIR/homebrew_formulas.txt" 2>/dev/null || true
  brew list --cask > "$STAGE_DIR/homebrew_casks.txt" 2>/dev/null || true
  brew tap > "$STAGE_DIR/homebrew_taps.txt" 2>/dev/null || true
  brew bundle dump --file="$STAGE_DIR/Brewfile" --force 2>/dev/null || true
  echo "  [OK] Homebrew packages and Brewfile" >> "$LOG_FILE"
else
  echo "  [MISSING] Homebrew" >> "$LOG_FILE"
fi

command -v pip &>/dev/null && pip freeze > "$STAGE_DIR/python_pip_freeze.txt" 2>/dev/null && echo "  [OK] pip packages" >> "$LOG_FILE"
command -v npm &>/dev/null && npm list -g --depth=0 > "$STAGE_DIR/npm_global_packages.txt" 2>/dev/null && echo "  [OK] npm packages" >> "$LOG_FILE"
command -v gem &>/dev/null && gem list > "$STAGE_DIR/ruby_gems_list.txt" 2>/dev/null && echo "  [OK] Ruby gems" >> "$LOG_FILE"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESTORE_SCRIPT="$SCRIPT_DIR/dev_env_restore.sh"
[ -f "$RESTORE_SCRIPT" ] && cp "$RESTORE_SCRIPT" "$STAGE_DIR/" && chmod +x "$STAGE_DIR/$(basename "$RESTORE_SCRIPT")" && echo "  [OK] Restore script included" >> "$LOG_FILE"

echo
echo "==> Creating encrypted DMG: $(basename "$DMG_NAME")"
echo "    You will be prompted for a password."
echo
hdiutil create -encryption -stdinpass -volname "DevBackup" -srcfolder "$STAGE_DIR" -format UDZO "$DMG_NAME"
if [ $? -eq 0 ]; then
  DMG_SIZE=$(du -sh "$DMG_NAME" | cut -f1)
  echo "  [OK] DMG created: $DMG_NAME ($DMG_SIZE)" >> "$LOG_FILE"
  echo
  echo "==> DMG created: $DMG_NAME"
  echo "    Size: $DMG_SIZE"
else
  echo "  [FAIL] DMG creation failed" >> "$LOG_FILE"
fi

echo
read "$COPYDMG?Copy DMG to ~/Documents/Backup/? [Y/n]: "
if [[ -z "$COPYDMG" || "$COPYDMG" =~ ^[Yy]$ ]]; then
  TARGET_DIR="$HOME/Documents/Backup"
  mkdir -p "$TARGET_DIR"
  cp "$DMG_NAME" "$TARGET_DIR/"
  echo "  [OK] DMG copied to $TARGET_DIR" >> "$LOG_FILE"
  echo "==> DMG copied to $TARGET_DIR, please wait for OneDrive sychronization to finish."
else
  echo "==> Skipping DMG copy, please ensure the DMG is saved to a differenent location than the device storage."
fi

echo
read "CLEANUP?Remove staging directory $STAGE_DIR? [y/N]: "
[[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]] && rm -rf "$STAGE_DIR" && echo "Staging directory removed." || echo "Staging directory retained at $STAGE_DIR"
echo
echo "==> Backup complete. See $LOG_FILE for details."
exit 0
