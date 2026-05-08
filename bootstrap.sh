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

echo "=== [2] Instalando stack estándar (GNOME + NetworkManager + Tor) ==="
apt install -y sudo git network-manager dbus-x11 network-manager-openvpn \
    network-manager-openvpn-gnome tor iptables-persistent gnome-core

echo "=== [3] Configurando NetworkManager ==="
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "=== [4] Clonando repositorio de configuración ==="
REPO_DIR="/usr/local/share/my-gnome-extensions"
mkdir -p /usr/local/share
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/x86david/my-gnome-extensions "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi
chmod -R a+rX "$REPO_DIR"

echo "=== [5] Configuración de GRUB ==="
[ -f "$REPO_DIR/etc-grub-default" ] && cp "$REPO_DIR/etc-grub-default" /etc/default/grub && update-grub

echo "=== [6] Preparando scripts del repositorio ==="
chmod +x "$REPO_DIR/configure-proxy.sh" "$REPO_DIR/setup-extensions.sh" "$REPO_DIR/install.zsh.sh"

echo "=== [7] Hardening de Red (Tor Cage) ==="
cd "$REPO_DIR"
./configure-proxy.sh

echo "=== [8] Instalando extensiones ==="
./setup-extensions.sh
./install.zsh.sh

echo "=== [9] Configuración global de Firefox (System Proxy) ==="
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

echo "=== [10] Limpiando interfaces antiguas ==="
echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces

echo "=== Bootstrap finalizado. Reiniciando... ==="
reboot
