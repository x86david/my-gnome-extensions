#!/bin/bash
set -e

###############################################
# 1. DESINSTALAR ZSH DE TODO EL SISTEMA
###############################################

echo "[1] Eliminando paquetes Zsh..."
apt purge -y zsh zsh-common || true
apt autoremove -y || true

echo "[2] Eliminando configuraciones de usuarios reales..."
while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -ge 1000 ] || [ "$user" = "root" ] || continue
    [ -d "$home" ] || continue

    rm -f  "$home/.zshrc"
    rm -rf "$home/.oh-my-zsh"
done < /etc/passwd

echo "[3] Eliminando configuraciones globales..."
rm -rf /etc/zsh || true
rm -f /etc/zshenv /etc/zprofile /etc/zlogin /etc/zlogout /etc/zshrc || true

echo "[4] Restaurando /bin/bash como shell..."
cp /etc/passwd /etc/passwd.bak.$(date +%s)
sed -i 's#/usr/bin/zsh#/bin/bash#g; s#/bin/zsh#/bin/bash#g' /etc/passwd

###############################################
# 2. INSTALACIÓN DE ZSH
###############################################

echo
echo "¿A quién quieres instalar Zsh?"
echo "1) Solo al usuario actual ($USER)"
echo "2) Solo a root"
echo "3) A TODOS los usuarios reales (UID >= 1000) + root"
read -p "Elige una opción (1/2/3): " opt

install_for_user() {
    local user="$1"
    local home_dir
    home_dir=$(eval echo "~$user")

    echo "→ Instalando Zsh para $user (home: $home_dir)"

    sudo -u "$user" RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        'bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

    ZSH_CUSTOM="$home_dir/.oh-my-zsh/custom"

    sudo -u "$user" git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true

    sudo -u "$user" git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true

    sudo -u "$user" git clone https://github.com/zsh-users/zsh-history-substring-search \
        "$ZSH_CUSTOM/plugins/zsh-history-substring-search" 2>/dev/null || true

    cat <<EOF | sudo tee "$home_dir/.zshrc" >/dev/null
export ZSH="$home_dir/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source \$ZSH/oh-my-zsh.sh

# Prompt profesional tipo bash
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %# '

autoload -Uz compinit
compinit
EOF

    chown "$user":"$user" "$home_dir/.zshrc"
    chsh -s /usr/bin/zsh "$user"
}

echo "[5] Instalando paquetes..."
apt update
apt install -y zsh curl git

case "$opt" in
    1) install_for_user "$USER" ;;
    2) install_for_user "root" ;;
    3)
        install_for_user "root"
        while IFS=: read -r user _ uid _ _ home shell; do
            [ "$uid" -ge 1000 ] || continue
            [ -d "$home" ] || continue
            install_for_user "$user"
        done < /etc/passwd
        ;;
    *) echo "Opción inválida." ; exit 1 ;;
esac

###############################################
# 3. CONFIGURACIÓN POR DEFECTO PARA NUEVOS USUARIOS
###############################################

echo "[6] Configurando Zsh por defecto para nuevos usuarios..."

mkdir -p /etc/skel

cat <<'EOF' > /etc/skel/.zshrc
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source \$ZSH/oh-my-zsh.sh

PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %# '

autoload -Uz compinit
compinit
EOF

echo "✔ Nuevos usuarios tendrán Zsh configurado automáticamente."

echo "✔ Instalación completada. Ejecuta: exec zsh"