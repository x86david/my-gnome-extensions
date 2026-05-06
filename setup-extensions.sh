#!/bin/bash
set -e

echo "=== Instalando extensiones GNOME desde APT ==="

apt update

apt install -y \
  gnome-shell-extension-caffeine \
  gnome-shell-extension-dash-to-panel \
  gnome-shell-extension-dashtodock \
  gnome-shell-extension-desktop-icons-ng \
  gnome-shell-extension-gpaste \
  gnome-shell-extension-system-monitor \
  gnome-shell-extension-tiling-assistant \
  gnome-shell-extension-drive-menu \
  gnome-shell-extension-user-theme \
  gir1.2-gnomedesktop-4.0 \
  gnome-shell-extensions \
  gpaste-2 \
  gnome-shell-extension-manager

echo "=== Instalando extensiones locales en cada usuario ==="

EXT_LOCAL=(
  "add-to-desktop@tommimon.github.com"
  "desktop-widgets@NiffirgkcaJ.github.com"
  "logowidget@github.com.howbea"
  "azclock@azclock.gitlab.com"
)

while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || continue
  [ -d "$home" ] || continue

  LOCAL_DIR="$home/.local/share/gnome-shell/extensions"
  mkdir -p "$LOCAL_DIR"

  echo "→ Instalando extensiones locales para $user"

  for ext in "${EXT_LOCAL[@]}"; do
      if [ -d "$ext" ]; then
          cp -r "$ext" "$LOCAL_DIR/" 2>/dev/null || true
          chown -R "$user":"$user" "$LOCAL_DIR/$ext" 2>/dev/null || true
      else
          echo "No se encontró la carpeta local: $ext"
      fi
  done

done < /etc/passwd

echo "=== Habilitando extensiones para usuarios existentes ==="

# Lista en formato dconf
EXT_LIST="[
  'drive-menu@gnome-shell-extensions.gcampax.github.com',
  'gpaste@gnome-shell-extensions.gnome.org',
  'user-theme@gnome-shell-extensions.gcampax.github.com',
  'caffeine@patapon.info',
  'dash-to-panel@jderose9.github.com',
  'ding@rastersoft.com',
  'system-monitor@gnome-shell-extensions.gcampax.github.com',
  'tiling-assistant@leleat-on-github',
  'hibernate-status@dromi',
  'vertical-workspaces@G-dH.github.com',
  'desktop-widgets@NiffirgkcaJ.github.com',
  'add-to-desktop@tommimon.github.com',
  'logowidget@github.com.howbea'
]"

while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || continue
  [ -d "$home" ] || continue

  echo "→ Forzando extensiones para $user"

  sudo -u "$user" dbus-launch dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST" || true

done < /etc/passwd

echo "=== Configurando extensiones por defecto para nuevos usuarios ==="

cat >/etc/profile.d/flexos-extensions.sh <<'EOF'
#!/bin/bash

FLAG="$HOME/.flexos_extensions_applied"

if [ ! -f "$FLAG" ]; then

    EXT_LIST="[
      'drive-menu@gnome-shell-extensions.gcampax.github.com',
      'gpaste@gnome-shell-extensions.gnome.org',
      'user-theme@gnome-shell-extensions.gcampax.github.com',
      'caffeine@patapon.info',
      'dash-to-panel@jderose9.github.com',
      'ding@rastersoft.com',
      'system-monitor@gnome-shell-extensions.gcampax.github.com',
      'tiling-assistant@leleat-on-github',
      'hibernate-status@dromi',
      'vertical-workspaces@G-dH.github.com',
      'desktop-widgets@NiffirgkcaJ.github.com',
      'add-to-desktop@tommimon.github.com',
      'logowidget@github.com.howbea'
    ]"

    dconf write /org/gnome/shell/enabled-extensions "$EXT_LIST"

    touch "$FLAG"
fi
EOF

chmod +x /etc/profile.d/flexos-extensions.sh

echo "=== Proceso completado ==="

if [ "$XDG_SESSION_TYPE" = "x11" ]; then
    echo "Reinicia GNOME Shell con ALT+F2 → r → Enter"
else
    echo "En Wayland debes cerrar sesión para aplicar cambios."
fi
