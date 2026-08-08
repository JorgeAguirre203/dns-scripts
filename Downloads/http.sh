#!/bin/bash
# ==========================================
# TAREA 6: FUNCIONES DE DESPLIEGUE HTTP (DEBIAN/UBUNTU)
# ==========================================

# Variables de color
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Validar ejecución como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}[ERROR] Este script debe ser ejecutado con privilegios de superusuario (root).${RESET}"
   exit 1
fi

# ==========================================
# MÓDULOS DE VALIDACIÓN Y SEGURIDAD
# ==========================================

# --- VERIFICACIÓN GLOBAL ---
verificar_http() {
    echo -e "\n${CYAN}=== ESTADO DE LOS SERVICIOS HTTP ===${RESET}"
    for servicio in apache2 nginx tomcat; do
        if systemctl is-active --quiet "$servicio"; then
            echo -e "${VERDE}[✓] $servicio está INSTALADO y EN EJECUCIÓN.${RESET}"
        else
            echo -e "${ROJO}[X] $servicio NO está en ejecución o no está instalado.${RESET}"
        fi
    done
    echo -e "\n${CYAN}=== PUERTOS A LA ESCUCHA (HTTP) ===${RESET}"
    ss -tuln | grep -E ':(80|443|8080|8888) ' || echo "No hay puertos HTTP comunes en uso."
    echo ""
}

# --- VALIDAR PUERTO ---
validar_puerto_ingresado() {
    local puerto=$1
    # Validar que no sea nulo y contenga solo números
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ -z "$puerto" ]; then
        echo -e "${ROJO}[ERROR] El puerto debe ser un número válido.${RESET}"
        return 1
    fi
    # Restringir puertos reservados
    if [ "$puerto" -lt 1024 ] && [ "$puerto" -ne 80 ] && [ "$puerto" -ne 443 ]; then
        echo -e "${ROJO}[ERROR] El puerto $puerto es un puerto reservado del sistema. Use 80, 443 o mayores a 1024.${RESET}"
        return 1
    fi
    # Validar que no esté ocupado
    if ss -tuln | grep -q ":$puerto "; then
        echo -e "${ROJO}[ERROR] El puerto $puerto ya está ocupado por otro servicio.${RESET}"
        return 1
    fi
    return 0
}

# --- AUTOMATIZACIÓN DE FIREWALL ---
configurar_firewall() {
    local puerto=$1
    echo -e "${AMARILLO}Configurando Firewall (UFW) para permitir el puerto $puerto...${RESET}"
    apt-get install -y -q ufw > /dev/null 2>&1
    ufw allow "$puerto/tcp" > /dev/null 2>&1
    
    # Cerrar puertos por defecto si no están en uso por el puerto seleccionado
    if [ "$puerto" != "80" ]; then ufw deny 80/tcp > /dev/null 2>&1; fi
    if [ "$puerto" != "8080" ]; then ufw deny 8080/tcp > /dev/null 2>&1; fi
    
    ufw --force enable > /dev/null 2>&1
}

# ==========================================
# FUNCIONES DE DESPLIEGUE HTTP
# ==========================================

# --- 1. DESPLIEGUE DE APACHE2 ---
menu_instalar_apache() {
    echo -e "\n${CYAN}--- DESPLIEGUE DE APACHE2 ---${RESET}"
    echo "Consultando versiones disponibles en repositorios..."
    apt-cache madison apache2 | awk '{print $3}' | head -n 3
    
    echo ""
    read -p "Ingrese la versión exacta (o deje en blanco para la Latest): " version
    read -p "Ingrese el puerto de escucha (ej. 80, 8080): " puerto

    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Iniciando instalación silenciosa...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    if [ -z "$version" ]; then
        apt-get install -y -q apache2 > /dev/null 2>&1
        VER_MOSTRAR="Latest"
    else
        apt-get install -y -q apache2="$version" > /dev/null 2>&1
        VER_MOSTRAR="$version"
    fi

    echo -e "${AMARILLO}Configurando puerto $puerto y seguridad (Headers, ServerTokens)...${RESET}"
    sed -i "s/Listen [0-9]*/Listen $puerto/g" /etc/apache2/ports.conf

    # Seguridad: Ocultar versión y agregar headers
    sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-available/security.conf
    sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-available/security.conf
    echo "TraceEnable Off" >> /etc/apache2/apache2.conf
    
    a2enmod headers > /dev/null 2>&1
    echo "Header always append X-Frame-Options SAMEORIGIN" >> /etc/apache2/apache2.conf
    echo "Header always append X-Content-Type-Options nosniff" >> /etc/apache2/apache2.conf

    # Seguridad: Bloquear métodos peligrosos
    cat <<EOF > /etc/apache2/conf-available/metodos.conf
<Directory /var/www/html>
    <LimitExcept GET POST HEAD OPTIONS>
        Require all denied
    </LimitExcept>
</Directory>
EOF
    a2enconf metodos > /dev/null 2>&1

    echo -e "${AMARILLO}Ajustando permisos y aislando directorio con usuario dedicado...${RESET}"
    id -u webadmin_apache &>/dev/null || useradd -r -s /usr/sbin/nologin webadmin_apache
    chown -R webadmin_apache:www-data /var/www/html
    chmod -R 750 /var/www/html

    echo "<h1>Servidor: Apache2 - Versión: $VER_MOSTRAR - Puerto: $puerto</h1>" > /var/www/html/index.html
    
    configurar_firewall "$puerto"
    systemctl restart apache2
    echo -e "${VERDE}[✓] Apache configurado de forma segura y exitosa en el puerto $puerto.${RESET}"
    sleep 2
}

