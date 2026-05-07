cat << 'EOF' > privacy_master.sh
#!/bin/bash

# --- CONFIGURATION ---
VPN_NAME="david"
VPN_UUID=$(nmcli -g UUID connection show "$VPN_NAME" 2>/dev/null)
PROXY_HOST="127.0.0.1"
PROXY_PORT="9050"
DNS_PORT="9053"

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN '$VPN_NAME' not found. Please import it first."
    exit 1
fi

echo "🕵️  Step 1: Installing and Configuring Tor..."
sudo apt update && sudo apt install -y tor iptables-persistent
sudo bash -c "cat << 'EOT' > /etc/tor/torrc
SocksPort $PROXY_HOST:$PROXY_PORT
DNSPort $PROXY_HOST:$DNS_PORT
EOT"
sudo systemctl restart tor

echo "🛡️  Step 2: Hijacking System DNS (Force through Tor)..."
sudo iptables -t nat -F OUTPUT
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Step 3: Activating GNOME System Proxy (SOCKS5)..."
gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
gsettings set org.gnome.system.proxy.socks port $PROXY_PORT
gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Step 4: Automating VPN '$VPN_NAME'..."
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Step 5: Installing the Intelligent Dispatcher (Copilot Bypass)..."
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
VPN_UUID=\"$VPN_UUID\"
case \"\$2\" in
    up)
        # Auto-link new WiFi networks
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
        # Force Copilot routes to bypass VPN/Proxy
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

echo "🔄 Step 6: Restarting Network..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ ALL SYSTEMS ACTIVE."
echo "1. Your DNS is forced through Tor (Always)."
echo "2. Your GNOME Apps use Tor SOCKS proxy."
echo "3. Your VPN starts automatically."
echo "4. Copilot bypasses everything to stay unblocked."
EOF

chmod +x privacy_master.sh
sudo ./privacy_master.sh
