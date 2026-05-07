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

  echo "📂 Fixing NetworkManager local paths for $user"
  mkdir -p "$home/.local/share/networkmanagement/certificates/nm-openvpn"
  chown -R "$user":"$user" "$home/.local"
  chmod -R 700 "$home/.local/share/networkmanagement"
done < /etc/passwd

echo "=== [2] Cleaning /etc/network/interfaces (loopback only) ==="
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
  awk '
    /^auto lo/ {print; next}
    /^iface lo/ {print; next}
    /^[[:space:]]*#/ {print; next}
    NF {print "# " $0; next}
    {print}
  ' /etc/network/interfaces > /etc/network/interfaces.new
  mv /etc/network/interfaces.new /etc/network/interfaces
fi

echo "=== [3] Enabling NetworkManager ==="
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "=== [3.1] Installing OpenVPN support for NetworkManager ==="   # ➜ NUEVO
apt install -y network-manager-openvpn network-manager-openvpn-gnome   # ➜ NUEVO

echo "=== [4] Installing GNOME minimal (gnome-core) ==="
apt install -y gnome-core

echo "=== [5] Cloning my-gnome-extensions repository ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share

if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/x86david/my-gnome-extensions.git "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
fi

chmod -R a+rX "$REPO_DIR"
cd "$REPO_DIR"

echo "=== [6] Making scripts executable ==="
chmod +x setup-extensions.sh
chmod +x install.zsh.sh
chmod +x configure-vpn-autostart.sh

echo "=== [7] Running setup-extensions.sh ==="
./setup-extensions.sh

echo "=== [8] Running install.zsh.sh (automatic mode) ==="
./install.zsh.sh

echo "=== [9] Installing GNOME Shell theme for all users ==="
THEME_SRC="$REPO_DIR/flat-remux-dark-fullpanel/gnome-shell"

while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
  [ -d "$home" ] || continue

  THEME_DIR="$home/.themes/flat-remux-dark-fullpanel/gnome-shell"
  mkdir -p "$THEME_DIR"
  cp -r "$THEME_SRC"/* "$THEME_DIR"/
  chown -R "$user":"$user" "$home/.themes"
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
#!/bin/bash

FLAG="$HOME/.flexos_first_login_done"

if [ -f "$FLAG" ]; then
    exit 0
fi

EXT_LIST="[
  'drive-menu@gnome-shell-extensions.gcampax.github.com',
  'gpaste@gnome-shell-extensions.gnome.org',
  'user-theme@gnome-shell-extensions.gcampax.github.com',
  'caffeine@patapon.info',
  'dash-to-panel@jderose9.github.com',
  'ding@rastersoft.com',
  'system-monitor@gnome-shell-extensions.gcampax.github.com',
  'tiling-assistant@leleat-on-github',
  'hibernate-status@dromi',
  'vertical-workspaces@G-dH.github.com',
  'desktop-widgets@NiffirgkcaJ.github.com',
  'add-to-desktop@tommimon.github.com',
  'logowidget@github.com.howbea'
]"

dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF

chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap completed. Reboot to enter GNOME. ==="
echo "REMINDER: After first login, import your .ovpn via GNOME Settings,"
echo "then run /usr/local/share/my-gnome-extensions/configure-vpn-autostart.sh"
reboot
