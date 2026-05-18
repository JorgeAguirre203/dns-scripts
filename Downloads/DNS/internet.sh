#!/bin/bash
check_internet(){
echo "[INFO] Verificando internet..."
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "[OK] Internet disponible (via $INTERFAZ_NET)"
    INSTALAR=1
else
    echo "[WARN] Sin internet. No se instalará BIND, solo se configurará."
    INSTALAR=0
fi
}