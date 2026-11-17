# Red en AWS (consola o CloudShell)

Estos scripts arman la red y las 9 EC2. No instalan NAT, HAProxy, BIND ni WordPress: eso sigue en Session Manager con los otros scripts.

## Dónde correrlos

La opción más simple es **AWS CloudShell** dentro del Learner Lab (el ícono de la terminal, arriba a la derecha de la consola). Ahí ya hay AWS CLI y las credenciales de la sesión.

Sube la carpeta `scripts/aws/` con Actions → Upload file, entra en ella y:

```bash
chmod +x ./*.sh
./comprobar-lab.sh
./crear-red.sh
./lanzar-instancias.sh
./mostrar-inventario.sh
```

Si CloudShell no está disponible, en el lab abre AWS Details, copia las variables `aws_access_key_id`, `aws_secret_access_key` y `aws_session_token`, y expórtalas en una terminal con AWS CLI. Esas claves se vencen: si un comando empieza a responder `ExpiredToken`, copia unas nuevas.

Región prevista: `us-east-1`. Si `comprobar-lab.sh` muestra otra, no lances nada hasta confirmar en cuál región vive el lab.

## Qué hace cada script

| Script | Efecto |
|---|---|
| `comprobar-lab.sh` | No crea nada. Muestra la identidad, la AMI de Ubuntu 24.04 y si aparece `LabRole`. |
| `crear-red.sh` | VPC, 4 subredes, Internet Gateway, rutas públicas, tablas privadas vacías de ruta por defecto, security groups. Escribe `ids.env`. |
| `lanzar-instancias.sh` | 9 EC2 con las IP del plan, quita Source/Destination Check a los NAT y apunta cada privada al NAT de su AZ. |
| `mostrar-inventario.sh` | Tabla con nombre, IP privada e IP pública. |

Correrlos de nuevo no duplica la VPC ni las instancias: busca el tag `Project=si3002-n2`. El tope del curso es 9 EC2 a la vez.

## Security groups que crea

| Grupo | Entrada |
|---|---|
| NAT-1 | Todo el tráfico desde `10.0.2.0/24`, más ICMP desde la VPC |
| NAT-2 | Todo el tráfico desde `10.0.4.0/24`, más ICMP desde la VPC |
| HAProxy | TCP 80 desde Internet, más ICMP desde la VPC |
| BIND | TCP y UDP 53 desde Internet, más ICMP desde la VPC |
| WordPress | TCP 80 solo desde `10.0.1.20` y `10.0.3.20` |
| MariaDB | TCP 3306 solo desde `10.0.2.10` y `10.0.4.10` |

El puerto 22 no se abre. La salida queda en la regla por defecto del security group (permite salir). Como el security group de AWS es con estado, la respuesta de esa salida puede volver.

## Después del lanzamiento

1. Espera uno o dos minutos y abre Session Manager en NAT-1 y NAT-2.
2. Configura el NAT **antes** de instalar nada en las privadas. Sin eso, WordPress y MariaDB no pueden hacer `apt` y a veces tampoco aparecen en Session Manager.
3. Copia las IP públicas de HAProxy-1, HAProxy-2, BIND-primario y BIND-secundario. Esas cuatro van a la zona DNS.

`ids.env` identifica recursos de la cuenta. Está en `.gitignore`.

La explicación de por qué la red está armada así está en `COMO-SE-HIZO.md`, en la raíz del repositorio.
