#!/bin/bash

source ./funciones_ssh.sh
source ./funciones_utils.sh
source ./check_status_utils.sh
source ./DNS/inputs.sh

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

 menu_status() {
   echo "Menu para revision de estatus del sistema"
      echo "1-Revisar status del sistema"
         echo "2- observar script"
           echo "3- volver al menu principal"
}

menu_dns()
{
    echo "Menu para configuracion de DNS"
    echo "1- configurar DNS"
    echo "2- observar scripts"
    echo "3- volver al menu principal"
}

menu_config_dns()
{
    echo "Menu para configuracion de DNS"
    echo "1- inputs.sh"
    echo "2- interfaz.sh"
    echo "3- Configurar ip fija"
    echo "4- check_internet.sh"
    echo "5- instalar/reinstalar bind9"
    echo "6- configurar bind9"
    echo "7- validar configuracion"
    echo "Reinicio"
    echo "9- pruebas"
    echo "10- volver al menu principal"
}

menu_scripts_dns()
{
    echo "elige el script"
    echo "1- inputs.sh"

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
                        break
                        ;;
                esac
                read -p "presiona enter para continuar"
            done
            ;;
        4)
            sudo ./dhcp_setup.sh
            ;;
        5)
            while true
            do
                menu_dns
                read -p "Opcion: " C
                case $C in
                    1)
                        while true                        do
                            menu_config_dns
                            read -p "Opcion: " D
                            case $D in
                                1)
                                    inputs
                                    ;;
                               
                                2)
                                    valid_interfaz
                                    ;;
                                3)
                                    ipfija
                                    ;;
                                4)
                                   check_internet
                                    ;;
                                5)
                                   rein_bind
                                    ;;
                                6)
                                    config_bind
                                    ;;
                                7)
                                   validar
                                    ;;
                                8)
                                    reinicio
                                    ;;
                                9)
                                    pruebas
                                    ;;
                                10)
                                    echo "volviendo..."
                                    break
                                    ;;
                    2)
                        menu_scripts_dns
                        read -p "Opcion: " E
                        case $E in
                            1)
                                nano -v ./DNS/inputs.sh
                        ;;
                esac
                read -p "presiona enter para continuar"
            done
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