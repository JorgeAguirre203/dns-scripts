#!/bin/bash

source ./funciones_utils.sh

instalar_ssh() {
    echo "=== Instalando OpenSSH Server ==="
    instalar_paquete "openssh-server"
}

configurar_ssh() {
    echo "=== Configurando SSH ==="

    # Cambiar puerto (opcional, puedes comentar si no quieres)
    sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config

    # Permitir autenticación por contraseña
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Permitir login root (opcional, pero útil para práctica)
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
}

iniciar_ssh() {
    echo "=== Iniciando servicio SSH ==="
    systemctl start ssh
    systemctl enable ssh
}

configurar_firewall() {
    echo "=== Configurando Firewall ==="

    if command -v ufw > /dev/null; then
        ufw allow 22/tcp
        ufw enable
        echo "✔ Puerto 22 abierto en UFW"
    else
        echo "⚠ UFW no instalado, omitiendo firewall"
    fi
}

verificar_ssh() {
    echo "=== Verificando SSH ==="
    validar_servicio "ssh"
}

instalar_configurar_ssh() {
    verificar_root
    verificar_conexion

    instalar_ssh
    configurar_ssh
    iniciar_ssh
    configurar_firewall
    verificar_ssh

    echo "🚀 SSH listo. Puedes conectarte con:"
    echo "ssh usuario@IP_DEL_SERVIDOR"
}