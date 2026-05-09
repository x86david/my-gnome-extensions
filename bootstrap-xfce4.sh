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

echo "=== [2] Instalando stack estándar (sudo, git, NetworkManager, XFCE4, Tor) ==="
apt install -y sudo git network-manager dbus-x11 network-manager-openvpn \
    tor iptables-persistent xfce4 xfce4-goodies

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

sleep 10

echo "=== [6] Clonando repositorio de configuración ==="
REPO_DIR="/usr/local/share/my-xfce-config"
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
chmod +x "$REPO_DIR/configure-proxy.sh" \
          "$REPO_DIR/install.zsh.sh"

echo "=== [9] Hardening de Red (Tor Cage) ==="
cd "$REPO_DIR"
./configure-proxy.sh

# Desactiva privacidad para continuar instalación con red normal
/usr/local/bin/toggle-privacy off

# Espera activa hasta que haya conexión
echo "⏳ Esperando a que la red vuelva..."
until ping -c1 deb.debian.org &>/dev/null; do
  sleep 2
done
echo "✅ Red online, continuando instalación."

echo "=== [10] Instalando Zsh ==="
./install.zsh.sh

echo "=== [11] Configuración global de Firefox (System Proxy) ==="
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

echo "=== Bootstrap XFCE4 finalizado. Reiniciando... ==="
reboot
