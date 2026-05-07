#!/bin/bash

verificar_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Este script debe ejecutarse como root"
        exit 1
    fi
}

verificar_conexion() {
    ping -c 1 google.com > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ No hay conexión a internet"
        exit 1
    fi
}

instalar_paquete() {
    paquete=$1
    dpkg -s $paquete &> /dev/null

    if [ $? -ne 0 ]; then
        echo "📦 Instalando $paquete..."
        apt update
        apt install -y $paquete
    else
        echo "✔ $paquete ya está instalado"
    fi
}

validar_servicio() {
    servicio=$1
    systemctl is-active --quiet $servicio

    if [ $? -eq 0 ]; then
        echo "✔ Servicio $servicio activo"
    else
        echo "❌ Servicio $servicio NO activo"
    fi
}