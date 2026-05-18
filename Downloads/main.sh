#!/bin/bash

source ./funciones_ssh.sh
source ./funciones_utils.sh
source ./check_status_utils.sh
source ./DNS/inputs.sh

menu() {
    clear
    echo "========================"
    echo "Administracion de servidor"
    echo "========================"
    echo "1- Instalar y configurar SSH"
    echo "2- Verificar estado SSH"
    echo "3- Verificar estado del sistema"
    echo "4- Crear DHCP"
    echo "5- Crear DNS"
    echo "6- Salir"
    echo "========================"
}

menu_status() {
    echo "Menu para revision de estatus del sistema"
    echo "1- Revisar status del sistema"
    echo "2- Observar script"
    echo "3- Volver al menu principal"
}

menu_dns() {
    echo "Menu para configuracion de DNS"
    echo "1- Configurar DNS"
    echo "2- Observar scripts"
    echo "3- Volver al menu principal"
}

menu_config_dns() {
    echo "Menu para configuracion de DNS"
    echo "1- inputs.sh"
    echo "2- interfaz.sh"
    echo "3- Configurar IP fija"
    echo "4- check_internet.sh"
    echo "5- Instalar/reinstalar bind9"
    echo "6- Configurar bind9"
    echo "7- Validar configuracion"
    echo "8- Reinicio"
    echo "9- Pruebas"
    echo "10- Volver al menu principal"
}

menu_scripts_dns() {
    echo "Elige el script"
    echo "1- inputs.sh"
}

while true; do
    menu
    read -p "Selecciona una opcion: " A

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
                        echo "Volviendo..."
                        break
                        ;;
                    *)
                        echo "Opcion invalida"
                        ;;
                esac

                read -p "Presiona ENTER para continuar"
            done
            ;;
        4)
            sudo ./dhcp_setup.sh
            ;;
        5)
            while true; do
                menu_dns
                read -p "Opcion: " C

                case $C in
                    1)
                        while true; do
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
                                    echo "Volviendo..."
                                    break
                                    ;;
                                *)
                                    echo "Opcion invalida"
                                    ;;
                            esac

                            read -p "Presiona ENTER para continuar"
                        done
                        ;;

                    2)
                        menu_scripts_dns
                        read -p "Opcion: " E

                        case $E in
                            1)
                                nano -v ./DNS/inputs.sh
                                ;;
                            *)
                                echo "Opcion invalida"
                                ;;
                        esac
                        ;;

                    3)
                        echo "Volviendo..."
                        break
                        ;;

                    *)
                        echo "Opcion invalida"
                        ;;
                esac

                read -p "Presiona ENTER para continuar"
            done
            ;;
        6)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opcion invalida"
            ;;
    esac

    read -p "Presiona ENTER para continuar"
done