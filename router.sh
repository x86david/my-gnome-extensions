#!/bin/bash

echo "🕵️  Paso 1: Instalando Tor..."
sudo apt update && sudo apt install -y tor

echo "⚙️  Paso 2: Configurando Tor (DNSPort 9053)..."
# Aseguramos que Tor escuche para DNS
sudo bash -c "cat << 'EOF' > /etc/tor/torrc
SocksPort 127.0.0.1:9050
DNSPort 127.0.0.1:9053
EOF"
sudo systemctl restart tor

echo "🛡️  Paso 3: Configurando iptables (Redirección DNS)..."
# Redirigir cualquier tráfico DNS saliente (puerto 53) hacia el puerto 9053 de Tor
sudo iptables -t nat -F OUTPUT  # Limpiar reglas previas de OUTPUT nat
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 9053

# Hacer las reglas de iptables persistentes
sudo apt install -y iptables-persistent
sudo sh -c "iptables-save > /etc/iptables/rules.v4"

echo "🌐 Paso 4: Forzando DNS Global en NetworkManager..."
# Configuramos NM para que siempre pregunte a una IP (que interceptará iptables)
sudo bash -c "cat << 'EOF' > /etc/NetworkManager/conf.d/99-global-dns.conf
[main]
dns=default

[global-dns-domain-*]
servers=1.1.1.1
EOF"

echo "🔄 Paso 5: Reiniciando servicios..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ SISTEMA DE PRIVACIDAD COMPLETADO."
echo "Todo el DNS del sistema ahora sale por Tor (vía iptables)."
