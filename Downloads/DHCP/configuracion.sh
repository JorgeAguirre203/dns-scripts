#!/bin/bash
# lib/configuracion.sh

configurar_dhcp() {
    echo "Configurando DHCP..."

    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server

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
}

reiniciar_servicio() {
    systemctl restart isc-dhcp-server
}