# 1. Create the Master Script
cat << 'EOF' > fix_vpn_final.sh
#!/bin/bash

# Configuration
VPN_NAME="david"
VPN_UUID="67134804-a046-4ab7-8a4a-28fbfc8a37cf"

echo "⚙️  Step 1: Unlocking VPN profile '$VPN_NAME'..."
# Remove user permissions and enable autoconnect
nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "🔗 Step 2: Linking all WiFi networks to this VPN..."
# Dynamically find all WiFi connections and link them to the VPN
WIFI_CONNS=$(nmcli --terse --fields NAME,TYPE connection show | grep :802-11-wireless | cut -d: -f1)
while read -r conn; do
    if [ -n "$conn" ]; then
        echo "   -> Linking: $conn"
        nmcli connection modify "$conn" connection.secondaries "$VPN_UUID" 2>/dev/null
    fi
done <<< "$WIFI_CONNS"

echo "📝 Step 3: Creating the Intelligent Dispatcher..."
# This script runs every time the VPN connects and finds the current gateway automatically
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2

# Only trigger when the VPN is up
if [ \"\$ACTION\" = \"vpn-up\" ]; then
    # DYNAMIC DETECTION: Find the current local gateway (ignoring the VPN tunnel)
    GW=\$(ip route | grep default | grep -v tun | awk '{print \$3}' | head -n1)
    DEV=\$(ip route | grep default | grep -v tun | awk '{print \$5}' | head -n1)
    
    # Copilot/Microsoft Ranges
    SUBNETS=(\"104.16.0.0/12\" \"172.64.0.0/13\" \"13.107.0.0/16\" \"150.171.0.0/16\")
    
    if [ -n \"\$GW\" ] && [ -n \"\$DEV\" ]; then
        for net in \"\${SUBNETS[@]}\"; do
            # Add route with high priority (metric 5)
            ip route add \$net via \$GW dev \$DEV metric 5 2>/dev/null || \\
            ip route replace \$net via \$GW dev \$DEV metric 5
        done
    fi
fi
EOD"

# Set permissions for the dispatcher
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Step 4: Restarting Network Services..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ MASTER CONFIGURATION COMPLETE."
echo "Your WiFi is reconnecting; the VPN and Copilot bypass will start automatically."
EOF

# 2. Run it
chmod +x fix_vpn_final.sh
sudo ./fix_vpn_final.sh
