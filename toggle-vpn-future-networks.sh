#!/bin/bash
set -e

# --- CONFIGURATION ---
VPN_SEARCH="${1:-david}"

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with sudo."
  exit 1
fi

echo "🔍 Detecting VPN profile: '$VPN_SEARCH'..."
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN profile containing '$VPN_SEARCH' not found."
    exit 1
fi
echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "⚙️  Unlocking VPN profile (Global Autoconnect)..."
nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Installing Future-Proof Dispatcher..."
# This script monitors NetworkManager events
cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-auto-link
#!/bin/bash
INTERFACE=$1
ACTION=$2
VPN_UUID="REPLACE_VPN_UUID"

case "$ACTION" in
    up)
        # If the connection that just started is WiFi or Ethernet
        if [ -n "$CONNECTION_UUID" ]; then
            TYPE=$(nmcli -g connection.type connection show "$CONNECTION_UUID")

            if [ "$TYPE" = "802-11-wireless" ] || [ "$TYPE" = "802-3-ethernet" ]; then
                # Check if the VPN is already linked
                SEC=$(nmcli -g connection.secondaries connection show "$CONNECTION_UUID" 2>/dev/null)
                
                if [[ "$SEC" != *"$VPN_UUID"* ]]; then
                    # Link the VPN
                    nmcli connection modify "$CONNECTION_UUID" connection.secondaries "$VPN_UUID"
                    
                    # Trigger a background re-up so the VPN starts immediately on the first join
                    (sleep 2 && nmcli connection up "$CONNECTION_UUID") &
                fi
            fi
        fi
        ;;
esac
EOD

# Hardcode the UUID into the dispatcher and set permissions
sed -i "s/REPLACE_VPN_UUID/$VPN_UUID/" /etc/NetworkManager/dispatcher.d/99-vpn-auto-link
chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-auto-link

echo "🔄 Restarting NetworkManager..."
systemctl restart NetworkManager

echo "✅ DONE."
echo "Any network you join from now on will automatically link to '$VPN_NAME'."
