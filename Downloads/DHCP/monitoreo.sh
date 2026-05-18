#!/bin/bash
# lib/monitoreo.sh

mostrar_estado() {
    echo -e "\n========= estado del servicio ======"
    systemctl is-active isc-dhcp-server

    echo -e "\n==== concesiones activas ===="
    awk '/lease/ {ip=$2} /client-hostname/ {print "IP:", ip, "| Host:", $2}' \
        /var/lib/dhcp/dhcpd.leases | tail -n 5
}