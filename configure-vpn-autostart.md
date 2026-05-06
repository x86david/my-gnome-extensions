# 📝 README — Autostart de una VPN de GNOME/NetworkManager en Linux

Este README explica cómo hacer que una VPN creada desde la interfaz de GNOME se conecte automáticamente al iniciar sesión o al conectarse a una red WiFi.  
GNOME no ofrece esta opción en la UI, pero NetworkManager sí la soporta.

---

## 🎯 Objetivo

Conseguir que una VPN creada desde *Configuración → Red → VPN* se conecte automáticamente cuando se active tu conexión principal (WiFi o Ethernet).

---

## 🧩 Problema

NetworkManager **no autoconecta perfiles VPN por sí solos**, incluso si tienen:

```
autoconnect=true
```

Además, si el perfil VPN tiene:

```
permissions=user:usuario:;
```

→ **el autoconnect queda bloqueado**.

Por eso GNOME no inicia la VPN automáticamente.

---

## ✅ Solución completa (2 pasos obligatorios)

### 1. Corregir el perfil VPN

Editar el archivo del perfil VPN:

```
sudo nano /etc/NetworkManager/system-connections/<vpn>.nmconnection
```

En la sección `[connection]`:

- Eliminar cualquier línea `permissions=...`
- Asegurar que existe:

```
autoconnect=true
```

Guardar y aplicar permisos:

```
sudo chmod 600 /etc/NetworkManager/system-connections/<vpn>.nmconnection
sudo systemctl restart NetworkManager
```

---

### 2. Asociar la VPN a tu conexión principal (WiFi/Ethernet)

NetworkManager solo autoconecta VPNs cuando están definidas como *secondary* de una conexión principal.

Obtener los UUID:

```
nmcli connection show
```

Asignar la VPN como secundaria:

```
sudo nmcli connection modify <conexion_principal> connection.secondaries <UUID_VPN>
```

Ejemplo:

```
sudo nmcli connection modify klone445 connection.secondaries 328be044-adaa-4e64-b065-783706224456
```

Reiniciar NetworkManager:

```
sudo systemctl restart NetworkManager
```

---

## 🔥 Prueba rápida

Desconectar y reconectar la WiFi:

```
nmcli device disconnect wlp2s0
nmcli device connect wlp2s0
```

Comprobar conexiones activas:

```
nmcli connection show --active
```

Deberías ver:

```
klone445   wifi
david      vpn
```

---

## 🧠 Notas

- No es necesario usar `openvpn-client@.service` de systemd.  
- GNOME no muestra la opción de autostart, pero NetworkManager sí la soporta.  
- La VPN solo se autoconectará cuando la conexión principal se active automáticamente (`autoconnect=yes`).  
