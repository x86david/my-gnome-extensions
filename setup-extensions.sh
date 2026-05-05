#!/bin/bash

# --- 1. LIMPIEZA ABSOLUTA ---
echo "Limpiando rastros de instalaciones incompatibles..."
# Borramos TODO lo local
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"
# Reseteamos dconf de raíz para evitar que persistan errores de esquema
dconf reset -f /org/gnome/shell/extensions/

# Desinstalamos las de sistema que causan el error 'Incompatible' en el Pastebin
sudo apt purge -y gnome-shell-extension-* gnome-shell-extensions
sudo apt autoremove -y

# --- 2. INSTALACIÓN DE HERRAMIENTAS ---
sudo apt update && sudo apt install -y pipx dbus-x11 gnome-shell-extension-manager
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 3. INSTALACIÓN POR UUID (SIN MEZCLAR CON APT) ---
# Usamos solo gext para evitar el error de 'Incompatible' del Pastebin
all_extensions=(
    "tiling-assistant@leleat-on-github"
    "search-light@://github.com"
    "blur-my-shell@aunetx"
    "caffeine@patapon.info"
    "dash-to-panel@://github.com"
    "ding@rastersoft.com"
    "arcmenu@arcmenu.com"
    "system-monitor@://github.com"
    "desktop-widgets@://github.com"
    "logowidget@github.com.howbea"
    "add-to-desktop@://github.com"
    "hibernate-status@dromi"
    "vertical-workspaces@://github.com"
    "user-theme@://github.com"
    "gpaste@gnome-shell-extensions.gnome.org"
    "drive-menu@://github.com"
)

echo "Instalando extensiones desde la web (versiones verificadas)..."
for uuid in "${all_extensions[@]}"; do
    ~/.local/bin/gext install "$uuid" --quiet
done

# --- 4. TEMA GLOBAL ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
fi

# --- 5. ACTIVACIÓN FORZADA (FIX D-BUS ERROR) ---
echo "Aplicando configuración de activación..."
sleep 2

# Lista de activación sincronizada
ACTIVE_LIST="['add-to-desktop@://github.com', 'logowidget@github.com.howbea', 'desktop-widgets@://github.com', 'caffeine@patapon.info', 'dash-to-panel@://github.com', 'ding@rastersoft.com', 'gpaste@gnome-shell-extensions.gnome.org', 'hibernate-status@dromi', 'drive-menu@://github.com', 'system-monitor@://github.com', 'tiling-assistant@leleat-on-github', 'user-theme@://github.com', 'vertical-workspaces@://github.com', 'blur-my-shell@aunetx', 'search-light@://github.com']"

# Ejecutamos gsettings a través de dbus-launch para evitar el error del Pastebin
dbus-launch --exit-with-session gsettings set org.gnome.shell disable-user-extensions false
dbus-launch --exit-with-session gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
dbus-launch --exit-with-session gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 6. GRUB ---
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "¡REPARACIÓN COMPLETADA!"
echo "He forzado la activación mediante D-Bus para evitar errores."
echo "REINICIA EL EQUIPO AHORA para aplicar los cambios."
echo "-------------------------------------------------------"
