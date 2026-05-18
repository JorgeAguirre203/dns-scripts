#!/bin/bash

#1. Instalacion idempotente

if ! dpkg -l | grep -q isc-dhcp-server; then
    echo "instalando isc-dhcp-server..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get install -y isc-dhcp-server
else
    echo "isc-dhcp-server ya esta instalado."
fi

#2. Validaciones
validar_ip(){
    local ip=$1
    if [[ $ip =~ ^192\.168\.100\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r a b c d <<< "$ip"
        if ((d >= 0 && d <= 255)); then
            return 0
        fi
    fi
    return 1
}

validar_rango() {
    local ini=$1
    local fin=$2

    ini_oct=$(echo $ini | cut -d '.' -f4)
    fin_oct=$(echo $fin | cut -d '.' -f4)

    if ((ini_oct >= 50 && fin_oct <= 150 && ini_oct < fin_oct)); then
        return 0
    else
        return 1
    fi
}

#3. orquestacion dinamica
read -p "Nombre del Ambito (Scope): " SCOPE
read -p "Interfaz de red (ej. ens34): " IFACE

#rango de ips
until validar_ip "$IP_INI"; do
    read -p "IP Inicial (192.168.100.50 - 192.168.100.150): " IP_INI
done

until validar_ip "$IP_FIN"; do
    read -p "IP Final (192.168.100.50 - 192.168.100.150): " IP_FIN
done

until validar_rango "$IP_INI" "$IP_FIN"; do
    echo "Rango invalido. Debe estar entre .50 y .150 y ser logico."
    read -p "IP Inicial: " IP_INI
    read -p "IP Final: " IP_FIN
done

#gateway fijo segun requerimiento
GATEWAY="192.168.100.1"

# DNS (puedes cambiar si quieres validar mas )
read -p "DNS (ej. 192.168.100.10): " DNS

# Lease
read -p "Tiempo de concesion (segundos): " LEASE

#Configuracion de dhcp...

echo "Configurando DHCP..."

#Interfaz
sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server

#archivo de configuracion
cat <<EOF > /etc/dhcp/dhcpd.conf
#configuracion dhcp - $SCOPE

authoritative;
default-lease-time $LEASE;
max-lease-time 7200;

subnet 192.168.100.0 netmask 255.255.255.0 {
    range $IP_INI $IP_FIN;
    option routers $GATEWAY;
    option domain-name-servers $DNS;
    option subnet-mask 255.255.255.0;
}
EOF

# REINICIAR SERVICIO

systemctl restart isc-dhcp-server

#5. Monitoreo y diagnostico

echo -e "\n========= estado del servicio ======"
systemctl is-active isc-dhcp-server

echo -e "\n==== concesiones activas ===="
awk '/lease/ {ip=$2} /client-hostname/ {print "IP:", ip, "| Host:", $2}' /var/lib/dhcp/dhcpd.leases | tail -n 5