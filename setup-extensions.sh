#!/bin/bash


#USER INSTALLED EXTENSIONS: INSTALL MANUALLY = "ADD TO DESKTOP" "DESKTOP LOGO" "DESKTOP WIDGETS"

echo "=== Instalando extensiones GNOME desde APT ==="

sudo apt update

sudo apt install -y \
gnome-shell-extension-caffeine \
gnome-shell-extension-dash-to-panel \
gnome-shell-extension-dashtodock \
gnome-shell-extension-desktop-icons-ng \
gnome-shell-extension-gpaste \
gnome-shell-extension-prefs \
gnome-shell-extension-system-monitor \
gnome-shell-extension-tiling-assistant \
gnome-shell-extension-drive-menu \
gnome-shell-extensions-common \
gnome-shell-extensions-extra \
gnome-shell-extensions \
gir1.2-gnomedesktop-4.0 \
gpaste-2 \
gnome-shell-extension-manager

echo "=== Creando carpeta de extensiones de usuario ==="

LOCAL_DIR="$HOME/.local/share/gnome-shell/extensions"

mkdir -p "$LOCAL_DIR"

echo "=== Instalando extensiones locales (usuario) ==="

EXT_LOCAL=(
"add-to-desktop@tommimon.github.com"
"desktop-widgets@NiffirgkcaJ.github.com"
"logowidget@github.com.howbea"
"azclock@azclock.gitlab.com"
)

for ext in "${EXT_LOCAL[@]}"; do
    if [ -d "$ext" ]; then
        echo "Copiando $ext..."
        cp -r "$ext" "$LOCAL_DIR/"
    else
        echo "No se encontró la carpeta local: $ext"
    fi
done

echo "=== Habilitando extensiones ==="

EXT_ENABLED=(
"desktop-widgets@NiffirgkcaJ.github.com"
"add-to-desktop@tommimon.github.com"
"logowidget@github.com.howbea"
"caffeine@patapon.info"
"dash-to-panel@jderose9.github.com"
"ding@rastersoft.com"
"GPaste@gnome-shell-extensions.gnome.org"
"system-monitor@gnome-shell-extensions.gcampax.github.com"
"tiling-assistant@leleat-on-github"
"hibernate-status@dromi"
"vertical-workspaces@G-dH.github.com"
"user-theme@gnome-shell-extensions.gcampax.github.com"
"drive-menu@gnome-shell-extensions.gcampax.github.com"
)

for ext in "${EXT_ENABLED[@]}"; do
    echo "Habilitando $ext..."
    gnome-extensions enable "$ext" 2>/dev/null
done

echo "=== Proceso completado ==="

if [ "$XDG_SESSION_TYPE" = "x11" ]; then
    echo "Reiniciando GNOME Shell (Xorg)..."
    echo "Presiona ALT+F2, escribe r y pulsa Enter"
else
    echo "En Wayland debes cerrar sesión para aplicar cambios."
fi
