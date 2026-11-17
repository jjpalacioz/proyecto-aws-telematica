#!/usr/bin/env bash
# Lista las EC2 de este proyecto con IP privada e IP pública.
# Corre en CloudShell o donde esté la AWS CLI con la sesión del lab.

set -euo pipefail
REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$DIR/ids.env" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/ids.env"
  REGION="${REGION:-$AWS_DEFAULT_REGION}"
fi
export AWS_DEFAULT_REGION="$REGION"

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=si3002-n2" "Name=instance-state-name,Values=pending,running,stopped" \
  --query "sort_by(Reservations[].Instances[], &PrivateIpAddress)[].{Nombre:Tags[?Key=='Name']|[0].Value,Estado:State.Name,Tipo:InstanceType,Privada:PrivateIpAddress,Publica:PublicIpAddress,Id:InstanceId}" \
  --output table

echo ""
echo "Source/Destination Check de las instancias NAT (tiene que decir false):"
ids="$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=si3002-n2" "Name=tag:Name,Values=NAT-1,NAT-2" "Name=instance-state-name,Values=pending,running,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)"
if [[ -n "$ids" ]]; then
  # shellcheck disable=SC2086
  aws ec2 describe-instances --instance-ids $ids \
    --query "Reservations[].Instances[].{Nombre:Tags[?Key=='Name']|[0].Value,SourceDestCheck:SourceDestCheck}" \
    --output table
fi
