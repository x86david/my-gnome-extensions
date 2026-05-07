#!/bin/bash
set -e

# --- CONFIGURATION ---
VPN_SEARCH="${1:-david}"
DNS_PORT="9053"
SOCKS_PORT="9050"

REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")
DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run with sudo."
  exit 1
fi

echo "🔍 Step 1: Detecting VPN profile: '$VPN_SEARCH'..."
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: VPN profile containing '$VPN_SEARCH' not found."
    exit 1
fi
echo "✅ Detected: $VPN_NAME ($VPN_UUID)"

echo "🕵️  Step 2: Installing Tor & System Dependencies..."
apt update && apt install -y tor iptables-persistent dbus-x11

echo "⚙️  Step 3: Configuring Tor (DNS + SOCKS)..."
cat << EOT > /etc/tor/torrc
SocksPort 127.0.0.1:$SOCKS_PORT
DNSPort 127.0.0.1:$DNS_PORT
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
EOT
systemctl restart tor

echo "🛡️  Step 4: Hijacking System DNS (iptables Redirect)..."
iptables -t nat -F OUTPUT
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🔌 Step 5: Forcing GNOME System Proxy for $REAL_USER..."
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy.socks port $SOCKS_PORT
sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gsettings set org.gnome.system.proxy mode 'manual'

echo "⚙️  Step 6: Unlocking VPN profile (Global Autoconnect)..."
nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "📝 Step 7: Installing Clean Dispatcher (WiFi + Ethernet Auto-Link)..."
cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=$1
ACTION=$2
VPN_UUID="REPLACE_VPN_UUID"

case "$ACTION" in
    up)
        if [ -n "$CONNECTION_UUID" ]; then
            TYPE=$(nmcli -g connection.type connection show "$CONNECTION_UUID")

            # WiFi + Ethernet support
            if [ "$TYPE" = "802-11-wireless" ] || [ "$TYPE" = "802-3-ethernet" ]; then
                nmcli connection modify "$CONNECTION_UUID" connection.secondaries "$VPN_UUID"
            fi
        fi
        ;;
esac
EOD

sed -i "s/REPLACE_VPN_UUID/$VPN_UUID/" /etc/NetworkManager/dispatcher.d/99-vpn-manager
chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Step 8: Restarting Network Stack..."
systemctl restart NetworkManager
nmcli networking off && sleep 2 && nmcli networking on

echo "✅ CONFIGURATION COMPLETE FOR '$VPN_NAME'."
echo "🔒 Privacy mode: Tor DNS + Tor SOCKS + VPN + No bypasses."
