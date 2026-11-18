#!/usr/bin/env bash
# =============================================================================
#  Asigna Elastic IP (IP pública fija) a las 4 instancias que la necesitan
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  POR QUÉ
#    El Learner Lab se apaga solo cada ~4 horas y al reiniciar las IP públicas
#    normales CAMBIAN. Las 4 máquinas cuyas IP van en el dominio (los 2 HAProxy
#    y los 2 BIND) necesitan IP fija para no tener que re-delegar el dominio
#    cada vez. Una Elastic IP se queda pegada a la instancia aunque se reinicie.
#
#  QUÉ HACE
#    1. Libera Elastic IP sueltas (sin asociar) de este proyecto, para no gastar.
#    2. Reserva una Elastic IP por cada una de las 4 instancias.
#    3. La asocia a la instancia correcta.
#    4. Muestra la tabla final.
#
#  DÓNDE
#    AWS CloudShell del Learner Lab.
#
#  Idempotente: si una instancia ya tiene Elastic IP, no le pone otra.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. El mensaje de AWS está arriba."' ERR

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"

log() { echo ">> $*" >&2; }

# Las 4 instancias que llevan IP fija, por su tag Name.
INSTANCIAS=(HAProxy-1 HAProxy-2 BIND-primario BIND-secundario)

id_por_nombre() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" "Name=tag:Project,Values=si3002-n2" \
              "Name=instance-state-name,Values=running,pending" \
    --query "Reservations[0].Instances[0].InstanceId" --output text
}

# ¿La instancia ya tiene una Elastic IP asociada?
eip_de_instancia() {
  aws ec2 describe-addresses \
    --filters "Name=instance-id,Values=$1" \
    --query "Addresses[0].PublicIp" --output text 2>/dev/null
}

log "Liberando Elastic IP sueltas (sin asociar) para no desperdiciar..."
for alloc in $(aws ec2 describe-addresses \
    --query "Addresses[?AssociationId==null].AllocationId" --output text); do
  if [[ -n "$alloc" && "$alloc" != "None" ]]; then
    log "   liberando $alloc"
    aws ec2 release-address --allocation-id "$alloc" || true
  fi
done

echo ""
printf '%-18s %-22s %-16s\n' "Instancia" "InstanceId" "Elastic IP"
printf '%-18s %-22s %-16s\n' "---------" "----------" "----------"

for nombre in "${INSTANCIAS[@]}"; do
  iid="$(id_por_nombre "$nombre")"
  if [[ -z "$iid" || "$iid" == "None" ]]; then
    printf '%-18s %-22s %-16s\n' "$nombre" "(no existe)" "-"
    continue
  fi

  ya="$(eip_de_instancia "$iid")"
  if [[ -n "$ya" && "$ya" != "None" ]]; then
    printf '%-18s %-22s %-16s\n' "$nombre" "$iid" "$ya (ya tenía)"
    continue
  fi

  alloc="$(aws ec2 allocate-address --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=eip-${nombre}},{Key=Project,Value=si3002-n2}]" \
    --query "AllocationId" --output text)"
  aws ec2 associate-address --allocation-id "$alloc" --instance-id "$iid" >/dev/null
  nueva="$(aws ec2 describe-addresses --allocation-ids "$alloc" --query "Addresses[0].PublicIp" --output text)"
  printf '%-18s %-22s %-16s\n' "$nombre" "$iid" "$nueva"
done

echo ""
echo "============================================================"
echo " ELASTIC IP ASIGNADAS"
echo "============================================================"
echo " Estas 4 IP ya NO cambian aunque el lab se reinicie."
echo " Son las que van en la zona DNS:"
echo "   www  -> HAProxy-1 y HAProxy-2"
echo "   ns1  -> BIND-primario"
echo "   ns2  -> BIND-secundario"
echo ""
echo " Las instancias privadas (WordPress, MariaDB) no necesitan:"
echo " su IP privada (10.0.x.x) ya es fija."
echo "============================================================"
