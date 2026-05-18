inputs() {
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
}