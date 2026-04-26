#!/bin/bash

echo "=== CONFIGURACION DNS LINUX (BIND9) ==="

# ================================
# 1. PEDIR DATOS SI NO VIENEN
# ================================
DOMINIO=$1
IP_SERVIDOR=$2
IP_CLIENTE=$3

if [ -z "$DOMINIO" ]; then
    read -p "Ingresa el dominio (ej: reprobados.com): " DOMINIO
fi

if [ -z "$IP_SERVIDOR" ]; then
    read -p "Ingresa la IP del servidor DNS: " IP_SERVIDOR
fi

if [ -z "$IP_CLIENTE" ]; then
    read -p "Ingresa la IP del cliente: " IP_CLIENTE
fi

ZONA_FILE="/var/cache/bind/db.$DOMINIO"

echo ""
echo "=== DATOS INGRESADOS ==="
echo "Dominio: $DOMINIO"
echo "Servidor: $IP_SERVIDOR"
echo "Cliente: $IP_CLIENTE"
echo ""

# ================================
# 2. VALIDAR IP FIJA
# ================================
IP_ACTUAL=$(hostname -I | awk '{print $1}')

if [ "$IP_ACTUAL" != "$IP_SERVIDOR" ]; then
    echo "[INFO] IP actual: $IP_ACTUAL"
    read -p "¿Deseas configurar IP fija a $IP_SERVIDOR? (s/n): " RESP

    if [ "$RESP" = "s" ]; then
        INTERFAZ=$(ip route | grep default | awk '{print $5}')

        echo "[INFO] Configurando IP estatica en $INTERFAZ..."

        sudo bash -c "cat > /etc/netplan/01-dns-config.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFAZ:
      addresses: [$IP_SERVIDOR/24]
EOF

        sudo netplan apply
        echo "[OK] IP configurada"
    fi
else
    echo "[OK] IP fija correcta"
fi

# ================================
# 3. INSTALACION (IDEMPOTENTE)
# ================================
if ! dpkg -l | grep -q bind9; then
    echo "[INFO] Instalando BIND9..."
    sudo apt update
    sudo apt install -y bind9 bind9utils bind9-doc
else
    echo "[OK] BIND9 ya instalado"
fi

# ================================
# 4. CONFIGURAR ZONA
# ================================
if ! grep -q "$DOMINIO" /etc/bind/named.conf.local; then
    echo "[INFO] Agregando zona..."

    sudo bash -c "cat >> /etc/bind/named.conf.local" <<EOF
zone "$DOMINIO" {
    type master;
    file "$ZONA_FILE";
};
EOF
else
    echo "[OK] Zona ya existe"
fi

# ================================
# 5. CREAR ARCHIVO DE ZONA
# ================================
if [ ! -f "$ZONA_FILE" ]; then
    echo "[INFO] Creando archivo de zona..."

    sudo bash -c "cat > $ZONA_FILE" <<EOF
\$TTL 604800
@   IN  SOA ns.$DOMINIO. admin.$DOMINIO. (
        1
        604800
        86400
        2419200
        604800 )

@       IN  NS      ns.$DOMINIO.
ns      IN  A       $IP_SERVIDOR

@       IN  A       $IP_CLIENTE
www     IN  CNAME   $DOMINIO.
EOF
else
    echo "[OK] Archivo de zona ya existe"
fi

# ================================
# 6. VALIDACION
# ================================
echo "[INFO] Validando configuracion..."

sudo named-checkconf || { echo "[ERROR] Configuracion incorrecta"; exit 1; }
sudo named-checkzone $DOMINIO $ZONA_FILE || { echo "[ERROR] Zona incorrecta"; exit 1; }

echo "[OK] Configuracion valida"

# ================================
# 7. REINICIAR SERVICIO
# ================================
sudo systemctl restart bind9

# ================================
# 8. PRUEBAS
# ================================
echo ""
echo "=== PRUEBAS ==="

echo "nslookup:"
nslookup $DOMINIO localhost

echo ""
echo "ping:"
ping -c 2 www.$DOMINIO

echo ""
echo "=== FINALIZADO ==="