#!/bin/bash

# Asegurar permisos de superusuario
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, ejecuta el script como root o usando sudo."
    exit 1
fi

configuracion_inicial_ftp() {
    echo "[*] Instalando vsftpd y configurando entorno..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq vsftpd acl >/dev/null 2>&1

    groupadd reprobados 2>/dev/null
    groupadd recursadores 2>/dev/null

    if ! grep -q "/usr/sbin/nologin" /etc/shells; then
        echo "/usr/sbin/nologin" >> /etc/shells
    fi

    # Estructura de carpetas raíz física
    mkdir -p /srv/ftp/grupos/general
    mkdir -p /srv/ftp/grupos/reprobados
    mkdir -p /srv/ftp/grupos/recursadores
    mkdir -p /srv/ftp/autenticados

    # Lobby para usuario anónimo
    mkdir -p /srv/ftp/lobby_anonimo/general
    chown root:root /srv/ftp/lobby_anonimo
    chmod 555 /srv/ftp/lobby_anonimo
    mount --bind /srv/ftp/grupos/general /srv/ftp/lobby_anonimo/general 2>/dev/null
    
    if ! grep -q "lobby_anonimo" /etc/fstab; then
        echo "/srv/ftp/grupos/general /srv/ftp/lobby_anonimo/general none bind 0 0" >> /etc/fstab
    fi

    # Permisos base y herencia (ACL)
    chown root:root /srv/ftp/grupos/general
    chmod 555 /srv/ftp/grupos/general
    chmod 770 /srv/ftp/grupos/reprobados
    chmod 770 /srv/ftp/grupos/recursadores

    setfacl -m g:reprobados:rwx /srv/ftp/grupos/general 2>/dev/null
    setfacl -m g:recursadores:rwx /srv/ftp/grupos/general 2>/dev/null
                                                   
    setfacl -d -m g:reprobados:rwx /srv/ftp/grupos/general 2>/dev/null
    setfacl -d -m g:recursadores:rwx /srv/ftp/grupos/general 2>/dev/null
    setfacl -d -m g:reprobados:rwx /srv/ftp/grupos/reprobados 2>/dev/null
    setfacl -d -m g:recursadores:rwx /srv/ftp/grupos/recursadores 2>/dev/null

    # Configuración de vsftpd
    cat <<EOF > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=YES
no_anon_password=YES
anon_root=/srv/ftp/lobby_anonimo
local_enable=YES
write_enable=YES
local_umask=002
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
seccomp_sandbox=NO
EOF

    systemctl restart vsftpd >/dev/null 2>&1
    echo "[OK] Servidor FTP configurado correctamente."
}

verificar_instalacion_ftp() {
    echo ""
    echo "========================================="
    echo "   VERIFICACIÓN DE ESTADO FTP (vsftpd)   "
    echo "========================================="

    if systemctl is-active --quiet vsftpd; then
        echo "[OK] El servicio vsftpd está ACTIVO y ejecutándose."
    else
        echo "[!] El servicio vsftpd NO está activo o no está instalado."
    fi

    if ss -tln | grep -q ":21 "; then
        echo "[OK] El puerto 21 (FTP) está abierto y a la escucha."
    else
        echo "[!] El puerto 21 NO está a la escucha."
    fi

    if getent group reprobados >/dev/null && getent group recursadores >/dev/null; then
        echo "[OK] Los grupos base (reprobados, recursadores) existen en el sistema."
    else
        echo "[!] Faltan los grupos base en el sistema."
    fi

    if [ -d "/srv/ftp/grupos/general" ]; then
        echo "[OK] La estructura física de directorios raíz está creada."
    else
        echo "[!] La estructura de directorios NO existe."
    fi

    echo "========================================="
}

