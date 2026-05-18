#!/bin/bash
pruebas(){
echo ""
echo "=== PRUEBAS ==="

echo "[TEST] Servicio:"
sudo systemctl status bind9 | grep Active

echo "[TEST] Puerto 53 (debe mostrar $IP_SERVIDOR:53):"
sudo ss -tulnp | grep :53

echo "[TEST] DNS:"
dig @$IP_SERVIDOR $DOMINIO +short
dig @$IP_SERVIDOR www.$DOMINIO +short

echo "[TEST] Ping cliente:"
ping -c 2 $IP_CLIENTE

echo ""
echo "=== FINALIZADO ==="
}