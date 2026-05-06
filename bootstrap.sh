#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

echo "=== [0] Actualizando sistema ==="
apt update
apt full-upgrade -y

echo "=== [1] Instalando paquetes base (sudo, git, NetworkManager) ==="
apt update
apt install -y sudo git network-manager

echo "=== [2] Limpiando /etc/network/interfaces (solo loopback) ==="

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

echo "=== [3] Activando NetworkManager ==="
systemctl enable NetworkManager
systemctl restart NetworkManager

echo "=== [4] Instalando GNOME minimal (gnome-core) ==="
apt install -y gnome-core

echo "=== [5] Clonando repositorio my-gnome-extensions ==="

REPO_DIR="/usr/local/share/my-gnome-extensions"

mkdir -p /usr/local/share

if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/x86david/my-gnome-extensions.git "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
fi

# Permitir lectura y ejecución (solo en directorios) a todos los usuarios
chmod -R a+rX "$REPO_DIR"

cd "$REPO_DIR"

echo "=== [6] Dando permisos de ejecución a los scripts ==="
chmod +x setup-extensions.sh
chmod +x install.zsh.sh

echo "=== [7] Ejecutando setup-extensions.sh ==="
./setup-extensions.sh

echo "=== [8] Ejecutando install.zsh.sh (modo automático, opción 3 por defecto) ==="
./install.zsh.sh

echo "=== [9] Instalando tema en todos los usuarios ==="

THEME_SRC="$REPO_DIR/flat-remux-dark-fullpanel/gnome-shell"

while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
  [ -d "$home" ] || continue

  THEME_DIR="$home/.themes/flat-remux-dark-fullpanel/gnome-shell"
  mkdir -p "$THEME_DIR"

  cp -r "$THEME_SRC"/* "$THEME_DIR"/
  chown -R "$user":"$user" "$home/.themes"
done < /etc/passwd

echo "=== [10] Importando configuración de Dash-to-Panel ==="

DTP_CONF="$REPO_DIR/dash_to_panel.config"

if [ -f "$DTP_CONF" ]; then
  while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
    [ -d "$home" ] || continue

    echo "→ Importando config Dash-to-Panel para $user"
    sudo -u "$user" dbus-launch dconf load /org/gnome/shell/extensions/dash-to-panel/ < "$DTP_CONF" || true
  done < /etc/passwd
else
  echo "No se encontró dash_to_panel.config, saltando importación."
fi

echo "=== Bootstrap completado. Reinicia para entrar en GNOME. ==="
reboot
