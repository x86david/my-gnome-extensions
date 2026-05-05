#!/bin/bash

# --- 1. DEEP CLEANING PHASE ---
echo "Deep Cleaning: Removing existing extensions..."
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"

# Purge system packages (Internal sudo used here)
sudo apt purge -y \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extensions \
    gnome-shell-extensions-extra
sudo apt autoremove -y

# --- 2. INSTALL SYSTEM DEPENDENCIES ---
echo "Installing setup dependencies..."
sudo apt update && sudo apt install -y \
    pipx \
    dbus-x11 \
    gnome-shell-extension-prefs \
    gnome-shell-extension-manager \
    gnome-shell-extensions \
    gnome-shell-extensions-extra

# Install gext CLI for the user (No sudo for pipx)
pipx install gnome-extensions-cli --system-site-packages --force
pipx ensurepath
export PATH="$PATH:$HOME/.local/bin"

# --- 3. GLOBAL THEME INSTALLATION ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)

echo "Installing theme globally to /usr/share/themes..."
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo rm -rf "/usr/share/themes/$THEME_NAME"
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
fi

# --- 4. MASS INSTALL ALL EXTENSIONS ---
all_extensions=(
    "azclock@://gitlab.com" "desktop-widgets@://github.com" "add-to-desktop@://github.com"
    "logowidget@github.com.howbea" "ubuntu-appindicators@ubuntu.com" "arcmenu@arcmenu.com"
    "blur-my-shell@aunetx" "caffeine@patapon.info" "dash-to-panel@://github.com"
    "dash-to-dock@://gmail.com" "ding@rastersoft.com" "GPaste@gnome-shell-extensions.gnome.org"
    "gsconnect@andyholmes.github.io" "system-monitor@://github.com"
    "tiling-assistant@leleat-on-github" "disable-workspace-switcher@jbradaric.me" "hibernate-status@dromi"
    "just-perfection-desktop@just-perfection" "middleclickclose@://gmail.com" "no-overview@fthx"
    "vertical-workspaces@://github.com" "apps-menu@://github.com"
    "places-menu@://github.com" "launch-new-instance@://github.com"
    "window-list@://github.com" "auto-move-windows@://github.com"
    "drive-menu@://github.com" "light-style@://github.com"
    "native-window-placement@://github.com" "screenshot-window-sizer@://github.com"
    "user-theme@://github.com" "windowsNavigator@://github.com"
    "workspace-indicator@://github.com"
)

echo "Downloading and installing all extensions..."
for uuid in "${all_extensions[@]}"; do
    # Run gext as user
    ~/.local/bin/gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. SYNC ENABLED LIST ---
ACTIVE_LIST="[ \
'add-to-desktop@://github.com', \
'logowidget@github.com.howbea', \
'desktop-widgets@://github.com', \
'caffeine@patapon.info', \
'dash-to-panel@://github.com', \
'ding@rastersoft.com', \
'GPaste@gnome-shell-extensions.gnome.org', \
'hibernate-status@dromi', \
'drive-menu@://github.com', \
'system-monitor@://github.com', \
'tiling-assistant@leleat-on-github', \
'user-theme@://github.com', \
'vertical-workspaces@://github.com' \
]"

echo "Activating synced extensions and theme..."
# These MUST run as user, not root
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 6. GRUB ---
echo "Applying GRUB Console Mode..."
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "Setup Complete! Logout and Login to refresh GNOME."
echo "-------------------------------------------------------"
