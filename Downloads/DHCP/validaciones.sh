#!/bin/bash
# lib/validaciones.sh

validar_ip() {
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