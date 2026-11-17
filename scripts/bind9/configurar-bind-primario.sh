#!/bin/bash
# =============================================================================
#  BIND9 PRIMARIO (maestro de la zona)
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    Solo en BIND-primario: 10.0.1.30, subred pública 1, us-east-1a.
#
#  ANTES DE CORRERLO, edita el bloque de variables.
#  Las cuatro IP son las IP PÚBLICAS de las EC2 (las que muestra la consola
#  de AWS o `curl -4 https://ifconfig.me` dentro de cada máquina pública).
#  No uses las IP privadas 10.0.x para los registros A de www ni de los NS:
#  el resto de Internet no puede enrutarlas.
#
#  El secundario (10.0.3.30) recibe la zona por transferencia. Este script
#  no se pega en el secundario: para eso está configurar-bind-secundario.sh.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. Revisa la salida de arriba."' ERR

# ----- EDITAR ESTO -----------------------------------------------------------
DOMINIO=""                      # ejemplo: xyzsa.com   (sin http:// y sin www)
IP_NS2_PUBLICA=""               # IP pública de BIND-secundario (10.0.3.30 por dentro)
IP_WEB_1=""                     # IP pública de HAProxy-1
IP_WEB_2=""                     # IP pública de HAProxy-2
IP_NS1_PUBLICA=""               # déjala vacía para detectarla en esta máquina
# IP privada del secundario. Tiene que coincidir con la EC2 real.
IP_SECUNDARIO_PRIVADA="10.0.3.30"
# -----------------------------------------------------------------------------

is_ipv4() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

if [[ -z "$DOMINIO" || "$DOMINIO" == *.*example* || "$DOMINIO" == "example.com" ]]; then
  echo "Define DOMINIO con un dominio o subdominio real. Un nombre de laboratorio no vale para la entrega."
  exit 1
fi

echo ">> Comprobando salida a Internet..."
if ! curl -4 -fsS --max-time 20 https://ifconfig.me >/dev/null; then
  echo "Esta instancia no sale a Internet. Revisa IP pública y ruta al Internet Gateway."
  exit 1
fi

if [[ -z "$IP_NS1_PUBLICA" ]]; then
  IP_NS1_PUBLICA="$(curl -4 -fsS --max-time 20 https://ifconfig.me)"
  echo ">> IP pública de este primario: $IP_NS1_PUBLICA"
fi

for pareja in \
  "IP_NS1_PUBLICA:$IP_NS1_PUBLICA" \
  "IP_NS2_PUBLICA:$IP_NS2_PUBLICA" \
  "IP_WEB_1:$IP_WEB_1" \
  "IP_WEB_2:$IP_WEB_2"
do
  nombre="${pareja%%:*}"
  valor="${pareja#*:}"
  if ! is_ipv4 "$valor"; then
    echo "La variable $nombre no es una IPv4 válida (valor: '$valor')."
    exit 1
  fi
done

SERIAL="$(date +%Y%m%d01)"
ZONA="/etc/bind/zones/db.${DOMINIO}"

echo ">> Instalando BIND9..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 bind9-utils bind9-dnsutils dnsutils

echo ">> Escribiendo opciones (autoritativo, sin recursión)..."
cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    recursion no;
    allow-query { any; };
    allow-transfer { none; };
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    dnssec-validation no;
    minimal-responses no;
};
EOF

echo ">> Escribiendo la zona ${DOMINIO} (serial ${SERIAL})..."
mkdir -p /etc/bind/zones
cat > "$ZONA" <<EOF
\$TTL 60
\$ORIGIN ${DOMINIO}.
@       IN SOA  ns1.${DOMINIO}. hostmaster.${DOMINIO}. (
                ${SERIAL}   ; serial  (súbelo en cada cambio: prueba D2)
                60          ; refresh
                60          ; retry
                1209600     ; expire
                60 )        ; minimum / TTL de caché negativa
        IN NS   ns1.${DOMINIO}.
        IN NS   ns2.${DOMINIO}.
ns1     IN A    ${IP_NS1_PUBLICA}
ns2     IN A    ${IP_NS2_PUBLICA}
@       IN A    ${IP_WEB_1}
@       IN A    ${IP_WEB_2}
www     IN A    ${IP_WEB_1}
www     IN A    ${IP_WEB_2}
inicio  IN CNAME www.${DOMINIO}.
EOF

chown root:bind "$ZONA"
chmod 640 "$ZONA"

cat > /etc/bind/named.conf.local <<EOF
zone "${DOMINIO}" {
    type primary;
    file "${ZONA}";
    notify yes;
    allow-transfer { ${IP_SECUNDARIO_PRIVADA}; };
    also-notify { ${IP_SECUNDARIO_PRIVADA}; };
};
EOF

echo ">> Comprobando zona y configuración..."
named-checkzone "$DOMINIO" "$ZONA"
named-checkconf

if systemctl cat named.service >/dev/null 2>&1; then
  systemctl enable named
  systemctl restart named
else
  systemctl enable bind9
  systemctl restart bind9
fi

echo ""
echo "============================================================"
echo " BIND PRIMARIO LISTO"
echo "============================================================"
echo " Dominio:  $DOMINIO"
echo " Serial:   $SERIAL"
echo " ns1 A:    $IP_NS1_PUBLICA"
echo " ns2 A:    $IP_NS2_PUBLICA"
echo " www A:    $IP_WEB_1 y $IP_WEB_2"
echo " CNAME:    inicio.${DOMINIO} -> www.${DOMINIO}"
echo ""
echo " Prueba local:"
echo "   dig @127.0.0.1 ${DOMINIO} SOA"
echo "   dig @127.0.0.1 www.${DOMINIO} A"
echo "   dig @127.0.0.1 inicio.${DOMINIO} CNAME"
echo ""
echo " Siguiente paso: correr configurar-bind-secundario.sh en 10.0.3.30"
echo " y, en el registrador, delegar el dominio a ns1 y ns2 con estas IP públicas."
echo "============================================================"
