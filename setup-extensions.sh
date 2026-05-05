#!/bin/bash

# 1. Install System Dependencies
echo "Installing Extension Manager and setup tools..."
sudo apt update && sudo apt install -y gnome-shell-extension-manager gnome-shell-extensions

# 2. Setup Theme Directory
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
TARGET_DIR="$HOME/.themes"

echo "Installing theme to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

# Copy the theme folder from the current script location to ~/.themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    cp -r "$SCRIPT_DIR/$THEME_NAME" "$TARGET_DIR/"
    echo "Theme installed successfully."
else
    echo "Error: Theme folder not found in $SCRIPT_DIR"
fi

# 3. Extension Management
echo "Configuring extensions..."

# Define your 'Used' list
active_extensions=(
    "user-theme@://github.com"
    "desktop-widgets@://github.com"
    "add-to-desktop@://github.com"
    "logowidget@github.com.howbea"
    "caffeine@patapon.info"
    "dash-to-dock@://gmail.com"
    "ding@rastersoft.com"
    "GPaste@gnome-shell-extensions.gnome.org"
    "system-monitor@://github.com"
    "tiling-assistant@leleat-on-github"
)

# Enable the extension system
gsettings set org.gnome.shell disable-user-extensions false

# Enable each extension
for uuid in "${active_extensions[@]}"; do
    gnome-extensions enable "$uuid" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Enabled: $uuid"
    else
        echo "Note: $uuid not found. You may need to download it via Extension Manager."
    fi
done

# 4. Enable the Theme
echo "Setting Shell Theme to $THEME_NAME..."
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

echo "-------------------------------------------------------"
echo "Setup finished! "
echo "If extensions didn't activate, please download them in "
echo "'Extension Manager' and run this script once more."
echo "-------------------------------------------------------"

