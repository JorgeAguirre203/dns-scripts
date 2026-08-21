#!/bin/bash

# ==========================================
# VARIABLES GLOBALES DE CONFIGURACIÓN
# ==========================================
FTP_SERVER="192.168.1.100" # <-- Cambia esto por la IP de tu servidor FTP privado
FTP_USER="usuario_ftp"     # <-- Cambia esto por tu usuario
FTP_PASS="clave_ftp"       # <-- Cambia esto por tu contraseña
DIR_DESCARGAS="/tmp/orquestador_descargas"
PUERTO_SSL_ACTIVO="Ninguno"

# ==========================================
# MÓDULO DE FUNCIONES
# ==========================================

verificar_dependencias() {
    echo "[*] Verificando herramientas del sistema (curl, openssl)..."
    if ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
        echo "[*] Instalando dependencias..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq curl openssl >/dev/null 2>&1
    fi
    echo "[✓] Dependencias listas."
}

validar_puerto_ingresado() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ -z "$puerto" ]; then
        echo "[ERROR] El puerto debe ser un número válido."
        return 1
    fi
    if ss -tuln | grep -q ":$puerto "; then
        echo "[ERROR] El puerto $puerto ya está ocupado en el sistema."
        return 1
    fi
    return 0
}

navegar_y_descargar_ftp() {
    local servicio=$1
    mkdir -p "$DIR_DESCARGAS"

    local puerto_ftp_actual=$(grep "^listen_port=" /etc/vsftpd.conf 2>/dev/null | cut -d'=' -f2)
    puerto_ftp_actual=${puerto_ftp_actual:-21} 

    local url_servicio="ftp://$FTP_SERVER:$puerto_ftp_actual/http/Linux/$servicio/"
    echo "[*] Explorando repositorio FTP para $servicio..."

    mapfile -t archivos_versiones < <(curl -s -l -k --ssl -u "$FTP_USER:$FTP_PASS" "$url_servicio" | grep -v '\.sha256$')
    
    if [ ${#archivos_versiones[@]} -eq 0 ]; then
        echo "[!] No se encontraron instaladores para $servicio en el FTP."
        return 1
    fi

    local archivo_elegido=$(echo "${archivos_versiones[0]}" | tr -d '\r')
    echo "[*] Descargando $archivo_elegido y su firma SHA256..."
    
    curl -s -k --ssl -u "$FTP_USER:$FTP_PASS" "$url_servicio$archivo_elegido" -o "$DIR_DESCARGAS/$archivo_elegido"
    curl -s -k --ssl -u "$FTP_USER:$FTP_PASS" "$url_servicio$archivo_elegido.sha256" -o "$DIR_DESCARGAS/$archivo_elegido.sha256"

    cd "$DIR_DESCARGAS" || return 1
    echo "[*] Validando integridad del archivo..."
    if sha256sum -c "$archivo_elegido.sha256" > /dev/null 2>&1; then
        echo "[✓] Hash SHA256 Correcto. Archivo íntegro."
        PAQUETE_DESCARGADO="$DIR_DESCARGAS/$archivo_elegido"
        cd - > /dev/null
        return 0
    else
        echo "[ERROR] Archivo corrupto. El Hash no coincide."
        cd - > /dev/null
        return 1
    fi
}

instalar_y_configurar_servicio() {
    local servicio=$1
    local metodo=$2
    local puerto=$3
    local paquete=$4
    local pkg_debian=""

    case $servicio in
        "Apache") pkg_debian="apache2" ;;
        "Nginx") pkg_debian="nginx" ;;
        "vsftpd") pkg_debian="vsftpd" ;;
        "Tomcat") pkg_debian="tomcat10 tomcat10-admin" ;; 
    esac

    echo "[*] Instalando $servicio (Modo: $metodo)..."

    if [ "$metodo" == "web" ]; then
        apt-get update -qq && apt-get install -y $pkg_debian -qq >/dev/null 2>&1
    else
        dpkg -i "$paquete" >/dev/null 2>&1
        apt-get install -f -y -qq >/dev/null 2>&1
    fi

    echo "[*] Aplicando configuraciones base..."
    case $servicio in
        "Apache")
            sed -i "s/Listen 80/Listen $puerto/g" /etc/apache2/ports.conf
            sed -i "s/<VirtualHost \*:80>/<VirtualHost \*:$puerto>/g" /etc/apache2/sites-available/000-default.conf
            echo "<h1>[✓] www.reprobados.com: Apache activo en puerto $puerto</h1>" > /var/www/html/index.html
            systemctl restart apache2
            ;;
        "Nginx")
            sed -i "s/listen 80/listen $puerto/g" /etc/nginx/sites-enabled/default
            echo "<h1>[✓] www.reprobados.com: Nginx activo en puerto $puerto</h1>" > /var/www/html/index.html
            systemctl restart nginx
            ;;
        "Tomcat")
            sed -i "s/port=\"8080\"/port=\"$puerto\"/g" /etc/tomcat10/server.xml
            mkdir -p /var/lib/tomcat10/webapps/ROOT
            echo "<h1>[✓] www.reprobados.com: Tomcat activo en puerto $puerto</h1>" > /var/lib/tomcat10/webapps/ROOT/index.html
            systemctl restart tomcat10
            ;;
        "vsftpd")
            grep -q "listen_port" /etc/vsftpd.conf || echo "listen_port=$puerto" >> /etc/vsftpd.conf
            sed -i "s/listen_port=.*/listen_port=$puerto/g" /etc/vsftpd.conf
            systemctl restart vsftpd
            ;;
    esac
}

