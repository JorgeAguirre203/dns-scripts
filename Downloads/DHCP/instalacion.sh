#!/bin/bash
# lib/instalacion.sh

instalar_dhcp() {
    if ! dpkg -l | grep -q isc-dhcp-server; then
        echo "instalando isc-dhcp-server..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y && apt-get install -y isc-dhcp-server
    else
        echo "isc-dhcp-server ya esta instalado."
    fi
}