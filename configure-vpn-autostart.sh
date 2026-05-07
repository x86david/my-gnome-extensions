# 1. Create the final "Privacy & VPN Master" Script
cat << 'EOF' > fix_vpn_complete.sh
#!/bin/bash

# Configuration
VPN_SEARCH="david"
DNS_PORT="9053"
SOCKS_PORT="9050"

echo "🔍 Step 0: Detecting VPN UUID dynamically..."
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN containing '$VPN_SEARCH' not found."
    exit 1
fi
echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "🕵️  Step 1: Installing and Configuring Tor..."
sudo apt update && sudo apt install -y tor iptables-persistent
sudo bash -c "cat << 'EOT' > /etc/tor/torrc
SocksPort 127.0.0.1:$SOCKS_PORT
DNSPort 127.0.0.1:$DNS_PORT
EOT"
sudo systemctl restart tor

echo "🛡️  Step 2: Hijacking System DNS (Corrected iptables syntax)..."
# We use -j REDIRECT --to-ports correctly for the nat table
sudo iptables -t nat -F OUTPUT
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
# Save rules so they persist after reboot
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Step 3: Activating GNOME System Proxy (SOCKS5)..."
gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Step 4: Unlocking VPN profile '$VPN_NAME'..."
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "🔗 Step 5: Linking EXISTING Wi-Fi networks to this VPN..."
WIFI_CONNS=$(nmcli --terse --fields NAME,TYPE connection show | grep :802-11-wireless | cut -d: -f1)
while read -r conn; do
    if [ -n "$conn" ]; then
        echo "   -> Linking: $conn"
        sudo nmcli connection modify "$conn" connection.secondaries "$VPN_UUID" 2>/dev/null
    fi
done <<< "$WIFI_CONNS"

echo "📝 Step 6: Creating Future-Proof Dispatcher (Auto-Link + Copilot Bypass)..."
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2
VPN_UUID=\"$VPN_UUID\"

case \"\$ACTION\" in
    up)
        # AUTO-LINK NEW NETWORKS: Link VPN and restart connection silently
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
        # COPILOT BYPASS: Force traffic through physical hardware
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

echo "🔄 Step 7: Restarting Network Services..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ ALL-IN-ONE PRIVACY MASTER COMPLETE."
EOF

# 2. Make executable and run
chmod +x fix_vpn_complete.sh
./fix_vpn_complete.sh
