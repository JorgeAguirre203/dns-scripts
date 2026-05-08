#!/bin/bash

// Este script es el punto de entrada para la administración del servidor


source ./funciones_utils.sh
source ./funciones_ssh.sh

menu() {
    clear
    echo "==============================="
    echo "   ADMINISTRACIÓN DE SERVIDOR"
    echo "==============================="
    echo "1) Instalar y configurar SSH"
    echo "2) Verificar estado SSH"
    echo "3) Salir"
    echo "==============================="
}

while true; do
    menu
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1)
            instalar_configurar_ssh
            ;;
        2)
            verificar_ssh
            ;;
        3)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac

    read -p "Presiona Enter para continuar..."
done