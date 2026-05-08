#!/bin/bash
# configure-proxy.sh
set -e

echo "🕵️  Installing Tor and Iptables Persistence..."
apt install -y tor iptables-persistent

echo "⚙️  Configuring Torrc..."
cat << 'EOF' > /etc/tor/torrc
SocksPort 127.0.0.1:9050
DNSPort 127.0.0.1:9053
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
EOF
systemctl restart tor

echo "🛡️  Applying DNS Hijacking (Redirect 53 -> 9053)..."
iptables -t nat -F OUTPUT
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053
iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 9053
sh -c "iptables-save > /etc/iptables/rules.v4"

echo "✅ Proxy and DNS hardening applied."
