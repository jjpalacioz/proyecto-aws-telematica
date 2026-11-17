#!/usr/bin/env bash
# =============================================================================
#  VPC, subredes, Internet Gateway, tablas de rutas y security groups
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    AWS CloudShell del Learner Lab, o un computador con AWS CLI y las
#    credenciales temporales del lab.
#
#  QUÉ CREA
#    VPC 10.0.0.0/16
#    Pública 1  10.0.1.0/24  us-east-1a     Privada 1  10.0.2.0/24  us-east-1a
#    Pública 2  10.0.3.0/24  us-east-1b     Privada 2  10.0.4.0/24  us-east-1b
#    Internet Gateway y ruta 0.0.0.0/0 en las dos públicas
#    Tablas privadas YA asociadas, todavía sin ruta por defecto
#    (esa ruta la agrega lanzar-instancias.sh cuando existen los NAT)
#    Security groups del diseño
#
#  Si lo corres otra vez, reutiliza lo que ya tenga el tag Name de este proyecto.
#  Al final escribe scripts/aws/ids.env (no lo subas si el repo es público).
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. El mensaje de AWS está arriba."' ERR

REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
export AWS_DEFAULT_REGION="$REGION"
AZ_A="${AZ_A:-${REGION}a}"
AZ_B="${AZ_B:-${REGION}b}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v aws >/dev/null 2>&1; then
  echo "No está el comando aws. Usa CloudShell en el Learner Lab."
  exit 1
fi
aws sts get-caller-identity >/dev/null

log() { echo ">> $*" >&2; }

# Imprime un id o cadena vacía si AWS devolvió None.
limpiar() {
  if [[ -z "${1:-}" || "$1" == "None" ]]; then
    printf '%s' ""
  else
    printf '%s' "$1"
  fi
}

etiquetar() {
  aws ec2 create-tags --resources "$1" --tags "Key=Name,Value=$2" "Key=Project,Value=si3002-n2" >/dev/null
}

buscar_vpc() {
  limpiar "$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=si3002-vpc" "Name=tag:Project,Values=si3002-n2" \
    --query "Vpcs[0].VpcId" --output text)"
}

buscar_subnet() {
  limpiar "$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=$1" "Name=tag:Project,Values=si3002-n2" \
    --query "Subnets[0].SubnetId" --output text)"
}

buscar_igw() {
  limpiar "$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=si3002-igw" "Name=tag:Project,Values=si3002-n2" \
    --query "InternetGateways[0].InternetGatewayId" --output text)"
}

buscar_rt() {
  limpiar "$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=$1" "Name=tag:Project,Values=si3002-n2" \
    --query "RouteTables[0].RouteTableId" --output text)"
}

buscar_sg() {
  limpiar "$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$1" \
    --query "SecurityGroups[0].GroupId" --output text)"
}

# Abre una regla. Si ya existe, sigue.
abrir() {
  local sg="$1" json="$2"
  local err
  if ! err="$(aws ec2 authorize-security-group-ingress --group-id "$sg" --cli-input-json "$json" 2>&1)"; then
    if [[ "$err" == *"InvalidPermission.Duplicate"* ]]; then
      echo "   (la regla ya existía)"
    else
      echo "$err" >&2
      return 1
    fi
  fi
}

log "Región $REGION  AZ $AZ_A y $AZ_B"

VPC_ID="$(buscar_vpc)"
if [[ -z "$VPC_ID" ]]; then
  log "Creando VPC 10.0.0.0/16"
  VPC_ID="$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query "Vpc.VpcId" --output text)"
  etiquetar "$VPC_ID" "si3002-vpc"
else
  log "VPC ya existía: $VPC_ID"
fi

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}"

crear_subnet() {
  local nombre="$1" cidr="$2" az="$3" publica="$4"
  local id
  id="$(buscar_subnet "$nombre")"
  if [[ -z "$id" ]]; then
    log "Creando subred $nombre $cidr $az"
    id="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$cidr" --availability-zone "$az" --query "Subnet.SubnetId" --output text)"
    etiquetar "$id" "$nombre"
  else
    log "Subred ya existía: $nombre $id"
  fi
  if [[ "$publica" == "si" ]]; then
    aws ec2 modify-subnet-attribute --subnet-id "$id" --map-public-ip-on-launch
  fi
  printf '%s' "$id"
}

