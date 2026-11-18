#!/usr/bin/env bash
# =============================================================================
#  Lanza las 9 EC2 del proyecto y conecta cada privada con el NAT de su AZ
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  ANTES: ./crear-red.sh  (tiene que existir ids.env al lado de este script)
#
#  QUÉ HACE
#    1. Busca la AMI de Ubuntu 24.04
#    2. Lanza las 9 instancias con la IP privada del plan
#    3. Quita Source/Destination Check a NAT-1 y NAT-2
#    4. Pone la ruta 0.0.0.0/0 de cada subred privada hacia el NAT de su AZ
#
#  No instala nftables, HAProxy, BIND ni WordPress. Eso se hace después,
#  por Session Manager, con los scripts de las otras carpetas.
#
#  Rol de instancia: LabRole, salvo que exportes INSTANCE_PROFILE=
#  (vacío) para lanzar sin rol.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. El mensaje de AWS está arriba."' ERR

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$DIR/ids.env" ]]; then
  echo "No está $DIR/ids.env. Corre primero ./crear-red.sh"
  exit 1
fi
# shellcheck disable=SC1091
source "$DIR/ids.env"
export AWS_DEFAULT_REGION="$REGION"

INSTANCE_PROFILE="${INSTANCE_PROFILE-LabRole}"
profile_args=()
if [[ -n "$INSTANCE_PROFILE" ]]; then
  profile_args=(--iam-instance-profile "Name=${INSTANCE_PROFILE}")
fi

log() { echo ">> $*" >&2; }

limpiar() {
  if [[ -z "${1:-}" || "$1" == "None" ]]; then
    printf '%s' ""
  else
    printf '%s' "$1"
  fi
}

log "Buscando AMI Ubuntu 24.04 en $REGION"
AMI="$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query "Parameter.Value" --output text)"
log "AMI $AMI"

buscar_instancia() {
  limpiar "$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=tag:Project,Values=si3002-n2" \
              "Name=instance-state-name,Values=pending,running,stopped,stopping" \
    --query "Reservations[].Instances[].InstanceId | [0]" --output text)"
}

lanzar() {
  local nombre="$1" tipo="$2" subnet="$3" sg="$4" ip="$5" publica="$6"
  local existente estado ud
  existente="$(buscar_instancia "$nombre")"
  if [[ -n "$existente" ]]; then
    estado="$(aws ec2 describe-instances --instance-ids "$existente" --query "Reservations[0].Instances[0].State.Name" --output text)"
    log "$nombre ya existe ($existente, $estado). No se lanza otra: el tope es 9."
    if [[ "$estado" == "stopped" ]]; then
      aws ec2 start-instances --instance-ids "$existente" >/dev/null
    fi
    printf '%s' "$existente"
    return
  fi

  ud="$(mktemp)"
  cat > "$ud" <<EOF
#!/bin/bash
hostnamectl set-hostname ${nombre}
echo ${nombre} > /etc/hostname
EOF

  local -a red_args=()
  if [[ "$publica" == "si" ]]; then
    red_args=(--associate-public-ip-address)
  fi

  log "Lanzando $nombre ($tipo, $ip)"
  local id
  id="$(aws ec2 run-instances \
    --image-id "$AMI" \
    --instance-type "$tipo" \
    --subnet-id "$subnet" \
    --private-ip-address "$ip" \
    --security-group-ids "$sg" \
    "${red_args[@]}" \
    "${profile_args[@]}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${nombre}},{Key=Project,Value=si3002-n2}]" \
    --user-data "file://${ud}" \
    --query "Instances[0].InstanceId" --output text)"
  rm -f "$ud"
  printf '%s' "$id"
}

# Tipo de instancia. El Learner Lab de este equipo tope a 12 vCPU, así que
# se usa t2.micro (1 vCPU, 1 GB) en las nueve: 9 vCPU en total, cabe de sobra.
# Se puede sobreescribir exportando TIPO antes de correr el script.
TIPO="${TIPO:-t2.micro}"

