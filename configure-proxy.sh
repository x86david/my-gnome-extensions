#!/bin/bash
set -e

echo "⚙️ Configurando torrc..."
cat << 'EOF' > /etc/tor/torrc
SocksPort 127.0.0.1:9050
DNSPort 127.0.0.1:9053
TransPort 127.0.0.1:9040
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
EOF

# Reinicia Tor y refresca red para no perder ruta
systemctl restart tor
sleep 2
nmcli networking off && nmcli networking on

echo "📝 Instalando toggle-privacy..."
cat << 'EOF' > /usr/local/bin/toggle-privacy
#!/bin/bash
DNS_PORT="9053"
TRANS_PORT="9040"
SOCKS_PORT="9050"

REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"

set_gnome_proxy() {
    if [ -S "/run/user/$USER_ID/bus" ]; then
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode "$1"
        if [ "$1" = "manual" ]; then
            sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
            sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
        fi
    fi
}

case "$1" in
    hardened)
        iptables -F
        iptables -t nat -F
        iptables -P OUTPUT DROP
        iptables -A OUTPUT -o lo -j ACCEPT
        iptables -A OUTPUT -m owner --uid-owner debian-tor -j ACCEPT
        iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $SOCKS_PORT -j ACCEPT
        iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $TRANS_PORT -j ACCEPT
        iptables -A OUTPUT -d 127.0.0.1 -p udp --dport $DNS_PORT -j ACCEPT
        iptables -t nat -A OUTPUT ! -o lo -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
        iptables -t nat -A OUTPUT ! -o lo -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT
        set_gnome_proxy "manual"
        ;;
    app)
        iptables -P OUTPUT ACCEPT
        iptables -F
        iptables -t nat -F
        iptables -t nat -A OUTPUT ! -o lo -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
        set_gnome_proxy "manual"
        ;;
    off)
        iptables -F
        iptables -t nat -F
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        set_gnome_proxy "none"

        # 🔄 Renueva DHCP con NetworkManager
        IFACE=$(nmcli -t -f DEVICE,STATE d | awk -F: '$2=="connected"{print $1; exit}')
        if [ -n "$IFACE" ]; then
            echo "🔄 Renovando DHCP en $IFACE..."
            nmcli device reapply "$IFACE"
            nmcli device disconnect "$IFACE"
            nmcli device connect "$IFACE"
        fi
        ;;
    *)
        echo "Usage: toggle-privacy {hardened|app|off}"
        exit 1
        ;;
esac
iptables-save > /etc/iptables/rules.v4
EOF

chmod +x /usr/local/bin/toggle-privacy

echo "🛡️ Activando Hardened Mode por defecto..."
/usr/local/bin/toggle-privacy hardened

#echo "🌐 Probando conexión a través del proxy..."
#curl -s http://ip-api.com/json | grep -E '"query"|"country"|"city"|"proxy"'