SUBNET_PUB_1="$(crear_subnet si3002-publica-1 10.0.1.0/24 "$AZ_A" si)"
SUBNET_PRIV_1="$(crear_subnet si3002-privada-1 10.0.2.0/24 "$AZ_A" no)"
SUBNET_PUB_2="$(crear_subnet si3002-publica-2 10.0.3.0/24 "$AZ_B" si)"
SUBNET_PRIV_2="$(crear_subnet si3002-privada-2 10.0.4.0/24 "$AZ_B" no)"

IGW_ID="$(buscar_igw)"
if [[ -z "$IGW_ID" ]]; then
  log "Creando Internet Gateway"
  IGW_ID="$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)"
  etiquetar "$IGW_ID" "si3002-igw"
fi
if ! aws ec2 describe-internet-gateways --internet-gateway-ids "$IGW_ID" \
    --query "InternetGateways[0].Attachments[?VpcId=='$VPC_ID'] | [0].VpcId" --output text | grep -q "$VPC_ID"; then
  log "Asociando Internet Gateway a la VPC"
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
fi

crear_rt() {
  local nombre="$1"
  local id
  id="$(buscar_rt "$nombre")"
  if [[ -z "$id" ]]; then
    log "Creando tabla de rutas $nombre"
    id="$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query "RouteTable.RouteTableId" --output text)"
    etiquetar "$id" "$nombre"
  else
    log "Tabla ya existía: $nombre $id"
  fi
  printf '%s' "$id"
}

asociar() {
  local rtb="$1" subnet="$2"
  local ya
  ya="$(limpiar "$(aws ec2 describe-route-tables --route-table-ids "$rtb" \
    --query "RouteTables[0].Associations[?SubnetId=='$subnet'].RouteTableAssociationId | [0]" --output text)")"
  if [[ -z "$ya" ]]; then
    aws ec2 associate-route-table --route-table-id "$rtb" --subnet-id "$subnet" >/dev/null
  fi
}

RT_PUBLIC="$(crear_rt si3002-rt-publica)"
if ! aws ec2 describe-route-tables --route-table-ids "$RT_PUBLIC" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]" --output text | grep -q "^igw-"; then
  log "Ruta pública 0.0.0.0/0 -> Internet Gateway"
  aws ec2 create-route --route-table-id "$RT_PUBLIC" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
fi
asociar "$RT_PUBLIC" "$SUBNET_PUB_1"
asociar "$RT_PUBLIC" "$SUBNET_PUB_2"

RT_PRIV_1="$(crear_rt si3002-rt-privada-1)"
RT_PRIV_2="$(crear_rt si3002-rt-privada-2)"
asociar "$RT_PRIV_1" "$SUBNET_PRIV_1"
asociar "$RT_PRIV_2" "$SUBNET_PRIV_2"
log "Las tablas privadas quedan sin 0.0.0.0/0 hasta que existan NAT-1 y NAT-2."

crear_sg() {
  local nombre="$1" desc="$2"
  local id
  id="$(buscar_sg "$nombre")"
  if [[ -z "$id" ]]; then
    log "Creando security group $nombre"
    id="$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name "$nombre" --description "$desc" --query "GroupId" --output text)"
    etiquetar "$id" "$nombre"
  else
    log "Security group ya existía: $nombre $id"
  fi
  printf '%s' "$id"
}

SG_NAT_1="$(crear_sg si3002-sg-nat-1 "NAT de la AZ A, solo desde la privada 1")"
SG_NAT_2="$(crear_sg si3002-sg-nat-2 "NAT de la AZ B, solo desde la privada 2")"
SG_HAPROXY="$(crear_sg si3002-sg-haproxy "HTTP publico hacia los balanceadores")"
SG_BIND="$(crear_sg si3002-sg-bind "DNS autoritativo")"
SG_WP="$(crear_sg si3002-sg-wordpress "HTTP solo desde los dos HAProxy")"
SG_DB="$(crear_sg si3002-sg-mariadb "MariaDB solo desde las dos WordPress")"

