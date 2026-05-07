# 1. Create the final "Absolute Privacy" Master Script
cat << 'EOF' > fix_vpn_complete.sh
#!/bin/bash

# --- CONFIGURATION ---
VPN_SEARCH="david"
DNS_PORT="9053"
SOCKS_PORT="9050"

# Detect the real user behind sudo
REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")
USER_HOME=$(eval echo "~$REAL_USER")

echo "📂 Step 1: Fixing file permissions for VPN Import..."
# Ensure the certificates/ovpn folder is readable by NetworkManager
# We apply this to common local share folders where certificates often live
sudo chown -R $REAL_USER:$REAL_USER "$USER_HOME/.local/share/networkmanagement" 2>/dev/null
sudo chmod -R 700 "$USER_HOME/.local/share/networkmanagement" 2>/dev/null

echo "🔍 Step 2: Detecting VPN Profile..."
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN containing '$VPN_SEARCH' not found."
    echo "Please import your .ovpn file in GNOME Settings first."
    exit 1
fi
echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "🕵️  Step 3: Installing Tor & System Dependencies..."
sudo apt update && sudo apt install -y tor iptables-persistent dbus-x11

echo "⚙️  Step 4: Configuring Tor (DNS + SOCKS)..."
sudo bash -c "cat << 'EOT' > /etc/tor/torrc
SocksPort 127.0.0.1:$SOCKS_PORT
DNSPort 127.0.0.1:$DNS_PORT
EOT"
sudo systemctl restart tor

echo "🛡️  Step 5: Hijacking System DNS (iptables Redirect)..."
sudo iptables -t nat -F OUTPUT
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Step 6: Forcing GNOME System Proxy for $REAL_USER..."
# We use the D-Bus session address to talk to your GNOME desktop from sudo
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Step 7: Unlocking VPN profile (Global Autoconnect)..."
# Remove 'permissions=user' and enable autoconnect
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Step 8: Installing Intelligent Dispatcher (Auto-Link + Copilot Bypass)..."
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2
VPN_UUID=\"$VPN_UUID\"

case \"\$ACTION\" in
    up)
        # Link NEW Wi-Fi networks and trigger silent re-up
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
        # Force Copilot/Microsoft traffic through Physical Wi-Fi (Bypass Tunnel)
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

echo "🔄 Step 9: Restarting Network Stack..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ ALL SYSTEMS ACTIVE AND HARDENED."
EOF

# 2. Run the script
chmod +x fix_vpn_complete.sh
sudo ./fix_vpn_complete.sh
