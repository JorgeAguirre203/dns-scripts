#!/bin/bash
ipfija(){
if [ "$IP_ACTUAL" != "$IP_SERVIDOR" ]; then
    read -p "Configurar IP fija $IP_SERVIDOR en $INTERFAZ_DNS? (s/n): " RESP

    if [ "$RESP" = "s" ]; then
        sudo bash -c "cat > /etc/netplan/01-dns.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFAZ_DNS:
      dhcp4: false
      addresses:
        - $IP_SERVIDOR/24
    $INTERFAZ_NET:
      dhcp4: true
EOF
        sudo netplan apply
        echo "[OK] IP configurada en $INTERFAZ_DNS"
    fi
fi
}