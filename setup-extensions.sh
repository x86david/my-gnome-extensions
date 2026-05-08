#!/bin/bash
set -e

echo "=== Installing GNOME extensions from APT ==="

apt update

apt install -y \
  gnome-shell-extension-caffeine \
  gnome-shell-extension-dash-to-panel \
  gnome-shell-extension-desktop-icons-ng \
  gnome-shell-extension-gpaste \
  gnome-shell-extension-system-monitor \
  gnome-shell-extension-tiling-assistant \
  gnome-shell-extension-drive-menu \
  gnome-shell-extension-places-menu \
  gnome-shell-extension-user-theme \
  gir1.2-gnomedesktop-4.0 \
  gnome-shell-extensions \
  gpaste-2

echo "=== Installing local extensions for each user ==="

EXT_LOCAL=(
  "add-to-desktop@tommimon.github.com"
  "desktop-widgets@NiffirgkcaJ.github.com"
  "logowidget@github.com.howbea"
  "azclock@azclock.gitlab.com"
  "blur-my-shell@aunetx"
  "burn-my-windows@schneegans.github.com"
  "lockscreen-extension@pratap.fastmail.fm"
  "IP-Finder@linxgem33.com"
  "hibernate-status@dromi"
)

while IFS=: read -r user _ uid _ _ home shell; do
  [ "$uid" -ge 1000 ] || continue
  [ -d "$home" ] || continue

  LOCAL_DIR="$home/.local/share/gnome-shell/extensions"
  mkdir -p "$LOCAL_DIR"

  echo "→ Installing local extensions for $user"

  for ext in "${EXT_LOCAL[@]}"; do
      if [ -d "$ext" ]; then
          cp -r "$ext" "$LOCAL_DIR/" 2>/dev/null || true
          chown -R "$user":"$user" "$LOCAL_DIR/$ext" 2>/dev/null || true
      else
          echo "Local extension folder not found: $ext"
      fi
  done

done < /etc/passwd

echo "=== Local extension installation complete ==="
