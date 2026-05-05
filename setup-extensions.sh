#!/bin/bash

# --- 1. DEEP CLEANING PHASE ---
echo "Starting Deep Clean: Removing all current extensions and themes..."

# Remove all local user extensions
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"

# Purge major system extensions to ensure fresh versions
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
    gnome-shell-extension-manager \
    gnome-shell-extensions \
    gnome-shell-extensions-extra

# Install gext CLI for web-based extensions
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 3. GLOBAL THEME INSTALLATION ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)

echo "Installing theme globally to /usr/share/themes..."
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo rm -rf "/usr/share/themes/$THEME_NAME"
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
else
    echo "Error: Theme folder not found in $SCRIPT_DIR"
fi

# --- 4. MASS INSTALL ALL EXTENSIONS (34 Total) ---
all_extensions=(
    "azclock@azclock.gitlab.com" "desktop-widgets@NiffirgkcaJ.github.com" "add-to-desktop@tommimon.github.com"
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
    "workspace-indicator@gnome-shell-extensions.gcampax.github.com" "revolutionary@jbellue.github.io"
)

echo "Downloading and installing extensions from web/repo..."
for uuid in "${all_extensions[@]}"; do
    gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. THE ULTIMATE ENABLE (ONE COMMAND) ---
# We use your exact 'ENABLED LIST' from your system logs
ACTIVE_LIST="['caffeine@patapon.info', 'hibernate-status@dromi', 'revolutionary@jbellue.github.io', 'add-to-desktop@tommimon.github.com', 'GPaste@gnome-shell-extensions.gnome.org', 'ding@rastersoft.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com', 'system-monitor@gnome-shell-extensions.gcampax.github.com', 'tiling-assistant@leleat-on-github', 'vertical-workspaces@G-dH.github.com', 'logowidget@github.com.howbea', 'desktop-widgets@NiffirgkcaJ.github.com', 'dash-to-panel@jderose9.github.com', 'user-theme@gnome-shell-extensions.gcampax.github.com']"

echo "Applying your active extension list and shell theme..."
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 6. GRUB REPLICATION ---
echo "Applying GRUB Console Mode..."
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "Setup finished! Global theme and all extensions ready."
echo "CRITICAL: Log out and log back in to activate changes."
echo "-------------------------------------------------------"
