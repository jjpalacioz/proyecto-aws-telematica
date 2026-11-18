# Inventario del despliegue (sesión del 18 nov 2026)

> ✅ Las 4 IP que van en el dominio (2 HAProxy + 2 BIND) son **Elastic IP FIJAS**:
> no cambian aunque el Learner Lab se apague y se reinicie.
> Las IPs **privadas** también son fijas (las fijó el script de lanzamiento).
> Los NAT tienen IP pública normal (no va en ningún lado externo, no importa si cambia).

## IPs FIJAS (Elastic IP) — las definitivas para el dominio

| Máquina | Elastic IP (FIJA) | Rol en DNS |
|---|---|---|
| HAProxy-1 | `18.214.151.88` | registro A de `www` |
| HAProxy-2 | `18.232.215.62` | registro A de `www` |
| BIND-primario | `23.21.163.138` | nameserver `ns1` |
| BIND-secundario | `52.2.122.81` | nameserver `ns2` |

## Las 9 instancias EC2

Todas `t2.micro` (1 vCPU, 1 GB RAM). El Learner Lab de este equipo topa en 9 instancias
simultáneas (detenidas también cuentan), por eso se usa `t2.micro` y no `t3.small`.

| Instancia | IP privada | IP pública (sesión 18 nov) | AZ | Subred |
|---|---|---|---|---|
| NAT-1 | 10.0.1.10 | 13.220.34.110 (normal) | us-east-1a | Pública 1 |
| HAProxy-1 | 10.0.1.20 | **18.214.151.88 (Elastic)** | us-east-1a | Pública 1 |
| BIND-primario | 10.0.1.30 | **23.21.163.138 (Elastic)** | us-east-1a | Pública 1 |
| WordPress-1 | 10.0.2.10 | (sin pública) | us-east-1a | Privada 1 |
| NAT-2 | 10.0.3.10 | 3.86.114.200 (normal) | us-east-1b | Pública 2 |
| HAProxy-2 | 10.0.3.20 | **18.232.215.62 (Elastic)** | us-east-1b | Pública 2 |
| BIND-secundario | 10.0.3.30 | **52.2.122.81 (Elastic)** | us-east-1b | Pública 2 |
| WordPress-2 | 10.0.4.10 | (sin pública) | us-east-1b | Privada 2 |
| MariaDB | 10.0.4.20 | (sin pública) | us-east-1b | Privada 2 |

## IPs para la zona DNS (registros A) — todas Elastic, fijas

- `www` → 18.214.151.88 (HAProxy-1) y 18.232.215.62 (HAProxy-2)  ← DNS Round Robin
- `ns1` → 23.21.163.138 (BIND-primario)
- `ns2` → 52.2.122.81 (BIND-secundario)

## Comprobaciones al lanzar
- Source/Destination Check en NAT-1 y NAT-2: **False** ✅
- Ruta privada 1 (10.0.2.0/24) → NAT-1 ✅
- Ruta privada 2 (10.0.4.0/24) → NAT-2 ✅

## Orden de configuración por dentro (Session Manager)
1. NAT-1: `bash configurar-nat.sh`
2. NAT-2: `bash configurar-nat.sh 10.0.4.0/24`
3. MariaDB → WordPress-1 → WordPress-2
4. HAProxy-1 y HAProxy-2
5. Anotar IPs públicas y configurar BIND-primario y BIND-secundario