log "Reglas de entrada"
abrir "$SG_NAT_1" '{"IpPermissions":[{"IpProtocol":"-1","IpRanges":[{"CidrIp":"10.0.2.0/24","Description":"privada-1"}]}]}'
abrir "$SG_NAT_2" '{"IpPermissions":[{"IpProtocol":"-1","IpRanges":[{"CidrIp":"10.0.4.0/24","Description":"privada-2"}]}]}'
abrir "$SG_HAPROXY" '{"IpPermissions":[{"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"http"}]}]}'
abrir "$SG_BIND" '{"IpPermissions":[
  {"IpProtocol":"tcp","FromPort":53,"ToPort":53,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"dns-tcp"}]},
  {"IpProtocol":"udp","FromPort":53,"ToPort":53,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"dns-udp"}]}
]}'
abrir "$SG_WP" '{"IpPermissions":[{"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[
  {"CidrIp":"10.0.1.20/32","Description":"haproxy-1"},
  {"CidrIp":"10.0.3.20/32","Description":"haproxy-2"}
]}]}'
abrir "$SG_DB" '{"IpPermissions":[{"IpProtocol":"tcp","FromPort":3306,"ToPort":3306,"IpRanges":[
  {"CidrIp":"10.0.2.10/32","Description":"wordpress-1"},
  {"CidrIp":"10.0.4.10/32","Description":"wordpress-2"}
]}]}'

# ICMP dentro de la VPC, para el análisis de protocolos del enunciado.
for sg in "$SG_NAT_1" "$SG_NAT_2" "$SG_HAPROXY" "$SG_BIND" "$SG_WP" "$SG_DB"; do
  abrir "$sg" '{"IpPermissions":[{"IpProtocol":"icmp","FromPort":-1,"ToPort":-1,"IpRanges":[{"CidrIp":"10.0.0.0/16","Description":"icmp-vpc"}]}]}'
done

cat > "$DIR/ids.env" <<EOF
# Generado por crear-red.sh. Lo usa lanzar-instancias.sh.
# No lo publiques: identifica recursos de la cuenta del lab.
REGION=$REGION
AZ_A=$AZ_A
AZ_B=$AZ_B
VPC_ID=$VPC_ID
IGW_ID=$IGW_ID
SUBNET_PUB_1=$SUBNET_PUB_1
SUBNET_PRIV_1=$SUBNET_PRIV_1
SUBNET_PUB_2=$SUBNET_PUB_2
SUBNET_PRIV_2=$SUBNET_PRIV_2
RT_PUBLIC=$RT_PUBLIC
RT_PRIV_1=$RT_PRIV_1
RT_PRIV_2=$RT_PRIV_2
SG_NAT_1=$SG_NAT_1
SG_NAT_2=$SG_NAT_2
SG_HAPROXY=$SG_HAPROXY
SG_BIND=$SG_BIND
SG_WP=$SG_WP
SG_DB=$SG_DB
EOF

echo ""
echo "============================================================"
echo " RED LISTA"
echo "============================================================"
echo " VPC          $VPC_ID"
echo " IGW          $IGW_ID"
echo " Pública 1    $SUBNET_PUB_1   ($AZ_A  10.0.1.0/24)"
echo " Privada 1    $SUBNET_PRIV_1   ($AZ_A  10.0.2.0/24)"
echo " Pública 2    $SUBNET_PUB_2   ($AZ_B  10.0.3.0/24)"
echo " Privada 2    $SUBNET_PRIV_2   ($AZ_B  10.0.4.0/24)"
echo " IDs en       $DIR/ids.env"
echo ""
echo " Siguiente: ./lanzar-instancias.sh"
echo " El puerto 22 no se abre. La administración es por Session Manager."
echo "============================================================"
