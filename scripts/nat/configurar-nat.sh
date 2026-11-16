#!/bin/bash
# =============================================================================
#  SCRIPT DE CONFIGURACIÓN DE INSTANCIA NAT CASERA (con nftables)
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  ¿QUÉ ES ESTO?
#  Una instancia NAT es una máquina en una subred PÚBLICA que le presta su
#  salida a Internet a las máquinas de la subred PRIVADA (que no tienen IP
#  pública). Es como el "portero" que saca las cartas de los de adentro y
#  les devuelve las respuestas.
#
#  ¿DÓNDE SE EJECUTA ESTE SCRIPT?
#  - En NAT-1 (subred pública 1, us-east-1a)  -> da salida a la privada 1
#  - En NAT-2 (subred pública 2, us-east-1b)  -> da salida a la privada 2
#  (Es el mismo script en las dos; solo cambia la variable RED_PRIVADA)
#
#  ¿CÓMO LO EJECUTO?
#  1. Entra a la instancia NAT con Session Manager.
#  2. Ponte como root:            sudo su -
#  3. Pega TODO este script (o guárdalo como archivo y córrelo con: bash configurar-nat.sh)
#
#  IMPORTANTE (se hace en la consola de AWS, NO aquí):
#  - Hay que DESHABILITAR el "Source/Destination Check" de esta instancia NAT.
#    (En EC2 -> seleccionar la instancia -> Actions -> Networking ->
#     Change source/destination check -> Stop). Sin esto, NADA de NAT funciona.
# =============================================================================

set -e  # si algún comando falla, el script se detiene (para no seguir a ciegas)

# -----------------------------------------------------------------------------
# PASO 0: Variables que debes revisar según en qué NAT estés
# -----------------------------------------------------------------------------
# En NAT-1 (AZ-a), la red privada que atiende es 10.0.2.0/24
# En NAT-2 (AZ-b), cámbiala a                      10.0.4.0/24
RED_PRIVADA="10.0.2.0/24"

# Nombre de la interfaz de red de la instancia. En Ubuntu 24.04 sobre EC2
# normalmente es "ens5". El script la detecta solo, pero puedes forzarla aquí.
INTERFAZ=$(ip route | grep default | awk '{print $5}' | head -n1)

echo ">> Interfaz de red detectada: $INTERFAZ"
echo ">> Red privada que atenderá este NAT: $RED_PRIVADA"

# -----------------------------------------------------------------------------
# PASO 1: Activar el "IP forwarding"
# -----------------------------------------------------------------------------
# Por defecto Linux NO reenvía paquetes de una tarjeta a otra (actúa como un PC
# normal, no como un router). Esta línea lo convierte en router: le permite
# tomar un paquete que viene de la red privada y reenviarlo hacia Internet.
echo ">> Activando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

# Lo dejamos escrito en un archivo de configuración para que SIGA ACTIVO
# aunque la instancia se reinicie (el Learner Lab apaga las máquinas seguido).
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf

# -----------------------------------------------------------------------------
# PASO 2: Instalar nftables (el firewall/NAT moderno de Linux)
# -----------------------------------------------------------------------------
echo ">> Instalando nftables..."
apt-get update -y
apt-get install -y nftables conntrack

# -----------------------------------------------------------------------------
# PASO 3: Crear la regla de NAT (enmascaramiento / masquerade)
# -----------------------------------------------------------------------------
# "masquerade" significa: a todo paquete que salga de la red privada hacia
# Internet, cámbiale la IP de origen por la IP de esta instancia NAT. Así el
# servidor de Internet le responde al NAT, y el NAT le devuelve la respuesta
# a la máquina privada correcta (eso lo recuerda la tabla de conntrack).

echo ">> Creando reglas nftables..."

# Borramos cualquier configuración previa para empezar limpio
nft flush ruleset

# Tabla de NAT
nft add table ip nat

# Cadena de POSTROUTING: se aplica justo cuando el paquete va a SALIR.
nft add chain ip nat postrouting '{ type nat hook postrouting priority 100 ; }'

# La regla estrella: todo lo que venga de la red privada y salga por la
# interfaz hacia Internet, se enmascara con la IP del NAT.
nft add rule ip nat postrouting ip saddr $RED_PRIVADA oifname "$INTERFAZ" masquerade

# -----------------------------------------------------------------------------
# PASO 4: Guardar las reglas para que sobrevivan a un reinicio
# -----------------------------------------------------------------------------
echo ">> Guardando reglas en /etc/nftables.conf..."
nft list ruleset > /etc/nftables.conf

# Activamos el servicio para que cargue las reglas al arrancar la máquina
systemctl enable nftables
systemctl restart nftables

# -----------------------------------------------------------------------------
# LISTO
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " NAT CONFIGURADO ✅"
echo "============================================================"
echo " Verifica con estos comandos:"
echo "   sysctl net.ipv4.ip_forward     (debe decir = 1)"
echo "   nft list ruleset               (debe mostrar la regla masquerade)"
echo ""
echo " RECUERDA: desactiva 'Source/Destination Check' de esta"
echo " instancia en la consola de AWS, o el NAT NO funcionará."
echo "============================================================"
