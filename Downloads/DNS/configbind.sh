#!/bin/bash
config_bind(){
echo "[INFO] Configurando BIND..."

sudo bash -c "cat > /etc/bind/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";

    listen-on { $IP_SERVIDOR; };
    listen-on-v6 { none; };

    allow-query { any; };
    recursion yes;
};
EOF

sudo bash -c "cat > /etc/bind/named.conf.local" <<EOF
zone "$DOMINIO" {
    type master;
    file "$ZONA_FILE";
};
EOF

sudo bash -c "cat > $ZONA_FILE" <<EOF
\$TTL 604800
@   IN  SOA ns.$DOMINIO. admin.$DOMINIO. (
        2
        604800
        86400
        2419200
        604800 )

@       IN  NS      ns.$DOMINIO.
ns      IN  A       $IP_SERVIDOR

@       IN  A       $IP_CLIENTE
www     IN  CNAME   $DOMINIO.
EOF
}