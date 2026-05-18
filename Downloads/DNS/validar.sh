#!/bin/bash

validar(){
echo "[INFO] Validando..."

sudo named-checkconf || { echo "[ERROR] Config incorrecta"; exit 1; }
sudo named-checkzone $DOMINIO $ZONA_FILE || { echo "[ERROR] Zona incorrecta"; exit 1; }

echo "[OK] Configuración válida"
}