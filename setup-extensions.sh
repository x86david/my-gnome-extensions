#!/bin/bash

# --- 1. LIMPIEZA INICIAL ---
echo "Limpiando entorno para una instalación nueva..."
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"
gsettings reset org.gnome.shell enabled-extensions

# --- 2. INSTALACIÓN POR APT (EXTENSIONES DE SISTEMA) ---
# Instalamos las versiones estables de Debian 13
echo "Instalando extensiones de sistema y dependencias..."
sudo apt update && sudo apt install -y \
    gnome-shell-extension-caffeine \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-gpaste \
    gnome-shell-extension-system-monitor \
    gnome-shell-extension-tiling-assistant \
    gnome-shell-extensions \
    gnome-shell-extension-manager \

# Nota: 'gnome-shell-extensions' incluye: window-list, drive-menu y user-theme.

# --- 3. CONFIGURACIÓN DE HERRAMIENTA CLI ---
# Para instalar las extensiones de usuario (Third Party)
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 4. INSTALACIÓN DE EXTENSIONES DE USUARIO (CLI) ---
user_extensions=(
    "add-to-desktop@://github.com"
    "logowidget@github.com.howbea"
    "desktop-widgets@://github.com"
    "hibernate-status@dromi"
    "vertical-workspaces@://github.com"
)

echo "Instalando extensiones de usuario desde la web..."
for uuid in "${user_extensions[@]}"; do
    ~/.local/bin/gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. ACTIVACIÓN DE LA LISTA ESPECÍFICA ---
# Definimos exactamente las que quieres habilitar
ACTIVE_LIST="[ \
'caffeine@patapon.info', \
'dash-to-dock@://gmail.com', \
'dash-to-panel@://github.com', \
'ding@rastersoft.com', \
'gpaste@gnome-shell-extensions.gnome.org', \
'hibernate-status@dromi', \
'drive-menu@://github.com', \
'system-monitor@://github.com', \
'tiling-assistant@leleat-on-github', \
'user-theme@://github.com', \
'vertical-workspaces@://github.com', \
'window-list@://github.com', \
'add-to-desktop@://github.com', \
'logowidget@github.com.howbea', \
'desktop-widgets@://github.com' \
]"

echo "Activando extensiones..."
sleep 2 # Pausa para que el sistema reconozca las carpetas nuevas
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"

echo "-------------------------------------------------------"
echo "¡Instalación completada!"
echo "RECUERDA: Debes reiniciar la sesión para que todo cargue."
echo "-------------------------------------------------------"
