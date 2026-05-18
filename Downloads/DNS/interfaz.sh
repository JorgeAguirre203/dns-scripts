#!/bin/bash
valid_interfaz(){
IP_ACTUAL=$(ip -4 addr show $INTERFAZ_DNS | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_ACTUAL" ]; then
    echo "[ERROR] $INTERFAZ_DNS no tiene IP"
    exit 1
fi

echo "[OK] $INTERFAZ_DNS → $IP_ACTUAL"
}