# 1. Create the final "Auto-Future" Master Script
cat << 'EOF' > fix_vpn_complete.sh
#!/bin/bash

# Config: The name of your VPN profile
VPN_SEARCH="david"

echo "🔍 Step 0: Detecting VPN UUID dynamically..."
# Dynamically get the official Name and UUID of the VPN
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN containing '$VPN_SEARCH' not found."
    exit 1
fi

echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "⚙️  Step 1: Unlocking VPN profile (making it global)..."
# Remove user permissions so it can be managed by the system dispatcher
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "🔗 Step 2: Linking all EXISTING Wi-Fi networks to this VPN..."
# Link every saved Wi-Fi connection to launch this VPN as a secondary
WIFI_CONNS=$(nmcli --terse --fields NAME,TYPE connection show | grep :802-11-wireless | cut -d: -f1)
while read -r conn; do
    if [ -n "$conn" ]; then
        echo "   -> Linking: $conn"
        sudo nmcli connection modify "$conn" connection.secondaries "$VPN_UUID" 2>/dev/null
    fi
done <<< "$WIFI_CONNS"

echo "📝 Step 3: Creating Future-Proof Dispatcher (Auto-Link + Auto-Reactivate + Routes)..."
# This is the "brain" that monitors all network events
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2
VPN_UUID=\"$VPN_UUID\"

case \"\$ACTION\" in
    up)
        # AUTO-LINK FOR NEW NETWORKS
        if [ -n \"\$CONNECTION_UUID\" ]; then
            TYPE=\$(nmcli -g connection.type connection show \"\$CONNECTION_UUID\")
            if [ \"\$TYPE\" = \"802-11-wireless\" ]; then
                SEC=\$(nmcli -g connection.secondaries connection show \"\$CONNECTION_UUID\" 2>/dev/null)
                
                # If the VPN isn't linked yet, link it and restart the connection silently
                if [[ \"\$SEC\" != *\"\$VPN_UUID\"* ]]; then
                    nmcli connection modify \"\$CONNECTION_UUID\" connection.secondaries \"\$VPN_UUID\"
                    
                    # RE-UP: Background restart so the VPN starts NOW without manual toggle
                    (sleep 2 && nmcli connection up \"\$CONNECTION_UUID\") &
                fi
            fi
        fi
        ;;
    vpn-up)
        # COPILOT BYPASS: Force traffic through physical hardware (wlp2s0)
        GW=\$(ip route | grep default | grep -v tun | awk '{print \$3}' | head -n1)
        DEV=\$(ip route | grep default | grep -v tun | awk '{print \$5}' | head -n1)
        SUBNETS=(\"104.16.0.0/12\" \"172.64.0.0/13\" \"13.107.0.0/16\" \"150.171.0.0/16\")
        
        if [ -n \"\$GW\" ] && [ -n \"\$DEV\" ]; then
            for net in \"\${SUBNETS[@]}\"; do
                # Use high-priority metric to beat the VPN tunnel
                ip route add \$net via \$GW dev \$DEV metric 5 2>/dev/null || \\
                ip route replace \$net via \$GW dev \$DEV metric 5
            done
        fi
        ;;
esac
EOD"

# Apply system permissions for the dispatcher script
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Step 4: Forcing refresh of current connection..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ ALL-IN-ONE CONFIGURATION COMPLETE."
echo "Your Wi-Fi is reconnecting. Any future Wi-Fi will now auto-link and start the VPN."
EOF

# 2. Make executable and run
chmod +x fix_vpn_complete.sh
./fix_vpn_complete.sh