generar_certificado_ssl() {
    if [ ! -f /etc/ssl/reprobados/servidor.crt ]; then
        echo "[*] Creando certificados PKI para www.reprobados.com..."
        mkdir -p /etc/ssl/reprobados
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/reprobados/servidor.key \
        -out /etc/ssl/reprobados/servidor.crt \
        -subj "/C=MX/ST=Sinaloa/L=Mochis/O=UAS/OU=FIM/CN=www.reprobados.com" >/dev/null 2>&1
        
        chmod 644 /etc/ssl/reprobados/servidor.key
        chmod 644 /etc/ssl/reprobados/servidor.crt
    fi
}

aplicar_ssl_servicio() {
    local servicio=$1
    local puerto_http=$2
    
    read -p "¿Desea activar SSL en este servicio? [S/N]: " activar_ssl
    if [[ "$activar_ssl" =~ ^[Ss]$ ]]; then
        read -p "Ingresa el puerto SEGURO (SSL/TLS) a utilizar (ej. 443, 8443): " puerto_ssl
        export PUERTO_SSL_ACTIVO=$puerto_ssl 
        generar_certificado_ssl
        
        echo "[*] Inyectando configuración SSL en $servicio..."
        case $servicio in
            "Apache")
                a2enmod ssl rewrite >/dev/null 2>&1
                cat <<EOF > /etc/apache2/sites-available/default-ssl.conf
<VirtualHost *:$puerto_ssl>
    ServerName www.reprobados.com
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/reprobados/servidor.crt
    SSLCertificateKeyFile /etc/ssl/reprobados/servidor.key
</VirtualHost>
EOF
                a2ensite default-ssl >/dev/null 2>&1
                sed -i "/VirtualHost \*:$puerto_http/a \ \tRewriteEngine On\n\tRewriteCond %{HTTPS} off\n\tRewriteRule ^(.*)$ https://%{HTTP_HOST}:%{SERVER_PORT}%{REQUEST_URI} [L,R=301]" /etc/apache2/sites-available/000-default.conf
                systemctl restart apache2
                ;;
            "Nginx")
                cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen $puerto_http;
    server_name _;
    return 301 https://\$host:$puerto_ssl\$request_uri;
}
server {
    listen $puerto_ssl ssl;
    server_name _;
    ssl_certificate /etc/ssl/reprobados/servidor.crt;
    ssl_certificate_key /etc/ssl/reprobados/servidor.key;
    location / {
        root /var/www/html;
        index index.html index.nginx-debian.html;
    }
}
EOF
                systemctl restart nginx
                ;;
            "vsftpd")
                export PUERTO_SSL_ACTIVO=$puerto_http
                {
                    echo "ssl_enable=YES"
                    echo "allow_anon_ssl=NO"
                    echo "force_local_data_ssl=YES"
                    echo "force_local_logins_ssl=YES"
                    echo "ssl_tlsv1=YES"
                    echo "rsa_cert_file=/etc/ssl/reprobados/servidor.crt"
                    echo "rsa_private_key_file=/etc/ssl/reprobados/servidor.key"
                } >> /etc/vsftpd.conf
                systemctl restart vsftpd
                ;;
            "Tomcat")
                sed -i "/<\/Service>/i \    <Connector port=\"$puerto_ssl\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" maxThreads=\"150\" SSLEnabled=\"true\" scheme=\"https\" secure=\"true\" clientAuth=\"false\" sslProtocol=\"TLS\">\n      <SSLHostConfig>\n        <Certificate certificateFile=\"/etc/ssl/reprobados/servidor.crt\" certificateKeyFile=\"/etc/ssl/reprobados/servidor.key\" type=\"RSA\" />\n      </SSLHostConfig>\n    </Connector>" /etc/tomcat10/server.xml
                systemctl restart tomcat10
                ;;
        esac
        echo "[✓] SSL/TLS activado y configurado."
    else
        export PUERTO_SSL_ACTIVO="Ninguno"
    fi
}

