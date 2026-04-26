#!/bin/bash

echo "=== DNS AUTOMATICO LINUX (BIND9) ==="

# ================================
# 1. INPUTS
# ================================
DOMINIO=$1
IP_SERVIDOR=$2
IP_CLIENTE=$3
INTERFAZ="ens33"

if [ -z "$DOMINIO" ]; then
    read -p "Dominio (ej: reprobados.com): " DOMINIO
fi

if [ -z "$IP_SERVIDOR" ]; then
    read -p "IP del servidor DNS: " IP_SERVIDOR
fi

if [ -z "$IP_CLIENTE" ]; then
    read -p "IP del cliente: " IP_CLIENTE
fi

ZONA_FILE="/var/cache/bind/db.$DOMINIO"

echo ""
echo "Dominio: $DOMINIO"
echo "Servidor DNS: $IP_SERVIDOR"
echo "Cliente: $IP_CLIENTE"
echo "Interfaz usada: $INTERFAZ"
echo ""

# ================================
# 2. VALIDAR INTERFAZ
# ================================
IP_ACTUAL=$(ip -4 addr show $INTERFAZ | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_ACTUAL" ]; then
    echo "[ERROR] La interfaz $INTERFAZ no tiene IP"
    exit 1
fi

echo "[OK] $INTERFAZ → $IP_ACTUAL"

# ================================
# 3. FORZAR IP EN ENS33
# ================================
if [ "$IP_ACTUAL" != "$IP_SERVIDOR" ]; then
    read -p "Configurar IP fija $IP_SERVIDOR en $INTERFAZ? (s/n): " RESP

    if [ "$RESP" = "s" ]; then
        sudo bash -c "cat > /etc/netplan/01-dns.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFAZ:
      dhcp4: false
      addresses:
        - $IP_SERVIDOR/24
EOF

        sudo netplan apply
        echo "[OK] IP configurada. Reinicia si hay problemas."
    fi
fi

# ================================
# 4. REINSTALAR BIND9
# ================================
echo "[INFO] Reinstalando BIND9..."

sudo systemctl stop bind9 2>/dev/null
sudo apt purge -y bind9 bind9utils bind9-doc 2>/dev/null
sudo apt autoremove -y

sudo apt update
sudo apt install -y bind9 bind9utils bind9-doc

# ================================
# 5. CONFIGURAR BIND
# ================================
echo "[INFO] Configurando BIND..."

# Forzar escucha en IP correcta
sudo bash -c "cat > /etc/bind/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";

    listen-on { $IP_SERVIDOR; };
    listen-on-v6 { none; };

    allow-query { any; };
    recursion yes;
};
EOF

# Zona
sudo bash -c "cat > /etc/bind/named.conf.local" <<EOF
zone "$DOMINIO" {
    type master;
    file "$ZONA_FILE";
};
EOF

# Archivo de zona
sudo bash -c "cat > $ZONA_FILE" <<EOF
\$TTL 604800
@   IN  SOA ns.$DOMINIO. admin.$DOMINIO. (
        2
        604800
        86400
        2419200
        604800 )

@       IN  NS      ns.$DOMINIO.
ns      IN  A       $IP_SERVIDOR

@       IN  A       $IP_CLIENTE
www     IN  CNAME   $DOMINIO.
EOF

# ================================
# 6. VALIDACION
# ================================
echo "[INFO] Validando..."

sudo named-checkconf || { echo "[ERROR] Configuracion incorrecta"; exit 1; }
sudo named-checkzone $DOMINIO $ZONA_FILE || { echo "[ERROR] Zona incorrecta"; exit 1; }

echo "[OK] Configuracion valida"

# ================================
# 7. REINICIAR
# ================================
sudo systemctl restart bind9
sudo systemctl enable bind9

# ================================
# 8. PRUEBAS
# ================================
echo ""
echo "=== PRUEBAS ==="

echo "[TEST] Estado del servicio:"
sudo systemctl status bind9 | grep Active

echo ""
echo "[TEST] Puerto 53:"
sudo ss -tulnp | grep :53

echo ""
echo "[TEST] DNS (dig):"
dig @$IP_SERVIDOR $DOMINIO +short
dig @$IP_SERVIDOR www.$DOMINIO +short

echo ""
echo "[TEST] Ping:"
ping -c 2 $IP_CLIENTE

echo ""
echo "=== FINALIZADO ==="