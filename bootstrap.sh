#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

echo "=== [0] Updating system ==="
apt update
apt full-upgrade -y

echo "=== [1] Installing base packages (sudo, git, NetworkManager, dbus-x11) ==="
apt install -y sudo git network-manager dbus-x11

echo "=== [1.5] Preparing users, sudo, and VPN directories ==="
while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || continue
  [ -d "$home" ] || continue
  echo "→ Adding $user to sudo"
  usermod -aG sudo "$user" || true
  mkdir -p "$home/.local/share/networkmanagement/certificates/nm-openvpn"
  chown -R "$user":"$user" "$home/.local"
  chmod -R 700 "$home/.local/share/networkmanagement"
done < /etc/passwd

echo "=== [2] Cleaning /etc/network/interfaces (loopback only) ==="
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
  awk '/^auto lo/ {print; next} /^iface lo/ {print; next} /^[[:space:]]*#/ {print; next} NF {print "# " $0; next} {print}' /etc/network/interfaces > /etc/network/interfaces.new
  mv /etc/network/interfaces.new /etc/network/interfaces
fi

echo "=== [3] Enabling NetworkManager & VPN Support ==="
systemctl enable NetworkManager
systemctl restart NetworkManager
apt install -y network-manager-openvpn network-manager-openvpn-gnome

echo "=== [4] Installing GNOME minimal (gnome-core) ==="
apt install -y gnome-core

echo "=== [5] Cloning my-gnome-extensions repository ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi
chmod -R a+rX "$REPO_DIR"

echo "=== [5.1] Applying GRUB config from repo ==="
if [ -f "$REPO_DIR/etc-grub-default" ]; then
  cp "$REPO_DIR/etc-grub-default" /etc/default/grub
  update-grub
fi

echo "=== [6] Making scripts executable ==="
chmod +x "$REPO_DIR/configure-proxy.sh"
chmod +x "$REPO_DIR/install-browser.sh"
chmod +x "$REPO_DIR/setup-extensions.sh"
chmod +x "$REPO_DIR/install.zsh.sh"

echo "=== [7] Running Privacy & Proxy Setup (configure-proxy.sh) ==="
cd "$REPO_DIR"
./configure-proxy.sh

echo "=== [7.1] Installing Tor Browser (install-browser.sh) ==="
./install-browser.sh

echo "=== [7.2] Running Extension & ZSH setup ==="
./setup-extensions.sh
./install.zsh.sh

echo "=== [8] Enforcing System-wide Firefox Privacy (Strict) ==="
# Hardens the default Firefox ESR installation
mkdir -p /etc/firefox-esr/
cat << 'EOF' > /etc/firefox-esr/syspref.js
// FLEXOS HARDENED FIREFOX SETTINGS
pref("network.proxy.socks_remote_dns", true); 
pref("network.trr.mode", 5);                  
pref("browser.contentblocking.category", "strict"); 
pref("privacy.trackingprotection.enabled", true);
pref("privacy.resistFingerprinting", true);   
pref("datareporting.healthreport.uploadEnabled", false); 
EOF

echo "=== [9] Installing GNOME Shell theme for all users ==="
THEME_SRC="$REPO_DIR/flat-remux-dark-fullpanel/gnome-shell"
while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
  [ -d "$home" ] || continue
  THEME_DIR="$home/.themes/flat-remux-dark-fullpanel/gnome-shell"
  mkdir -p "$THEME_DIR"
  cp -r "$THEME_SRC"/* "$THEME_DIR"/ 2>/dev/null || true
  chown -R "$user":"$user" "$home/.themes" 2>/dev/null || true
done < /etc/passwd

echo "=== [10] Installing first-login GNOME autostart script ==="
cat << 'EOF' > /etc/xdg/autostart/flexos-first-login.desktop
[Desktop Entry]
Type=Application
Name=FlexOS First Login
Exec=/usr/local/bin/flexos-first-login.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

cat << 'EOF' > /usr/local/bin/flexos-first-login.sh
#!/bash/sh
# NOTE: Uses /bin/sh for broader compatibility in autostart
FLAG="$HOME/.flexos_first_login_done"
[ -f "$FLAG" ] && exit 0

# Extensions list from FlexOS Preset
EXT_LIST="['drive-menu@://github.com','gpaste@gnome-shell-extensions.gnome.org','user-theme@://github.com','caffeine@patapon.info','dash-to-panel@://github.com','ding@rastersoft.com','system-monitor@://github.com','tiling-assistant@leleat-on-github','hibernate-status@dromi','vertical-workspaces@://github.com','desktop-widgets@://github.com','add-to-desktop@://github.com','logowidget@github.com.howbea']"

dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

# Enable GNOME System Proxy via D-Bus session for the user
USER_ID=$(id -u)
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port 9050

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF
chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap completed. Rebooting to enter GNOME. ==="
reboot
