#!/bin/bash
rein_bind(){
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
}