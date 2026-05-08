#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root."
  exit 1
fi

echo "=== [0] Updating system ==="
apt update && apt full-upgrade -y

echo "=== [1] Pre-configuring non-interactive installs ==="
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

echo "=== [2] Installing base packages (GNOME, Tor, Networking) ==="
apt install -y sudo git network-manager dbus-x11 network-manager-openvpn network-manager-openvpn-gnome tor iptables-persistent gnome-core

echo "=== [3] Configuring DNS & Systemd-Resolved ==="
mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nDNSStubListener=no" > /etc/systemd/resolved.conf.d/no-stub.conf
systemctl restart systemd-resolved

echo "=== [4] Cloning my-gnome-extensions repository ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share
if [ ! -d "$REPO_DIR" ]; then
  # FIXED URL
  git clone https://github.com "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi
chmod -R a+rX "$REPO_DIR"

echo "=== [5] Applying GRUB config from repo ==="
[ -f "$REPO_DIR/etc-grub-default" ] && cp "$REPO_DIR/etc-grub-default" /etc/default/grub && update-grub

echo "=== [6] Making repository scripts executable ==="
chmod +x "$REPO_DIR/configure-proxy.sh" "$REPO_DIR/install-browser.sh" "$REPO_DIR/setup-extensions.sh" "$REPO_DIR/install.zsh.sh"

echo "=== [7] Running Privacy & Proxy Setup (configure-proxy.sh) ==="
cd "$REPO_DIR"
./configure-proxy.sh

echo "=== [8] Installing Tor Browser & Shell Tools ==="
./install-browser.sh
./setup-extensions.sh
./install.zsh.sh

echo "=== [9] Enforcing System-wide Firefox Hardening (Strict) ==="
mkdir -p /etc/firefox-esr/
cat << 'EOF' > /etc/firefox-esr/syspref.js
// FLEXOS HARDENED SETTINGS
pref("network.proxy.type", 5);                // Follow System Proxy (toggle-privacy)
pref("network.proxy.socks_remote_dns", true); // Force DNS through Tor
pref("network.trr.mode", 5);                  // Disable DoH (leaks)
pref("browser.contentblocking.category", "strict"); 
pref("privacy.resistFingerprinting", true);   
pref("datareporting.healthreport.uploadEnabled", false); 
EOF

echo "=== [10] Installing Theme for all users ==="
THEME_SRC="$REPO_DIR/flat-remux-dark-fullpanel/gnome-shell"
while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
  [ -d "$home" ] || continue
  THEME_DIR="$home/.themes/flat-remux-dark-fullpanel/gnome-shell"
  mkdir -p "$THEME_DIR"
  cp -r "$THEME_SRC"/* "$THEME_DIR"/ 2>/dev/null || true
  chown -R "$user":"$user" "$home/.themes" 2>/dev/null || true
  usermod -aG sudo "$user" || true
done < /etc/passwd

echo "=== [11] Cleaning /etc/network/interfaces ==="
if [ -f /etc/network/interfaces ]; then
  awk '/^auto lo/ {print; next} /^iface lo/ {print; next} /^[[:space:]]*#/ {print; next} NF {print "# " $0; next} {print}' /etc/network/interfaces > /etc/network/interfaces.new
  mv /etc/network/interfaces.new /etc/network/interfaces
fi

echo "=== [12] Installing first-login GNOME autostart script ==="
cat << 'EOF' > /etc/xdg/autostart/flexos-first-login.desktop
[Desktop Entry]
Type=Application
Name=FlexOS First Login
Exec=/usr/local/bin/flexos-first-login.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

cat << 'EOF' > /usr/local/bin/flexos-first-login.sh
#!/bin/bash
FLAG="$HOME/.flexos_first_login_done"
[ -f "$FLAG" ] && exit 0

# FIXED EXTENSION IDs
EXT_LIST="['drive-menu@gnome-shell-extensions.gcampax.github.com','gpaste@gnome-shell-extensions.gnome.org','user-theme@gnome-shell-extensions.gcampax.github.com','caffeine@patapon.info','dash-to-panel@jderose9.github.com','ding@rastersoft.com','system-monitor@gnome-shell-extensions.gcampax.github.com','tiling-assistant@leleat-on-github','hibernate-status@dromi','vertical-workspaces@G-dH.github.com','desktop-widgets@NiffirgkcaJ.github.com','add-to-desktop@tommimon.github.com','logowidget@github.com.howbea']"

dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

# Enable GNOME System Proxy for user session
USER_ID=$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
gsettings set org.gnome.system.proxy.socks port 9050

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF
chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap completed. Rebooting to enter FlexOS. ==="
reboot
