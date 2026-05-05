#!/bin/bash

# --- 1. CLEANING PHASE ---
echo "Cleaning old extension files..."
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"

# --- 2. INSTALL SYSTEM PACKAGES ---
echo "Installing dependencies..."
sudo apt update && sudo apt install -y \
    pipx \
    dbus-x11 \
    gnome-shell-extension-prefs \
    gnome-shell-extension-manager \
    gnome-shell-extensions \
    gnome-shell-extensions-extra

# Ensure gext is installed for the current user
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 3. THEME INSTALLATION ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo rm -rf "/usr/share/themes/$THEME_NAME"
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
fi

# --- 4. INSTALL ALL EXTENSIONS ---
all_extensions=(
    "azclock@://gitlab.com" "desktop-widgets@NiffirgkcaJ.github.com" "add-to-desktop@tommimon.github.com"
    "logowidget@github.com.howbea" "ubuntu-appindicators@ubuntu.com" "arcmenu@arcmenu.com"
    "blur-my-shell@aunetx" "caffeine@patapon.info" "dash-to-panel@jderose9.github.com"
    "dash-to-dock@://gmail.com" "ding@rastersoft.com" "GPaste@gnome-shell-extensions.gnome.org"
    "gsconnect@andyholmes.github.io" "system-monitor@gnome-shell-extensions.gcampax.github.com"
    "tiling-assistant@leleat-on-github" "disable-workspace-switcher@jbradaric.me" "hibernate-status@dromi"
    "just-perfection-desktop@just-perfection" "middleclickclose@://gmail.com" "no-overview@fthx"
    "vertical-workspaces@G-dH.github.com" "apps-menu@gnome-shell-extensions.gcampax.github.com"
    "places-menu@gnome-shell-extensions.gcampax.github.com" "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
    "window-list@gnome-shell-extensions.gcampax.github.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
    "drive-menu@gnome-shell-extensions.gcampax.github.com" "light-style@gnome-shell-extensions.gcampax.github.com"
    "native-window-placement@gnome-shell-extensions.gcampax.github.com" "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com" "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
)

echo "Installing extensions..."
for uuid in "${all_extensions[@]}"; do
    ~/.local/bin/gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. FORCED ENABLE LOGIC ---
# Waiting 2 seconds ensures the system registry is ready for updates
echo "Waiting for D-Bus synchronization..."
sleep 2

ACTIVE_LIST="['add-to-desktop@tommimon.github.com', 'logowidget@github.com.howbea', 'desktop-widgets@NiffirgkcaJ.github.com', 'caffeine@patapon.info', 'dash-to-panel@jderose9.github.com', 'ding@rastersoft.com', 'GPaste@gnome-shell-extensions.gnome.org', 'hibernate-status@dromi', 'drive-menu@gnome-shell-extensions.gcampax.github.com', 'system-monitor@gnome-shell-extensions.gcampax.github.com', 'tiling-assistant@leleat-on-github', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'vertical-workspaces@G-dH.github.com']"

# Force the settings into the user session
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 6. GRUB ---
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "Done! Please log out and back in manually to activate."
echo "-------------------------------------------------------"
