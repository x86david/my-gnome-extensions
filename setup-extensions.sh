#!/bin/bash

# 1. Install System & Installation Dependencies
echo "Installing setup dependencies..."
sudo apt update && sudo apt install -y pipx gnome-shell-extension-manager gnome-shell-extensions
pipx install gnome-extensions-cli --system-site-packages --force

# Add pipx to PATH for this session
export PATH="$PATH:$HOME/.local/bin"

# 2. Setup Theme Directory
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)
TARGET_DIR="$HOME/.themes"

echo "Installing theme to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    cp -r "$SCRIPT_DIR/$THEME_NAME" "$TARGET_DIR/"
else
    echo "Error: Theme folder not found in $SCRIPT_DIR"
fi

# 3. Mass Install ALL Extensions (Enabled & Disabled)
# This list includes every UUID found in your earlier logs
all_extensions=(
    "azclock@://gitlab.com" "desktop-widgets@NiffirgkcaJ.github.com" "add-to-desktop@tommimon.github.com"
    "logowidget@github.com.howbea" "ubuntu-appindicators@ubuntu.com" "arcmenu@arcmenu.com"
    "blur-my-shell@aunetx" "caffeine@patapon.info" "dash-to-panel@jderose9.github.com"
    "dash-to-dock@micxgx.gmail.com" "ding@rastersoft.com" "GPaste@gnome-shell-extensions.gnome.org"
    "gsconnect@andyholmes.github.io" "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "tiling-assistant@leleat-on-github" "disable-workspace-switcher@jbradaric.me" "hibernate-status@dromi"
    "just-perfection-desktop@just-perfection" "middleclickclose@paolo.tranquilli.gmail.com" "no-overview@fthx"
    "vertical-workspaces@G-dH.github.com" "apps-menu@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com" "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "window-list@gnome-shell-extensions.gcampax.github.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com" "light-style@gnome-shell-extensions.gcampax.github.com"
    "native-window-placement@gnome-shell-extensions.gcampax.github.com" "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com" "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
)

echo "Downloading and installing extensions (this may take a minute)..."
for uuid in "${all_extensions[@]}"; do
    gext install "$uuid" --quiet 2>/dev/null
done

# 4. Enable ONLY the "Used" list
echo "Activating your used extensions..."
active_extensions=(
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "desktop-widgets@NiffirgkcaJ.github.com"
    "add-to-desktop@tommimon.github.com"
    "logowidget@github.com.howbea"
    "caffeine@patapon.info"
    "dash-to-dock@micxgx.gmail.com"
    "ding@rastersoft.com"
    "GPaste@gnome-shell-extensions.gnome.org"
    "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "tiling-assistant@leleat-on-github"
)

gsettings set org.gnome.shell disable-user-extensions false
# Disable all first to ensure only your list is active
gsettings set org.gnome.shell enabled-extensions "[]"

for uuid in "${active_extensions[@]}"; do
    gnome-extensions enable "$uuid"
done

# 5. Final Appearance Setup
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

echo "Applying GRUB Console Mode..."
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "Done! Restart GNOME (Alt+F2, 'r') to see changes."
