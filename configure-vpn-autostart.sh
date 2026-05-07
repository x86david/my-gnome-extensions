cat << 'EOF' > fix_vpn_complete.sh
#!/bin/bash

# --- CONFIGURACIÓN ---
VPN_SEARCH="david"
DNS_PORT="9053"
SOCKS_PORT="9050"

# Detectar usuario real
REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")

echo "🔍 Paso 0: Detectando VPN..."
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN '$VPN_SEARCH' no encontrada."
    exit 1
fi

echo "🕵️  Paso 1: Instalando dependencias..."
sudo apt update && sudo apt install -y tor iptables-persistent dbus-x11

echo "⚙️  Paso 2: Configurando Tor..."
sudo bash -c "cat << 'EOT' > /etc/tor/torrc
SocksPort 127.0.0.1:$SOCKS_PORT
DNSPort 127.0.0.1:$DNS_PORT
EOT"
sudo systemctl restart tor

echo "🛡️  Paso 3: Hijacking DNS (iptables)..."
sudo iptables -t nat -F OUTPUT
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Paso 4: Activando Proxy GNOME para $REAL_USER..."
# Forzamos la sesión de DBUS para evitar errores de "child process"
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Paso 5: Configurando Autoconnect VPN..."
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Paso 6: Instalando Dispatcher de Rutas..."
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2
VPN_UUID=\"$VPN_UUID\"

case \"\$ACTION\" in
    up)
        if [ -n \"\$CONNECTION_UUID\" ]; then
            TYPE=\$(nmcli -g connection.type connection show \"\$CONNECTION_UUID\")
            if [ \"\$TYPE\" = \"802-11-wireless\" ]; then
                SEC=\$(nmcli -g connection.secondaries connection show \"\$CONNECTION_UUID\" 2>/dev/null)
                if [[ \"\$SEC\" != *\"\$VPN_UUID\"* ]]; then
                    nmcli connection modify \"\$CONNECTION_UUID\" connection.secondaries \"\$VPN_UUID\"
                    (sleep 2 && nmcli connection up \"\$CONNECTION_UUID\") &
                fi
            fi
        fi
        ;;
    vpn-up)
        GW=\$(ip route | grep default | grep -v tun | awk '{print \$3}' | head -n1)
        DEV=\$(ip route | grep default | grep -v tun | awk '{print \$5}' | head -n1)
        SUBNETS=(\"104.16.0.0/12\" \"172.64.0.0/13\" \"13.107.0.0/16\" \"150.171.0.0/16\")
        if [ -n \"\$GW\" ] && [ -n \"\$DEV\" ]; then
            for net in \"\${SUBNETS[@]}\"; do
                ip route add \$net via \$GW dev \$DEV metric 5 2>/dev/null || \\
                ip route replace \$net via \$GW dev \$DEV metric 5
            done
        fi
        ;;
esac
EOD"
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Paso 7: Reiniciando red..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ PROCESO FINALIZADO CON ÉXITO."
EOF

chmod +x fix_vpn_complete.sh
sudo ./fix_vpn_complete.sh
