#!/bin/bash
# =============================================================================
#  MariaDB — la única base de datos del proyecto
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    Solo en la EC2 de base de datos: 10.0.4.20, subred privada 2, us-east-1b.
#    Sale a Internet por NAT-2. Si apt falla, el NAT-2 todavía no está listo.
#
#  LA CLAVE
#    DB_PASS tiene que ser la misma que en configurar-wordpress.sh.
#    Cámbiala en los dos archivos antes de ejecutarlos.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. Revisa la salida de arriba."' ERR

DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASS="CambiarAntesDeEjecutar-XYZ2026"
WP1_IP="10.0.2.10"
WP2_IP="10.0.4.10"

if [[ "$DB_PASS" == CambiarAntesDeEjecutar-* ]]; then
  echo "AVISO: sigues con la clave de ejemplo del repositorio."
  echo "       Cámbiala aquí y en configurar-wordpress.sh si el repositorio se va a compartir."
fi

echo ">> Comprobando salida a Internet por el NAT de esta AZ..."
if ! curl -4 -fsS --max-time 25 https://ifconfig.me >/dev/null; then
  echo "Esta privada no sale a Internet."
  echo "Revisa NAT-2 (RED_PRIVADA=10.0.4.0/24), Source/Destination Check desactivado"
  echo "y la ruta 0.0.0.0/0 de la subred 10.0.4.0/24 hacia NAT-2."
  exit 1
fi
echo ">> La IP pública que ve el exterior es la del NAT, no la de esta máquina:"
curl -4 -fsS --max-time 20 https://ifconfig.me || true
echo ""

echo ">> Instalando MariaDB..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server

CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
if [[ -f "$CNF" ]]; then
  sed -i -E 's/^[#]*[[:space:]]*bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' "$CNF"
  grep -q '^bind-address' "$CNF" || printf '\nbind-address = 0.0.0.0\n' >> "$CNF"
fi

systemctl enable mariadb
systemctl restart mariadb

echo ">> Creando base y usuarios solo para las dos WordPress..."
mysql --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'${WP1_IP}' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'${WP2_IP}' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'${WP1_IP}' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'${WP2_IP}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${WP1_IP}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${WP2_IP}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

echo ""
echo "============================================================"
echo " MARIADB LISTA"
echo "============================================================"
echo " Escucha (tiene que salir 0.0.0.0:3306 o *:3306):"
ss -lnt | grep 3306 || true
echo ""
echo " Base: ${DB_NAME}   Usuario: ${DB_USER}"
echo " Acepta conexiones solo de ${WP1_IP} y ${WP2_IP}."
echo " El security group además debe permitir TCP 3306 solo desde esas dos IP."
echo "============================================================"
