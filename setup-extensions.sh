#!/bin/bash

# --- 1. LIMPIEZA Y PREPARACIÓN ---
echo "Limpiando entorno y preparando instalación..."
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"

# --- 2. INSTALACIÓN POR APT (REPOSITORIOS DEBIAN) ---
# He corregido los nombres para que coincidan con los paquetes reales de Debian 13
echo "Instalando paquetes desde repositorios oficiales..."
sudo apt update && sudo apt install -y \
    gnome-shell-extension-manager \
    gnome-shell-extension-prefs \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-arc-menu \
    gnome-shell-extension-gsconnect \
    gnome-shell-extension-gpaste \
    gnome-shell-extensions \
    gnome-shell-extensions-extra \
    gir1.2-gnomedesktop-3.0 \
    gir1.2-gnomedesktop-4.0 \
    pipx dbus-x11

# --- 3. CONFIGURACIÓN DE GEXT (PARA LO QUE NO ESTÁ EN APT) ---
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 4. INSTALACIÓN DE FAVORITOS (TIENDA GNOME) ---
# Estas suelen no estar en APT o ser versiones muy viejas, mejor bajarlas directo
web_favorites=(
    "tiling-assistant@leleat-on-github"
    "search-light@://github.com"
    "blur-my-shell@aunetx"
    "caffeine@patapon.info"
    "system-monitor@://github.com"
    "desktop-widgets@://github.com"
    "logowidget@github.com.howbea"
    "add-to-desktop@://github.com"
    "hibernate-status@dromi"
    "vertical-workspaces@://github.com"
)

echo "Instalando favoritos desde GNOME Extensions..."
for uuid in "${web_favorites[@]}"; do
    ~/.local/bin/gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. INSTALACIÓN GLOBAL DEL TEMA ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo rm -rf "/usr/share/themes/$THEME_NAME"
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
fi

# --- 6. ACTIVACIÓN SINCRONIZADA (TUS AZULES) ---
# He incluido 'search-light' y 'blur-my-shell' en la lista de activas
ACTIVE_LIST="[ \
'add-to-desktop@://github.com', \
'logowidget@github.com.howbea', \
'desktop-widgets@://github.com', \
'caffeine@patapon.info', \
'dash-to-panel@://github.com', \
'ding@rastersoft.com', \
'GPaste@gnome-shell-extensions.gnome.org', \
'hibernate-status@dromi', \
'system-monitor@://github.com', \
'tiling-assistant@leleat-on-github', \
'user-theme@://github.com', \
'vertical-workspaces@://github.com', \
'blur-my-shell@aunetx', \
'search-light@://github.com' \
]"

echo "Sincronizando activación..."
sleep 2
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 7. GRUB ---
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "¡Hecho! Se han instalado todas tus favoritas."
echo "REINICIA LA SESIÓN PARA VER LOS CAMBIOS."
echo "-------------------------------------------------------"