# --- 2. DESPLIEGUE DE NGINX ---
menu_instalar_nginx() {
    echo -e "\n${CYAN}--- DESPLIEGUE DE NGINX ---${RESET}"
    echo "Consultando versiones disponibles en repositorios..."
    apt-cache madison nginx | awk '{print $3}' | head -n 3
    
    echo ""
    read -p "Ingrese la versión exacta (o deje en blanco para la Latest): " version
    read -p "Ingrese el puerto de escucha (ej. 8080): " puerto

    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Iniciando instalación silenciosa...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    if [ -z "$version" ]; then
        apt-get install -y -q nginx > /dev/null 2>&1
        VER_MOSTRAR="Latest"
    else
        apt-get install -y -q nginx="$version" > /dev/null 2>&1
        VER_MOSTRAR="$version"
    fi

    echo -e "${AMARILLO}Configurando puerto $puerto...${RESET}"
    sed -i "s/listen 80 default_server;/listen $puerto default_server;/g" /etc/nginx/sites-available/default
    sed -i "s/listen \[::\]:80 default_server;/listen \[::\]:$puerto default_server;/g" /etc/nginx/sites-available/default

    echo -e "${AMARILLO}Aplicando configuraciones de seguridad (Headers y Métodos)...${RESET}"
    # Ocultar versión
    sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
    # Headers de seguridad
    sed -i '/server_tokens off;/a \        add_header X-Frame-Options "SAMEORIGIN";\n        add_header X-Content-Type-Options "nosniff";' /etc/nginx/nginx.conf
    
    # Bloquear métodos TRACE/TRACK/DELETE
    sed -i '/server_name _;/a \        if ($request_method !~ ^(GET|HEAD|POST)$ ) {\n            return 405;\n        }' /etc/nginx/sites-available/default

    echo -e "${AMARILLO}Creando usuario dedicado y ajustando permisos en /var/www/html...${RESET}"
    id -u webadmin_nginx &>/dev/null || useradd -r -s /usr/sbin/nologin webadmin_nginx
    chown -R webadmin_nginx:www-data /var/www/html
    chmod -R 750 /var/www/html

    echo "<h1>Servidor: Nginx - Versión: $VER_MOSTRAR - Puerto: $puerto</h1>" > /var/www/html/index.html

    configurar_firewall "$puerto"
    systemctl restart nginx
    echo -e "${VERDE}[✓] Nginx configurado de forma segura y exitosa en el puerto $puerto.${RESET}"
    sleep 2
}

