#!/bin/bash

echo "=== DNS AUTOMATICO LINUX (BIND9) ==="

# ================================
# 1. INPUTS
# ================================
DOMINIO=$1
IP_SERVIDOR=$2
IP_CLIENTE=$3

INTERFAZ_DNS="ens34"   # Host-Only (DNS)
INTERFAZ_NET="ens33"   # NAT (internet)

if [ -z "$DOMINIO" ]; then
    read -p "Dominio (ej: reprobados.com): " DOMINIO
fi

if [ -z "$IP_SERVIDOR" ]; then
    read -p "IP del servidor DNS (ens34): " IP_SERVIDOR
fi

if [ -z "$IP_CLIENTE" ]; then
    read -p "IP del cliente: " IP_CLIENTE
fi

ZONA_FILE="/var/cache/bind/db.$DOMINIO"

echo ""
echo "Dominio: $DOMINIO"
echo "Servidor DNS: $IP_SERVIDOR"
echo "Cliente: $IP_CLIENTE"
echo "Interfaz DNS: $INTERFAZ_DNS"
echo "Interfaz Internet: $INTERFAZ_NET"
echo ""

# ================================
# 2. VALIDAR INTERFAZ DNS (ens34)
# ================================
IP_ACTUAL=$(ip -4 addr show $INTERFAZ_DNS | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_ACTUAL" ]; then
    echo "[ERROR] $INTERFAZ_DNS no tiene IP"
    exit 1
fi

echo "[OK] $INTERFAZ_DNS → $IP_ACTUAL"

# ================================
# 3. CONFIGURAR IP FIJA EN ENS34
# ================================
if [ "$IP_ACTUAL" != "$IP_SERVIDOR" ]; then
    read -p "Configurar IP fija $IP_SERVIDOR en $INTERFAZ_DNS? (s/n): " RESP

    if [ "$RESP" = "s" ]; then
        sudo bash -c "cat > /etc/netplan/01-dns.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFAZ_DNS:
      dhcp4: false
      addresses:
        - $IP_SERVIDOR/24
    $INTERFAZ_NET:
      dhcp4: true
EOF
        sudo netplan apply
        echo "[OK] IP configurada en $INTERFAZ_DNS"
    fi
fi

# ================================
# 4. CHECK INTERNET (para instalar)
# ================================
echo "[INFO] Verificando internet..."
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "[OK] Internet disponible (via $INTERFAZ_NET)"
    INSTALAR=1
else
    echo "[WARN] Sin internet. No se instalará BIND, solo se configurará."
    INSTALAR=0
fi

# ================================
# 5. INSTALAR/REINSTALAR BIND9
# ================================
if [ $INSTALAR -eq 1 ]; then
    echo "[INFO] Instalando/Reinstalando BIND9..."
    sudo systemctl stop bind9 2>/dev/null
    sudo apt purge -y bind9 bind9utils bind9-doc 2>/dev/null
    sudo apt autoremove -y
    sudo apt update
    sudo apt install -y bind9 bind9utils bind9-doc
else
    echo "[INFO] Saltando instalación de BIND9"
fi

# ================================
# 6. CONFIGURAR BIND (forzar ens34)
# ================================
echo "[INFO] Configurando BIND..."

sudo bash -c "cat > /etc/bind/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";

    listen-on { $IP_SERVIDOR; };
    listen-on-v6 { none; };

    allow-query { any; };
    recursion yes;
};
EOF

sudo bash -c "cat > /etc/bind/named.conf.local" <<EOF
zone "$DOMINIO" {
    type master;
    file "$ZONA_FILE";
};
EOF

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
# 7. VALIDACION
# ================================
echo "[INFO] Validando..."

sudo named-checkconf || { echo "[ERROR] Config incorrecta"; exit 1; }
sudo named-checkzone $DOMINIO $ZONA_FILE || { echo "[ERROR] Zona incorrecta"; exit 1; }

echo "[OK] Configuración válida"

# ================================
# 8. REINICIAR
# ================================
sudo systemctl restart bind9
sudo systemctl enable bind9

# ================================
# 9. PRUEBAS
# ================================
echo ""
echo "=== PRUEBAS ==="

echo "[TEST] Servicio:"
sudo systemctl status bind9 | grep Active

echo "[TEST] Puerto 53 (debe mostrar $IP_SERVIDOR:53):"
sudo ss -tulnp | grep :53

echo "[TEST] DNS:"
dig @$IP_SERVIDOR $DOMINIO +short
dig @$IP_SERVIDOR www.$DOMINIO +short

echo "[TEST] Ping cliente:"
ping -c 2 $IP_CLIENTE

echo ""
echo "=== FINALIZADO ==="