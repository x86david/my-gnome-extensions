#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root."
  exit 1
fi

echo "=== [0] Actualizando sistema ==="
apt update && apt full-upgrade -y

echo "=== [1] Pre-configurando iptables-persistent ==="
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

echo "=== [2] Instalando stack estándar (sudo, git, NetworkManager, GNOME, Tor) ==="
apt install -y sudo git network-manager dbus-x11 network-manager-openvpn \
    network-manager-openvpn-gnome tor iptables-persistent gnome-core

echo "=== [3] Añadiendo usuarios existentes al grupo sudo ==="
while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || continue
  [ -d "$home" ] || continue
  echo "→ Añadiendo $user a sudo"
  usermod -aG sudo "$user" || true
done < /etc/passwd

echo "=== [4] Limpiando /etc/network/interfaces (solo loopback) ==="
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
  echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces
fi

echo "=== [5] Configurando NetworkManager ==="
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "=== [6] Clonando repositorio de configuración ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/x86david/my-gnome-extensions "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi
chmod -R a+rX "$REPO_DIR"

echo "=== [7] Configuración de GRUB ==="
[ -f "$REPO_DIR/etc-grub-default" ] && cp "$REPO_DIR/etc-grub-default" /etc/default/grub && update-grub

echo "=== [8] Preparando scripts del repositorio ==="
chmod +x "$REPO_DIR/configure-proxy.sh" "$REPO_DIR/setup-extensions.sh" "$REPO_DIR/install.zsh.sh"

echo "=== [9] Hardening de Red (Tor Cage) ==="
cd "$REPO_DIR"
./configure-proxy.sh
sleep 5
toogle-privacy off

echo "=== [10] Instalando extensiones y Zsh ==="
./setup-extensions.sh
./install.zsh.sh

echo "=== [11] Instalando tema GNOME para todos los usuarios ==="
THEME_SRC="$REPO_DIR/flat-remux-dark-fullpanel/gnome-shell"
while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
  [ -d "$home" ] || continue
  THEME_DIR="$home/.themes/flat-remux-dark-fullpanel/gnome-shell"
  mkdir -p "$THEME_DIR"
  cp -r "$THEME_SRC"/* "$THEME_DIR"/
  chown -R "$user":"$user" "$home/.themes"
done < /etc/passwd

echo "=== [12] Configuración global de Firefox (System Proxy) ==="
mkdir -p /etc/firefox-esr/
cat << 'EOF' > /etc/firefox-esr/syspref.js
pref("network.proxy.type", 5);
pref("network.proxy.socks_remote_dns", true);
pref("network.trr.mode", 5);
pref("browser.contentblocking.category", "strict");
pref("privacy.trackingprotection.enabled", true);
pref("privacy.resistFingerprinting", true);
pref("datareporting.healthreport.uploadEnabled", false);
EOF

echo "=== [13] Instalando script de primer login GNOME ==="
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

EXT_LIST="['user-theme@gnome-shell-extensions.gcampax.github.com','dash-to-panel@jderose9.github.com']"
dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF
chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap finalizado. Reiniciando... ==="
reboot
