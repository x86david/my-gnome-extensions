#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root."
  exit 1
fi

echo "=== [0] Actualizando sistema ==="
apt update && apt full-upgrade -y

echo "=== [1] Pre-configurando instalaciones no interactivas ==="
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

echo "=== [2] Instalando stack estándar (GNOME + NetworkManager) ==="
# Eliminamos systemd-resolved. Usamos lo que viene con gnome-core.
apt install -y sudo git network-manager dbus-x11 network-manager-openvpn \
    network-manager-openvpn-gnome tor iptables-persistent gnome-core

echo "=== [3] Configurando NetworkManager como gestor único ==="
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "=== [4] Clonando repositorio de configuración ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi
chmod -R a+rX "$REPO_DIR"

echo "=== [5] Aplicando configuración de GRUB ==="
[ -f "$REPO_DIR/etc-grub-default" ] && cp "$REPO_DIR/etc-grub-default" /etc/default/grub && update-grub

echo "=== [6] Preparando scripts del repositorio ==="
chmod +x "$REPO_DIR/configure-proxy.sh" "$REPO_DIR/install-browser.sh" "$REPO_DIR/setup-extensions.sh" "$REPO_DIR/install.zsh.sh"

echo "=== [7] Ejecutando Hardening de Red (Tor Cage) ==="
cd "$REPO_DIR"
./configure-proxy.sh

echo "=== [8] Instalando aplicaciones y extensiones ==="
./install-browser.sh
./setup-extensions.sh
./install.zsh.sh

echo "=== [9] Configuración global de Firefox (System Proxy) ==="
mkdir -p /etc/firefox-esr/
cat << 'EOF' > /etc/firefox-esr/syspref.js
pref("network.proxy.type", 5);                // Usa el proxy del sistema
pref("network.proxy.socks_remote_dns", true); // DNS por Tor
pref("network.trr.mode", 5);                  // Desactiva DoH
pref("browser.contentblocking.category", "strict"); 
pref("privacy.resistFingerprinting", true);   
pref("datareporting.healthreport.uploadEnabled", false); 
EOF

echo "=== [10] Instalando Tema y preparando usuarios ==="
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

echo "=== [11] Limpiando interfaces antiguas (dejando solo NM) ==="
if [ -f /etc/network/interfaces ]; then
  # Solo dejamos el loopback, el resto para NetworkManager
  echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces
fi

echo "=== [12] Configurando Script de inicio FlexOS ==="
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

# Lista de extensiones corregida
EXT_LIST="['drive-menu@://github.com','gpaste@gnome-shell-extensions.gnome.org','user-theme@://github.com','caffeine@patapon.info','dash-to-panel@://github.com','ding@rastersoft.com','system-monitor@://github.com','tiling-assistant@leleat-on-github','hibernate-status@dromi','vertical-workspaces@://github.com','desktop-widgets@://github.com','add-to-desktop@://github.com','logowidget@github.com.howbea']"

dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

if [ -f "/usr/local/share/my-gnome-extensions/dash_to_panel.config" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "/usr/local/share/my-gnome-extensions/dash_to_panel.config"
fi

# Sincronizamos GNOME Proxy con el estado 'hardened'
USER_ID=$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
gsettings set org.gnome.system.proxy.socks port 9050

touch "$FLAG"
rm -f /etc/xdg/autostart/flexos-first-login.desktop
EOF
chmod +x /usr/local/bin/flexos-first-login.sh

echo "=== Bootstrap finalizado. Reiniciando para entrar en FlexOS. ==="
reboot
