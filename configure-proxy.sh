#!/bin/bash
# configure-proxy.sh
set -e

echo "⚙️  Configuring Torrc..."
cat << 'EOF' > /etc/tor/torrc
SocksPort 127.0.0.1:9050
DNSPort 127.0.0.1:9053
TransPort 127.0.0.1:9040
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
EOF
systemctl restart tor

echo "📝 Installing 'toggle-privacy' command to /usr/local/bin..."
cat << 'EOF' > /usr/local/bin/toggle-privacy
#!/bin/bash
VPN_PORT="1194"
DNS_PORT="9053"
TRANS_PORT="9040"
SOCKS_PORT="9050"

# Detect real user for GNOME proxy
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
        echo "🛡️  Enforcing Tor Cage..."
        sudo iptables -F
        sudo iptables -t nat -F
        sudo iptables -P OUTPUT DROP
        sudo iptables -A OUTPUT -o lo -j ACCEPT
        sudo iptables -A OUTPUT -m owner --uid-owner debian-tor -j ACCEPT
        sudo iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $SOCKS_PORT -j ACCEPT
        sudo iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $TRANS_PORT -j ACCEPT
        sudo iptables -A OUTPUT -d 127.0.0.1 -p udp --dport $DNS_PORT -j ACCEPT
        sudo iptables -A OUTPUT -p udp --dport $VPN_PORT -j ACCEPT
        sudo iptables -t nat -A OUTPUT ! -o lo -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
        sudo iptables -t nat -A OUTPUT ! -o lo -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT
        set_gnome_proxy "manual"
        ;;
    app)
        echo "🔌 Switching to App Mode..."
        sudo iptables -P OUTPUT ACCEPT
        sudo iptables -F
        sudo iptables -t nat -F
        sudo iptables -t nat -A OUTPUT ! -o lo -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
        set_gnome_proxy "manual"
        ;;
    off)
        echo "🔓 Privacy Off..."
        sudo iptables -P OUTPUT ACCEPT
        sudo iptables -F
        sudo iptables -t nat -F
        set_gnome_proxy "none"
        ;;
    *)
        echo "Usage: toggle-privacy {hardened|app|off}"
        exit 1
        ;;
esac
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
EOF

# Set permissions
chmod +x /usr/local/bin/toggle-privacy

echo "🛡️  Activating Hardened Mode by default..."
/usr/local/bin/toggle-privacy hardened

echo "✅ 'toggle-privacy' is now available as a global command."
