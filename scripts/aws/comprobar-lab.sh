#!/bin/bash
# =============================================================================
#  Comprobaciones del primer día en AWS Academy Learner Lab
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    En AWS CloudShell (bash, con la sesión del lab ya iniciada) o en un
#    computador con AWS CLI y las credenciales temporales del lab exportadas.
#
#  No crea nada. Solo dice si la cuenta, la región, el rol y la AMI cuadran
#  con el plan del repositorio.
# =============================================================================

set -u
REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-us-east-1}}"
export AWS_DEFAULT_REGION="$REGION"

echo "Región que va a usar el resto de scripts: $REGION"
echo "Si el Learner Lab está en otra región, exporta AWS_DEFAULT_REGION y vuelve a correr este script."
echo ""

if ! command -v aws >/dev/null 2>&1; then
  echo "No está el comando aws. Ábrelo desde AWS CloudShell, que ya trae la CLI."
  exit 1
fi

echo ">> Identidad de la sesión"
if ! aws sts get-caller-identity; then
  echo "La CLI no tiene credenciales. En el lab: AWS Details -> AWS CLI -> copiar las variables y pegarlas en esta terminal."
  exit 1
fi
echo ""

echo ">> AMI Ubuntu 24.04 (parámetro público de Canonical)"
AMI="$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text 2>/dev/null || true)"
if [[ -z "$AMI" || "$AMI" == "None" ]]; then
  echo "No se pudo leer la AMI. Revisa la región. El plan usa Ubuntu 24.04."
else
  echo "AMI: $AMI"
fi
echo ""

echo ">> Instance profile LabRole (Session Manager)"
if aws iam get-instance-profile --instance-profile-name LabRole >/dev/null 2>&1; then
  echo "LabRole existe. lanzar-instancias.sh lo puede adjuntar."
else
  echo "No se pudo leer LabRole."
  echo "En muchos Learner Lab el perfil se llama LabRole y la CLI de IAM a veces no deja listarlo,"
  echo "pero EC2 sí deja adjuntarlo. Si el lanzamiento falla por el rol, vuelve a correr con:"
  echo "    INSTANCE_PROFILE= ./lanzar-instancias.sh"
  echo "y entra a las instancias públicas por EC2 Instance Connect."
fi
echo ""

echo ">> Elastic IP ya usadas en esta región"
aws ec2 describe-addresses --query "Addresses[].PublicIp" --output text 2>/dev/null || echo "(sin permiso o sin direcciones)"
echo ""
echo "Si más adelante la consola deja asociar Elastic IP, úsalas en los dos BIND y los dos HAProxy."
echo "Si no deja, no detengas esas cuatro instancias después de delegar el dominio: la IP pública cambia."
echo ""

echo ">> Instancias ya encendidas (para no pasarse de 9 ni de la cuota de vCPU)"
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=pending,running \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key=='Name']|[0].Value]" \
  --output table || true

echo ""
echo "Listo. Si la identidad respondió, puedes seguir con ./crear-red.sh"
