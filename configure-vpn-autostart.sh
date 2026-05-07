# 1. Crear el Script Maestro Automatizado (Versión corregida)
cat << 'EOF' > fix_vpn_final.sh
#!/bin/bash

# Configuración: Nombre base
VPN_SEARCH="david"

echo "🔍 Paso 0: Detectando UUID de la VPN..."
# Buscamos el UUID filtrando por el nombre que contenga "david"
VPN_UUID=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f2)
VPN_NAME=$(nmcli -g NAME,UUID connection show | grep -i "$VPN_SEARCH" | head -n1 | cut -d: -f1)

if [ -z "$VPN_UUID" ]; then
    echo "❌ Error: No se encontró ninguna conexión que contenga '$VPN_SEARCH'."
    echo "Usa 'nmcli connection show' para ver cómo se llama exactamente tu VPN."
    exit 1
fi

echo "✅ VPN detectada: $VPN_NAME"
echo "✅ UUID detectado: $VPN_UUID"

echo "⚙️  Paso 1: Desbloqueando perfil VPN '$VPN_NAME'..."
sudo nmcli connection modify "$VPN_NAME" connection.permissions "" connection.autoconnect yes

echo "🔗 Paso 2: Vinculando todas las redes WiFi a esta VPN..."
WIFI_CONNS=$(nmcli --terse --fields NAME,TYPE connection show | grep :802-11-wireless | cut -d: -f1)
while read -r conn; do
    if [ -n "$conn" ]; then
        echo "   -> Vinculando: $conn"
        sudo nmcli connection modify "$conn" connection.secondaries "$VPN_UUID" 2>/dev/null
    fi
done <<< "$WIFI_CONNS"

echo "📝 Paso 3: Creando Dispatcher Inteligente (Rutas Dinámicas)..."
sudo bash -c "cat << 'EOD' > /etc/NetworkManager/dispatcher.d/99-vpn-manager
#!/bin/bash
INTERFACE=\$1
ACTION=\$2

if [ \"\$ACTION\" = \"vpn-up\" ]; then
    # DETECCIÓN DINÁMICA DE GW Y DEV
    GW=\$(ip route | grep default | grep -v tun | awk '{print \$3}' | head -n1)
    DEV=\$(ip route | grep default | grep -v tun | awk '{print \$5}' | head -n1)
    
    SUBNETS=(\"104.16.0.0/12\" \"172.64.0.0/13\" \"13.107.0.0/16\" \"150.171.0.0/16\")
    
    if [ -n \"\$GW\" ] && [ -n \"\$DEV\" ]; then
        for net in \"\${SUBNETS[@]}\"; do
            ip route add \$net via \$GW dev \$DEV metric 5 2>/dev/null || \\
            ip route replace \$net via \$GW dev \$DEV metric 5
        done
    fi
fi
EOD"

sudo chmod +x /etc/NetworkManager/dispatcher.d/99-vpn-manager

echo "🔄 Paso 4: Reiniciando red para aplicar cambios..."
sudo systemctl restart NetworkManager
sudo nmcli networking off && sleep 2 && sudo nmcli networking on

echo "✅ CONFIGURACIÓN MAESTRA COMPLETADA."
EOF

# 2. Ejecutar el script
chmod +x fix_vpn_final.sh
./fix_vpn_final.sh
