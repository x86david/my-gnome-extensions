#!/bin/bash

# --- 1. FASE DE PURGA TOTAL (LIMPIEZA DE RAÍZ) ---
echo "Iniciando PURGA TOTAL de extensiones y configuraciones..."

# A. Eliminar archivos físicos (Local)
rm -rf "$HOME/.local/share/gnome-shell/extensions/*"
rm -rf "$HOME/.config/gnome-shell/extensions" # Algunas guardan config aquí

# B. Resetear configuraciones en la base de datos de GNOME (Dconf)
# Esto borra los ajustes personalizados de TODAS las extensiones
gsettings reset-recursively org.gnome.shell.extensions
gsettings reset org.gnome.shell enabled-extensions
gsettings reset org.gnome.shell disabled-extensions

# C. Desinstalar paquetes del sistema y sus archivos de configuración
sudo apt purge -y \
    gnome-shell-extension-* \
    gnome-shell-extensions \
    gnome-shell-extensions-extra
sudo apt autoremove -y && sudo apt autoclean

# --- 2. INSTALACIÓN DE DEPENDENCIAS LIMPIAS ---
echo "Instalando dependencias base..."
sudo apt update && sudo apt install -y \
    gnome-shell-extension-manager \
    gnome-shell-extension-prefs \
    gir1.2-gnomedesktop-3.0 \
    gir1.2-gnomedesktop-4.0 \
    pipx dbus-x11

# Reinstalar la herramienta CLI de descarga
pipx install gnome-extensions-cli --system-site-packages --force
export PATH="$PATH:$HOME/.local/bin"

# --- 3. INSTALACIÓN GLOBAL DEL TEMA ---
THEME_NAME="flat-remux-dark-fullpanel"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" &> /dev/null && pwd)
sudo mkdir -p /usr/share/themes
if [ -d "$SCRIPT_DIR/$THEME_NAME" ]; then
    sudo rm -rf "/usr/share/themes/$THEME_NAME"
    sudo cp -r "$SCRIPT_DIR/$THEME_NAME" /usr/share/themes/
fi

# --- 4. REINSTALACIÓN DE FAVORITOS (LISTA UNIFICADA) ---
all_extensions=(
    "tiling-assistant@leleat-on-github"
    "search-light@://github.com"
    "blur-my-shell@aunetx"
    "caffeine@patapon.info"
    "dash-to-panel@://github.com"
    "desktop-icons-ng@rastersoft.com"
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

echo "Descargando extensiones desde cero..."
for uuid in "${all_extensions[@]}"; do
    ~/.local/bin/gext install "$uuid" --quiet 2>/dev/null
done

# --- 5. ACTIVACIÓN LIMPIA (TUS AZULES) ---
echo "Sincronizando activación en sesión limpia..."
sleep 2

ACTIVE_LIST="[ \
'add-to-desktop@://github.com', \
'logowidget@github.com.howbea', \
'desktop-widgets@://github.com', \
'caffeine@patapon.info', \
'dash-to-panel@://github.com', \
'ding@rastersoft.com', \
'gpaste@gnome-shell-extensions.gnome.org', \
'hibernate-status@dromi', \
'drive-menu@://github.com', \
'system-monitor@://github.com', \
'tiling-assistant@leleat-on-github', \
'user-theme@://github.com', \
'vertical-workspaces@://github.com', \
'blur-my-shell@aunetx', \
'search-light@://github.com' \
]"

gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "$ACTIVE_LIST"
gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"

# --- 6. GRUB ---
sudo sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=console/' /etc/default/grub
sudo update-grub

echo "-------------------------------------------------------"
echo "¡PURGA Y REINSTALACIÓN COMPLETADA!"
echo "Se han eliminado todas las configuraciones viejas."
echo "REINICIA EL EQUIPO PARA ASEGURAR UNA SESIÓN LIMPIA."
echo "-------------------------------------------------------"
