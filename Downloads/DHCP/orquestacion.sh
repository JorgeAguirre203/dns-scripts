#!/bin/bash
# lib/orquestacion.sh

recopilar_parametros() {
    read -p "Nombre del Ambito (Scope): " SCOPE
    read -p "Interfaz de red (ej. ens34): " IFACE

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

    GATEWAY="192.168.100.1"
    read -p "DNS (ej. 192.168.100.10): " DNS
    read -p "Tiempo de concesion (segundos): " LEASE

    # Exportar para que el script principal las vea
    export SCOPE IFACE IP_INI IP_FIN GATEWAY DNS LEASE
}