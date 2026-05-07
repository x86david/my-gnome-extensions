#!/bin/bash
set -e

# --- CONFIGURATION ---
# Use the first argument as the VPN name, or default to "david"
VPN_SEARCH="${1:-david}"
DNS_PORT="9053"
SOCKS_PORT="9050"

# Detect the real user and session
REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with sudo."
  exit 1
fi

echo "🔍 Step 1: Detecting VPN profile: '$VPN_SEARCH'..."
# Flexible search for the VPN name/UUID
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN profile containing '$VPN_SEARCH' not found."
    echo "Usage: sudo $0 [vpn_name]"
    echo "Current connections available:"
    nmcli -t -f NAME connection show
    exit 1
fi
echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "🕵️  Step 2: Installing Tor & System Dependencies..."
apt update && apt install -y tor iptables-persistent dbus-x11

echo "⚙️  Step 3: Configuring Tor (DNS + SOCKS)..."
cat << EOT > /etc/tor/torrc
SocksPort 127.0.0.1:$SOCKS_PORT
DNSPort 127.0.0.1:$DNS_PORT
EOT
systemctl restart tor

echo "🛡️  Step 4: Hijacking System DNS (iptables Redirect)..."
iptables -t nat -F OUTPUT
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Step 5: Forcing GNOME System Proxy for $REAL_USER..."
# This ensures gsettings hits the actual user session
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Step 6: Unlocking VPN profile (Global Autoconnect)..."
nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Step 7: Installing Intelligent Dispatcher (Auto-Link + Copilot Bypass)..."
cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=$1
ACTION=$2
VPN_UUID="REPLACE_VPN_UUID"

case "$ACTION" in
    up)
        if [ -n "$CONNECTION_UUID" ]; then
            TYPE=$(nmcli -g connection.type connection show "$CONNECTION_UUID")
            if [ "$TYPE" = "802-11-wireless" ]; then
                SEC=$(nmcli -g connection.secondaries connection show "$CONNECTION_UUID" 2>/dev/null)
                if [[ "$SEC" != *"$VPN_UUID"* ]]; then
                    nmcli connection modify "$CONNECTION_UUID" connection.secondaries "$VPN_UUID"
                    (sleep 2 && nmcli connection up "$CONNECTION_UUID") &
                fi
            fi
        fi
        ;;
    vpn-up)
        # Bypassing VPN for Microsoft/Copilot
        GW=$(ip route | grep default | grep -v tun | awk '{print $3}' | head -n1)
        DEV=$(ip route | grep default | grep -v tun | awk '{print $5}' | head -n1)
        SUBNETS=("104.16.0.0/12" "172.64.0.0/13" "13.107.0.0/16" "150.171.0.0/16")
        
        if [ -n "$GW" ] && [ -n "$DEV" ]; then
            for net in "${SUBNETS[@]}"; do
                ip route add $net via $GW dev $DEV metric 5 2>/dev/null || \
                ip route replace $net via $GW dev $DEV metric 5
            done
        fi
        ;;
esac
EOD

# Hardcode the detected UUID into the dispatcher
sed -i "s/REPLACE_VPN_UUID/$VPN_UUID/" /etc/NetworkManager/dispatcher.d/99-vpn-manager
chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Step 8: Restarting Network Stack..."
systemctl restart NetworkManager
nmcli networking off && sleep 2 && nmcli networking on

echo "✅ CONFIGURATION COMPLETE FOR '$VPN_NAME'."