realizar_resumen_instalacion() {
    local serv=$1
    local pto=$2
    
    if [ "$serv" == "Tomcat" ]; then
        echo "[*] Esperando a que el servicio Java inicie..."
        sleep 5
    fi

    echo "========================================="
    echo "       RESUMEN DE INSTALACIÓN            "
    echo "========================================="
    echo "Servicio: $serv"
    
    local p_name="${serv,,}"; [[ "$serv" == "Apache" ]] && p_name="apache2"; [[ "$serv" == "Tomcat" ]] && p_name="java"
    echo -ne "Estado del proceso: "
    pgrep "$p_name" >/dev/null && echo "OK" || echo "FAIL"
    
    echo -ne "Puerto HTTP activo ($pto): "
    ss -tuln | grep -q ":$pto " && echo "OK" || echo "CERRADO"
    
    echo -ne "Cifrado SSL/TLS (Puerto $PUERTO_SSL_ACTIVO): "
    if [ "$PUERTO_SSL_ACTIVO" != "Ninguno" ]; then
        ss -tuln | grep -q ":$PUERTO_SSL_ACTIVO " || grep -q "ssl_enable=YES" /etc/vsftpd.conf && echo "ACTIVO" || echo "FALLÓ"
    else
        echo "OMITIDO"
    fi
    echo "-----------------------------------------"
}

# ==========================================
# BLOQUE PRINCIPAL DE EJECUCIÓN (MENÚ)
# ==========================================

clear
echo "========================================="
echo "   ORQUESTADOR HÍBRIDO LINUX - TAREA 7   "
echo "========================================="

# 1. Chequeo inicial
verificar_dependencias

# 2. Selección de Servicio
echo "¿Qué servicio desea desplegar?"
echo "1) Apache"
echo "2) Nginx"
echo "3) Tomcat"
echo "4) vsftpd"
read -p "Seleccione [1-4]: " opc_serv

case $opc_serv in
    1) SERVICIO_ELEGIDO="Apache" ;;
    2) SERVICIO_ELEGIDO="Nginx" ;;
    3) SERVICIO_ELEGIDO="Tomcat" ;;
    4) SERVICIO_ELEGIDO="vsftpd" ;;
    *) echo "[ERROR] Opción no válida."; exit 1 ;;
esac

# 3. Selección de Origen
echo "¿Desde dónde desea instalar?"
echo "1) Repositorio Web (apt)"
echo "2) Repositorio Privado FTP"
read -p "Seleccione [1-2]: " opc_metodo

METODO_ELEGIDO="web"
if [ "$opc_metodo" == "2" ]; then
    METODO_ELEGIDO="ftp"
    navegar_y_descargar_ftp "$SERVICIO_ELEGIDO"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Falló la descarga FTP o la validación Hash. Abortando."
        exit 1
    fi
fi

# 4. Configuración de Puertos
read -p "Ingrese el puerto base a utilizar (ej. 80, 8080, 21): " PUERTO_BASE
validar_puerto_ingresado "$PUERTO_BASE" || exit 1

# 5. Ejecución en cascada
instalar_y_configurar_servicio "$SERVICIO_ELEGIDO" "$METODO_ELEGIDO" "$PUERTO_BASE" "$PAQUETE_DESCARGADO"
aplicar_ssl_servicio "$SERVICIO_ELEGIDO" "$PUERTO_BASE"
realizar_resumen_instalacion "$SERVICIO_ELEGIDO" "$PUERTO_BASE"

echo "[✓] Flujo de orquestación finalizado."