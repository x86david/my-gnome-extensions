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

echo "=== [1.1] Configuring GRUB ==="
cat << 'EOF' > /etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`( . /etc/os-release && echo ${NAME} )`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=false
GRUB_TERMINAL=console
EOF
update-grub

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

echo "=== [6] Running Privacy & Proxy Setup (configure-proxy.sh) ==="
chmod +x "$REPO_DIR/configure-proxy.sh"
chmod +x "$REPO_DIR/configure-vpn-autostart.sh"
cd "$REPO_DIR"
./configure-proxy.sh

echo "=== [7] Running Extension & ZSH setup ==="
chmod +x setup-extensions.sh
chmod +x install.zsh.sh
./setup-extensions.sh
./install.zsh.sh

echo "=== [8] Enforcing System-wide Firefox Privacy (Strict) ==="
# This creates a global policy that Firefox applies to all profiles
mkdir -p /etc/firefox-esr/syspref.js # For Debian ESR
mkdir -p /usr/lib/firefox/browser/defaults/preferences # For Standard Firefox
cat << 'EOF' > /etc/firefox/syspref.js
// FLEXOS HARDENED FIREFOX SETTINGS
pref("network.proxy.socks_remote_dns", true); // Force DNS through Tor
pref("network.trr.mode", 5);                  // Disable DNS-over-HTTPS (use Tor DNS)
pref("browser.contentblocking.category", "strict"); // Strict Tracking Protection
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.resistFingerprinting", true);   // Resist Fingerprinting
pref("browser.formfill.enable", false);       // Disable form autofill
pref("signon.rememberSignons", false);        // Disable password manager
pref("datareporting.healthreport.uploadEnabled", false); // Disable telemetry
EOF

echo "=== [9] Installing Theme and Autostart ==="
# ... (Theme installation code from your previous version)

cat << 'EOF' > /etc/xdg/autostart/flexos-first-login.desktop
[Desktop Entry]
Type=Application
Name=FlexOS First Login
Exec=/usr/local/bin/flexos-first-login.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# Note: The first-login script now only handles DCONF/GNOME specific UI bits
cat << 'EOF' > /usr/local/bin/flexos-first-login.sh
#!/bin/bash
FLAG="$HOME/.flexos_first_login_done"
[ -f "$FLAG" ] && exit 0

# Apply extensions and dash-to-panel
dconf write /org/gnome/shell/enabled-extensions "$(cat /usr/local/share/my-gnome-extensions/extensions.list)"
if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

# Enable GNOME Manual Proxy via D-Bus session
USER_ID=$(id -u)
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port 9050

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF
chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap completed. Rebooting. ==="
reboot
