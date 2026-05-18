#!/bin/bash

source ./funciones_ssh.sh
source ./funciones_utils.sh
source ./check_status_utils.sh
source ./DNS/inputs.sh
source ./DNS/bind.sh
source ./DNS/configbind.sh
source ./DNS/confip.sh
source ./DNS/interfaz.sh
source ./DNS/internet.sh
source ./DNS/reinicio.sh
source ./DNS/test.sh
source ./DNS/validar.sh
source ./DHCP/instalacion.sh
source ./DHCP/validaciones.sh
source ./DHCP/orquestacion.sh
source ./DHCP/configuracion.sh
source ./DHCP/monitoreo.sh


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

menu_dhcp() {
    echo "Menu para configuracion de DHCP"
    echo "1- Configurar DHCP"
    echo "2- Observar scripts"
    echo "3- Volver al menu principal"
}

menu_config_dhcp() {
    echo "Menu para configuracion de DHCP"
    echo "1- Instalar isc-dhcp-server"
    echo "2- Ingresar parametros"
    echo "3- Aplicar configuracion"
    echo "4- Reiniciar servicio"
    echo "5- Ver estado y concesiones"
    echo "6- Volver al menu principal"
}

menu_scripts_dhcp() {
    echo "Elige el script"
    echo "1- instalacion.sh"
    echo "2- validaciones.sh"
    echo "3- orquestacion.sh"
    echo "4- configuracion.sh"
    echo "5- monitoreo.sh"
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
            while true; do
                menu_dhcp
                read -p "Opcion: " F

                case $F in
                    1)
                        while true; do
                            menu_config_dhcp
                            read -p "Opcion: " G

                            case $G in
                                1)
                                    instalar_dhcp
                                    ;;
                                2)
                                    recopilar_parametros
                                    ;;
                                3)
                                    configurar_dhcp
                                    ;;
                                4)
                                    reiniciar_servicio
                                    ;;
                                5)
                                    mostrar_estado
                                    ;;
                                6)
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
                        menu_scripts_dhcp
                        read -p "Opcion: " H

                        case $H in
                            1)
                                nano -v ./DHCP/lib/instalacion.sh
                                ;;
                            2)
                                nano -v ./DHCP/lib/validaciones.sh
                                ;;
                            3)
                                nano -v ./DHCP/lib/orquestacion.sh
                                ;;
                            4)
                                nano -v ./DHCP/lib/configuracion.sh
                                ;;
                            5)
                                nano -v ./DHCP/lib/monitoreo.sh
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