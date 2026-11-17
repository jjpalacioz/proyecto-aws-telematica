#!/bin/bash
# =============================================================================
#  HAPROXY — balanceador HTTP del proyecto (el mismo script en las dos EC2)
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    HAProxy-1   10.0.1.20   subred pública 1   us-east-1a
#    HAProxy-2   10.0.3.20   subred pública 2   us-east-1b
#
#  QUÉ HACE
#    Escucha HTTP en el puerto 80 y reparte cada petición entre
#    WordPress-1 (10.0.2.10) y WordPress-2 (10.0.4.10).
#    Los dos balanceadores conocen las dos instancias. Si una WordPress
#    se apaga, el chequeo de salud la saca y el tráfico se queda en la otra.
#    Eso es la prueba B2.
#
#  QUÉ NO HACE (a propósito)
#    - No usa cookie ni afinidad de sesión. Si la hubiera, B1 no se vería.
#    - No cachea respuestas.
#    - Cierra la conexión hacia el servidor en cada petición
#      (option http-server-close) para que el round-robin sí alterne.
#
#  CÓMO SE EJECUTA
#    1. Session Manager en la instancia HAProxy.
#    2. sudo bash configurar-haproxy.sh
#    El script es igual en HAProxy-1 y en HAProxy-2.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. Revisa la salida de arriba."' ERR

WP1_IP="10.0.2.10"
WP2_IP="10.0.4.10"

echo ">> Comprobando salida a Internet..."
if ! curl -4 -fsS --max-time 20 https://ifconfig.me >/dev/null; then
  echo "Esta instancia no sale a Internet."
  echo "Es una máquina pública: revisa que tenga IP pública y que su ruta 0.0.0.0/0 apunte al Internet Gateway."
  exit 1
fi

echo ">> Instalando HAProxy..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y haproxy curl

echo ">> Escribiendo /etc/haproxy/haproxy.cfg ..."
cp -a /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat > /etc/haproxy/haproxy.cfg <<EOF
# Balanceo HTTP del sitio XYZ. Mismo archivo en HAProxy-1 y HAProxy-2.
# Cada balanceador habla con las DOS WordPress, también con la de la otra AZ.

global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 2000
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    # Una conexión nueva hacia WordPress por cada petición.
    # Sin esto, el keep-alive deja varias peticiones pegadas al mismo servidor
    # y la prueba B1 parece que no balancea.
    option  http-server-close
    option  forwardfor
    option  redispatch
    retries 3
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    timeout http-request 10s

frontend http_front
    bind *:80
    default_backend wordpress

backend wordpress
    # roundrobin: 1a petición a wp1, 2a a wp2, 3a a wp1...
    # No hay línea "cookie". La afinidad de sesión ocultaría el reparto.
    balance roundrobin
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host localhost
    http-check expect rstatus ^[23]
    server wp1 ${WP1_IP}:80 check inter 3s fall 2 rise 2
    server wp2 ${WP2_IP}:80 check inter 3s fall 2 rise 2

# Estadísticas solo en la propia máquina (Session Manager). No se publican.
listen stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
EOF

echo ">> Validando la configuración..."
haproxy -c -f /etc/haproxy/haproxy.cfg

echo ">> Arrancando HAProxy..."
systemctl enable haproxy
systemctl restart haproxy
systemctl --no-pager --full status haproxy || true

echo ""
echo "============================================================"
echo " HAPROXY LISTO"
echo "============================================================"
echo " Backends: wp1=${WP1_IP}  wp2=${WP2_IP}"
echo " Comprueba el chequeo de salud (los dos deben salir UP cuando WordPress ya responda):"
echo "   curl -s http://127.0.0.1:8404/stats ; echo"
echo " Desde tu PC, cuando esta instancia tenga IP pública:"
echo "   curl -s http://IP_PUBLICA_DE_ESTE_HAPROXY/ | grep -o '10\\.0\\.[0-9.]*'"
echo " Repite el curl varias veces. Tienen que aparecer 10.0.2.10 y 10.0.4.10."
echo "============================================================"