validar_usuario_ftp() {
    local user=$1
    if [[ -z "$user" || "$user" =~ ^[0-9] || "$user" =~ [^a-zA-Z0-9_] || ${#user} -gt 15 ]]; then
        return 1
    fi
    id "$user" &>/dev/null && return 1
    return 0
}

gestion_alta_usuarios() {
    read -p "¿Cuántos usuarios deseas agregar? " n
    for ((i=1; i<=n; i++)); do
        while true; do
            echo "--- Creando usuario $i de $n ---"
            read -p "Username: " username
            if validar_usuario_ftp "$username"; then
                read -p "Grupo (1:reprobados, 2:recursadores): " op
                [[ "$op" == "1" ]] && grupo="reprobados" || grupo="recursadores"

                useradd -m -d /srv/ftp/autenticados/$username -s /usr/sbin/nologin -G "$grupo" "$username"
                read -s -p "Password para $username: " pass
                echo "$username:$pass" | chpasswd
                echo ""

                mkdir -p /srv/ftp/autenticados/$username/{general,"$grupo",$username}

                chown root:root /srv/ftp/autenticados/$username
                chmod 555 /srv/ftp/autenticados/$username

                mount --bind /srv/ftp/grupos/general /srv/ftp/autenticados/$username/general 2>/dev/null
                mount --bind /srv/ftp/grupos/"$grupo" /srv/ftp/autenticados/$username/"$grupo" 2>/dev/null

                echo "/srv/ftp/grupos/general /srv/ftp/autenticados/$username/general none bind 0 0" >> /etc/fstab
                echo "/srv/ftp/grupos/$grupo /srv/ftp/autenticados/$username/$grupo none bind 0 0" >> /etc/fstab

                systemctl daemon-reload

                setfacl -m u:$username:rwx /srv/ftp/autenticados/$username/$username
                setfacl -m u:$username:rwx /srv/ftp/grupos/general
                setfacl -m u:$username:rwx /srv/ftp/grupos/"$grupo"

                echo "[OK] Usuario $username listo y configurado."
                break
            else
                echo "[!] Username inválido o el usuario ya existe."
            fi
        done
    done
}

cambiar_grupo_ftp() {
    read -p "Ingrese el username a cambiar de grupo: " username
    if ! id "$username" &>/dev/null; then
        echo "[!] El usuario no existe."
        return 1
    fi

    read -p "NUEVO grupo (1:reprobados, 2:recursadores): " op
    if [ "$op" == "1" ]; then
        nuevo_grupo="reprobados"; viejo_grupo="recursadores"
    elif [ "$op" == "2" ]; then
        nuevo_grupo="recursadores"; viejo_grupo="reprobados"
    else
        echo "[!] Opción inválida."
        return 1
    fi

    echo "[*] Moviendo usuario..."

    umount /srv/ftp/autenticados/$username/$viejo_grupo 2>/dev/null
    sed -i "\|/srv/ftp/autenticados/$username/$viejo_grupo|d" /etc/fstab
    rm -rf /srv/ftp/autenticados/$username/$viejo_grupo

    gpasswd -d $username $viejo_grupo 2>/dev/null
    usermod -aG $nuevo_grupo $username

    mkdir -p /srv/ftp/autenticados/$username/$nuevo_grupo
    mount --bind /srv/ftp/grupos/$nuevo_grupo /srv/ftp/autenticados/$username/$nuevo_grupo
    echo "/srv/ftp/grupos/$nuevo_grupo /srv/ftp/autenticados/$username/$nuevo_grupo none bind 0 0" >> /etc/fstab

    setfacl -m u:$username:rwx /srv/ftp/grupos/$nuevo_grupo

    echo "[OK] Usuario movido a $nuevo_grupo exitosamente."
}

eliminar_usuario_ftp() {
    read -p "Ingrese el username que desea eliminar: " username
    if ! id "$username" &>/dev/null; then
        echo "[!] El usuario no existe."
        return 1
    fi

    if id -nG "$username" | grep -qw "reprobados"; then
        grupo="reprobados"
    else
        grupo="recursadores"
    fi

    echo "[*] Limpiando montajes y archivos..."

    umount /srv/ftp/autenticados/$username/general 2>/dev/null
    umount /srv/ftp/autenticados/$username/$grupo 2>/dev/null

    sed -i "\|/srv/ftp/autenticados/$username|d" /etc/fstab

    userdel -r "$username"

    echo "[OK] Usuario $username eliminado del servidor."
}

# --- MENÚ PRINCIPAL Y EJECUCIÓN ---
while true; do
    echo ""
    echo "========================================="
    echo "      GESTIÓN DE SERVIDORES FTP          "
    echo "========================================="
    echo "1. Configurar e Instalar Servidor FTP"
    echo "2. Verificar Estado del Servidor FTP"
    echo "3. Dar de Alta Usuarios FTP"
    echo "4. Cambiar Usuario de Grupo"
    echo "5. Eliminar Usuario FTP"
    echo "6. Salir"
    read -p "Selecciona una opción [1-6]: " opcion

    case $opcion in
        1) configuracion_inicial_ftp ;;
        2) verificar_instalacion_ftp ;;
        3) gestion_alta_usuarios ;;
        4) cambiar_grupo_ftp ;;
        5) eliminar_usuario_ftp ;;
        6) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done