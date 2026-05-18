#!/bin/bash

source ./funciones_ssh.sh
source ./funciones_utils.sh
source ./check_status_utils.sh

menu() {
    clear
    echo "========"
    echo "administracion de servidor"
    echo "================="
    echo "1-instalar y configurarr ssh"
    echo "2- verificar estado ssh"
    echo "3- verificar estado del sistema"
    echo "4- Crear DHCP"
    echo "5- Crear DNS"
    echo "6- salir"
    echo "================="
}

while true; do
    menu
    read -p "selecciona una opcion: " A

    case $A in
        1)
            instalar_configurar_ssh
            ;;
        2)
            verificar_ssh
            ;;
        3)
            menu_status() {
                echo "Menu para revision de estatus del sistema"
                echo "1-Revisar status del sistema"
                echo "2- observar script"
                echo "3- volver al menu principal"
            }
            while true; do
                menu_status
                read -p "Opcion: " B
                case $B in
                    1)
                        validar_status
                        ;;
                    2)
                        nano -v ./check_status.sh
                        nano -v ./check_status_utils.sh
                        ;;
                    3)
                        echo "volviendo..."
                        break # 'break' te saca de este sub-menú y te regresa al principal
                        ;;
                esac
                read -p "presiona enter para continuar"
            done
            ;;
        4)
            sudo ./dhcp_setup.sh
            ;;
        5)
            sudo ./dns-scripts.sh
            ;;
        6)
            echo "Saliendo"
            exit 0
            ;;
        *)
            echo "opcion invalida"
            ;;
    esac
    read -p "presiona enter para continuar"
done