NAT1="$(lanzar NAT-1 "$TIPO" "$SUBNET_PUB_1" "$SG_NAT_1" 10.0.1.10 si)"
HAP1="$(lanzar HAProxy-1 "$TIPO" "$SUBNET_PUB_1" "$SG_HAPROXY" 10.0.1.20 si)"
BIND1="$(lanzar BIND-primario "$TIPO" "$SUBNET_PUB_1" "$SG_BIND" 10.0.1.30 si)"
WP1="$(lanzar WordPress-1 "$TIPO" "$SUBNET_PRIV_1" "$SG_WP" 10.0.2.10 no)"
NAT2="$(lanzar NAT-2 "$TIPO" "$SUBNET_PUB_2" "$SG_NAT_2" 10.0.3.10 si)"
HAP2="$(lanzar HAProxy-2 "$TIPO" "$SUBNET_PUB_2" "$SG_HAPROXY" 10.0.3.20 si)"
BIND2="$(lanzar BIND-secundario "$TIPO" "$SUBNET_PUB_2" "$SG_BIND" 10.0.3.30 si)"
WP2="$(lanzar WordPress-2 "$TIPO" "$SUBNET_PRIV_2" "$SG_WP" 10.0.4.10 no)"
DB="$(lanzar MariaDB "$TIPO" "$SUBNET_PRIV_2" "$SG_DB" 10.0.4.20 no)"

IDS=("$NAT1" "$HAP1" "$BIND1" "$WP1" "$NAT2" "$HAP2" "$BIND2" "$WP2" "$DB")
log "Esperando a que las 9 estén en running..."
aws ec2 wait instance-running --instance-ids "${IDS[@]}"

log "Quitando Source/Destination Check en NAT-1 y NAT-2"
aws ec2 modify-instance-attribute --instance-id "$NAT1" --no-source-dest-check
aws ec2 modify-instance-attribute --instance-id "$NAT2" --no-source-dest-check

ruta_nat() {
  local rtb="$1" instancia="$2" nombre="$3"
  local ya
  ya="$(limpiar "$(aws ec2 describe-route-tables --route-table-ids "$rtb" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].DestinationCidrBlock | [0]" --output text)")"
  if [[ -n "$ya" ]]; then
    log "Reemplazando ruta por defecto de $nombre -> $instancia"
    aws ec2 replace-route --route-table-id "$rtb" --destination-cidr-block 0.0.0.0/0 --instance-id "$instancia"
  else
    log "Creando ruta por defecto de $nombre -> $instancia"
    aws ec2 create-route --route-table-id "$rtb" --destination-cidr-block 0.0.0.0/0 --instance-id "$instancia" >/dev/null
  fi
}

ruta_nat "$RT_PRIV_1" "$NAT1" "privada 1"
ruta_nat "$RT_PRIV_2" "$NAT2" "privada 2"

echo ""
echo "============================================================"
echo " 9 EC2 LANZADAS"
echo "============================================================"
echo " Source/Destination Check de los NAT: desactivado."
echo " Privada 1 sale por NAT-1. Privada 2 sale por NAT-2."
echo ""
echo " SIGUIENTE, por Session Manager, en este orden:"
echo "   1. NAT-1:  bash configurar-nat.sh"
echo "   2. NAT-2:  bash configurar-nat.sh 10.0.4.0/24"
echo "   3. MariaDB, luego WordPress-1, luego WordPress-2"
echo "   4. Los dos HAProxy"
echo "   5. Anotar IP públicas y configurar los dos BIND"
echo ""
echo " Hasta que el NAT no esté configurado POR DENTRO, las privadas"
echo " no pueden instalar paquetes ni registrarse bien en Session Manager."
echo " Los NAT, HAProxy y BIND sí tienen IP pública: Session Manager"
echo " puede entrar a esas seis en cuanto el agente SSM arranque."
echo "============================================================"
echo ""

bash "$DIR/mostrar-inventario.sh"
