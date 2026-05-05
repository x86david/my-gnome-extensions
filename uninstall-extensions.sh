#!/bin/bash
echo "--- INICIANDO LIMPIEZA TOTAL ---"

# 1. Desinstalar todos los paquetes de extensiones de sistema
sudo apt purge -y gnome-shell-extension-* gnome-shell-extensions gnome-shell-extensions-extra
sudo apt autoremove -y

# 2. Borrar archivos físicos en tu carpeta de usuario
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"
rm -rf "$HOME/.config/gnome-shell/extensions" 2>/dev/null

# 3. RESETEAR LA BASE DE DATOS (Dconf)
# Esto es lo más importante para quitar los "bugs" de configuración
dconf reset -f /org/gnome/shell/extensions/
gsettings reset org.gnome.shell enabled-extensions
gsettings reset org.gnome.shell disabled-extensions

echo "--- LIMPIEZA COMPLETADA ---"
echo "Se recomienda reiniciar la VM ahora antes de volver a instalar."