# --- 3. DESPLIEGUE DE TOMCAT ---
menu_instalar_tomcat() {
    echo -e "\n${CYAN}--- DESPLIEGUE DE TOMCAT (EXTRACCIÓN) ---${RESET}"
    echo "Opciones de versiones de Tomcat disponibles:"
    echo "1) LTS (9.0.86)"
    echo "2) Latest / Desarrollo (10.1.19)"
    read -p "Seleccione versión [1-2]: " opc_ver
    
    if [ "$opc_ver" == "1" ]; then
        T_VER="9.0.86"
        T_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$T_VER/bin/apache-tomcat-$T_VER.tar.gz"
    elif [ "$opc_ver" == "2" ]; then
        T_VER="10.1.19"
        T_URL="https://archive.apache.org/dist/tomcat/tomcat-10/v$T_VER/bin/apache-tomcat-$T_VER.tar.gz"
    else
        echo -e "${ROJO}[ERROR] Selección inválida.${RESET}"
        return 1
    fi

    read -p "Ingrese el puerto de escucha (ej. 8888): " puerto
    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Instalando Java silenciosamente (Requisito)...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -q default-jdk > /dev/null 2>&1

    echo -e "${AMARILLO}Descargando y extrayendo Tomcat v$T_VER...${RESET}"
    wget -q $T_URL -O /tmp/tomcat.tar.gz
    mkdir -p /opt/tomcat
    tar -xf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
    rm /tmp/tomcat.tar.gz

    echo -e "${AMARILLO}Configurando puerto $puerto y seguridad (Header X-Powered-By/Server)...${RESET}"
    # Modificar puerto y sobreescribir nombre del servidor en cabeceras
    sed -i "s/port=\"8080\" protocol=\"HTTP\/1.1\"/port=\"$puerto\" protocol=\"HTTP\/1.1\" server=\"AppServer\"/g" /opt/tomcat/conf/server.xml
    # Forzar headers contra clickjacking en web.xml global
    sed -i '/<\/web-app>/i \
    <filter>\n\
        <filter-name>httpHeaderSecurity</filter-name>\n\
        <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter</filter-class>\n\
        <init-param><param-name>antiClickJackingOption</param-name><param-value>SAMEORIGIN</param-value></init-param>\n\
    </filter>\n\
    <filter-mapping><filter-name>httpHeaderSecurity</filter-name><url-pattern>/*</url-pattern></filter-mapping>' /opt/tomcat/conf/web.xml
    
    # Bloquear métodos peligrosos
    sed -i '/<\/web-app>/i \
    <security-constraint>\n\
        <web-resource-collection>\n\
            <web-resource-name>BlockedMethods</web-resource-name>\n\
            <url-pattern>/*</url-pattern>\n\
            <http-method>TRACE</http-method>\n\
            <http-method>TRACK</http-method>\n\
            <http-method>DELETE</http-method>\n\
        </web-resource-collection>\n\
        <auth-constraint />\n\
    </security-constraint>' /opt/tomcat/conf/web.xml

    echo -e "${AMARILLO}Creando usuario dedicado y configurando permisos...${RESET}"
    id -u webadmin_tomcat &>/dev/null || useradd -r -m -U -d /opt/tomcat -s /bin/false webadmin_tomcat
    chown -R webadmin_tomcat:webadmin_tomcat /opt/tomcat
    chmod -R 750 /opt/tomcat

    echo "<h1>Servidor: Tomcat - Versión: $T_VER - Puerto: $puerto</h1>" > /opt/tomcat/webapps/ROOT/index.jsp
    chown webadmin_tomcat:webadmin_tomcat /opt/tomcat/webapps/ROOT/index.jsp

    echo -e "${AMARILLO}Creando servicio SystemD...${RESET}"
    cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=webadmin_tomcat
Group=webadmin_tomcat
Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart tomcat
    systemctl enable tomcat > /dev/null 2>&1

    configurar_firewall "$puerto"
    echo -e "${VERDE}[✓] Tomcat instalado de forma segura y exitosa en el puerto $puerto.${RESET}"
    sleep 2
}

# ==========================================
# CONTROLADOR PRINCIPAL (MENÚ INTERACTIVO)
# ==========================================
main_menu() {
    while true; do
        clear
        echo -e "${AZUL}================================================${RESET}"
        echo -e "${AMARILLO}  SISTEMA DE APROVISIONAMIENTO HTTP - LINUX  ${RESET}"
        echo -e "${AZUL}================================================${RESET}"
        echo -e "1) Verificar Estado de Servicios"
        echo -e "2) Desplegar Servidor Apache2"
        echo -e "3) Desplegar Servidor Nginx"
        echo -e "4) Desplegar Servidor Tomcat"
        echo -e "5) Salir"
        echo -e "${AZUL}================================================${RESET}"
        read -p "Seleccione una opción [1-5]: " opcion
        
        case $opcion in
            1) verificar_http; read -n 1 -s -r -p "Presione cualquier tecla para continuar..." ;;
            2) menu_instalar_apache; read -n 1 -s -r -p "Presione cualquier tecla para continuar..." ;;
            3) menu_instalar_nginx; read -n 1 -s -r -p "Presione cualquier tecla para continuar..." ;;
            4) menu_instalar_tomcat; read -n 1 -s -r -p "Presione cualquier tecla para continuar..." ;;
            5) echo -e "${CYAN}Saliendo del sistema de aprovisionamiento...${RESET}"; exit 0 ;;
            *) echo -e "${ROJO}[ERROR] Opción inválida.${RESET}"; sleep 1 ;;
        esac
    done
}

# Invocar la función principal al ejecutar el script
main_menu