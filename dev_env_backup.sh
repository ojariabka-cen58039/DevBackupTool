#!/bin/zsh

# Developer Environment Backup Script for macOS
# Backs up configuration/state for common dev tools and creates an encrypted, versioned DMG archive.
#
# Author: ojariabka@csas.cz
# Date: May 2025
# Version: 1.0

# --------------------------- CONFIGURATION ----------------------------------

STAGE_DIR="$HOME/dev_configs_backup_stage"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DMG_NAME="$HOME/dev-backup-$TIMESTAMP.dmg"
LOG_FILE="$STAGE_DIR/backup_summary.log"

# Paths to backup
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

# Extra files (e.g., Gemfile/Gemfile.lock)
GEMFILES=( $(find "$HOME" -maxdepth 3 -type f \( -name "Gemfile" -o -name "Gemfile.lock" \) 2>/dev/null) )

# ---------------------- SETUP STAGING DIRECTORY -----------------------------

echo "==> Preparing staging directory: $STAGE_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
echo "Developer Environment Backup - $(date)" > "$LOG_FILE"
echo "Backup includes:" >> "$LOG_FILE"
echo "  DMG filename: $(basename "$DMG_NAME")" >> "$LOG_FILE"

# --------------------------- COPY FILES/DIRS --------------------------------

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

# Gemfiles
for GF in "${GEMFILES[@]}"; do
  DST="$STAGE_DIR${GF#$HOME}"
  mkdir -p "$(dirname "$DST")"
  cp -p "$GF" "$DST"
  echo "  [OK] ${GF#$HOME/}" >> "$LOG_FILE"
done

# ─── Include Podman config & data ──────────────────────────────────────────
echo "==> Adding Podman configuration & data to staging"
if [ -d "$HOME/.local/share/containers" ]; then
  mkdir -p "$STAGE_DIR/.local/share"
  cp -a "$HOME/.local/share/containers" "$STAGE_DIR/.local/share/"
fi
if [ -d "$HOME/.config/containers" ]; then
  mkdir -p "$STAGE_DIR/.config"
  cp -a "$HOME/.config/containers" "$STAGE_DIR/.config/"
fi
if [ "$(id -u)" -eq 0 ]; then
  [ -d /etc/containers ] && cp -a /etc/containers "$STAGE_DIR/etc/"
  [ -d /var/lib/containers ] && cp -a /var/lib/containers "$STAGE_DIR/var-lib/"
else
  echo "  [INFO] Skipping system Podman dirs (run as root to include)" >> "$LOG_FILE"
fi

# ------------------------ EXPORT PACKAGE LISTS ------------------------------

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

if command -v pip &>/dev/null; then
  pip freeze > "$STAGE_DIR/python_pip_freeze.txt" 2>/dev/null || true
  echo "  [OK] pip packages" >> "$LOG_FILE"
else
  echo "  [MISSING] pip" >> "$LOG_FILE"
fi

if command -v npm &>/dev/null; then
  npm list -g --depth=0 > "$STAGE_DIR/npm_global_packages.txt" 2>/dev/null || true
  echo "  [OK] npm packages" >> "$LOG_FILE"
else
  echo "  [MISSING] npm" >> "$LOG_FILE"
fi

if command -v gem &>/dev/null; then
  gem list > "$STAGE_DIR/ruby_gems_list.txt" 2>/dev/null || true
  echo "  [OK] Ruby gems" >> "$LOG_FILE"
else
  echo "  [MISSING] gem" >> "$LOG_FILE"
fi

# -------------------- INCLUDE RESTORE SCRIPT --------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESTORE_SCRIPT="$SCRIPT_DIR/dev_env_restore.sh"
if [ -f "$RESTORE_SCRIPT" ]; then
  cp "$RESTORE_SCRIPT" "$STAGE_DIR/"
  chmod +x "$STAGE_DIR/$(basename "$RESTORE_SCRIPT")"
  echo "  [OK] Restore script included" >> "$LOG_FILE"
else
  echo "  [WARNING] Restore script not found" >> "$LOG_FILE"
fi

# ------------------------ CREATE ENCRYPTED DMG ------------------------------
echo
echo "==> Creating encrypted DMG: $(basename "$DMG_NAME")"
echo "    You will be prompted for a password."
echo
hdiutil create -encryption -stdinpass -volname "DevBackup" -srcfolder "$STAGE_DIR" -format UDZO "$DMG_NAME"

if [ $? -eq 0 ]; then
  echo "  [OK] DMG created: $DMG_NAME" >> "$LOG_FILE"
else
  echo "  [FAIL] DMG creation failed" >> "$LOG_FILE"
fi

# ------------------- CLEANUP PROMPT ----------------------------------------
echo
read "CLEANUP?Remove staging directory $STAGE_DIR? [y/N]: "
if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then
  rm -rf "$STAGE_DIR"
  echo "Staging directory removed."
else
  echo "Staging directory retained at $STAGE_DIR"
fi

echo
echo "==> Backup complete. See $LOG_FILE for details."
exit 0
