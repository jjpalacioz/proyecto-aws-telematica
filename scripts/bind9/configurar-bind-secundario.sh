#!/bin/bash
# =============================================================================
#  BIND9 SECUNDARIO (recibe la zona por transferencia)
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    Solo en BIND-secundario: 10.0.3.30, subred pública 2, us-east-1b.
#
#  ANTES
#    El primario (10.0.1.30) ya tiene que estar respondiendo.
#    DOMINIO tiene que ser exactamente el mismo texto que en el primario.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. Revisa la salida de arriba."' ERR

# ----- EDITAR ESTO -----------------------------------------------------------
DOMINIO=""                      # el mismo que en el primario, sin www
IP_PRIMARIO_PRIVADA="10.0.1.30"
# -----------------------------------------------------------------------------

if [[ -z "$DOMINIO" || "$DOMINIO" == *.*example* || "$DOMINIO" == "example.com" ]]; then
  echo "Define DOMINIO con el mismo dominio real que usaste en el primario."
  exit 1
fi

echo ">> Comprobando salida a Internet..."
if ! curl -4 -fsS --max-time 20 https://ifconfig.me >/dev/null; then
  echo "Esta instancia no sale a Internet. Revisa IP pública y ruta al Internet Gateway."
  exit 1
fi

echo ">> Instalando BIND9..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 bind9-utils bind9-dnsutils dnsutils

echo ">> Comprobando que el primario responde..."
if ! dig @"$IP_PRIMARIO_PRIVADA" "$DOMINIO" SOA +time=3 +tries=1 | grep -q "status: NOERROR"; then
  echo "El primario $IP_PRIMARIO_PRIVADA no respondió SOA de $DOMINIO."
  echo "Arranca antes configurar-bind-primario.sh y revisa el security group (TCP/UDP 53)."
  exit 1
fi

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

# La copia de la zona se escribe en /var/cache/bind porque AppArmor
# permite escribir ahí. El secundario no se edita a mano: llega por AXFR.
cat > /etc/bind/named.conf.local <<EOF
zone "${DOMINIO}" {
    type secondary;
    file "/var/cache/bind/db.${DOMINIO}";
    primaries { ${IP_PRIMARIO_PRIVADA}; };
};
EOF

named-checkconf
if systemctl cat named.service >/dev/null 2>&1; then
  systemctl enable named
  systemctl restart named
else
  systemctl enable bind9
  systemctl restart bind9
fi

echo ">> Pidiendo la transferencia de zona..."
sleep 2
rndc retransfer "$DOMINIO" || true
sleep 2

echo ""
echo "============================================================"
echo " BIND SECUNDARIO LISTO"
echo "============================================================"
echo " Debe responder AUTHORITY como el primario, con el mismo serial."
echo "   dig @127.0.0.1 ${DOMINIO} SOA"
echo "   dig @127.0.0.1 www.${DOMINIO} A"
echo ""
echo " Si la zona no aparece, en el primario revisa allow-transfer:"
echo " tiene que incluir la IP privada de este secundario (10.0.3.30) y el security group TCP 53."
echo "============================================================"
