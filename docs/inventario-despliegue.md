# Inventario del despliegue (sesión del 18 nov 2026)

> ⚠️ Las IPs **públicas** cambian si el Learner Lab se apaga y se reinicia.
> Las IPs **privadas** son fijas (las fijó el script de lanzamiento).
> Si reinician el lab, hay que volver a anotar las públicas y actualizar la zona DNS.

## Las 9 instancias EC2

Todas `t2.micro` (1 vCPU, 1 GB RAM). El Learner Lab de este equipo topa en 9 instancias
simultáneas (detenidas también cuentan), por eso se usa `t2.micro` y no `t3.small`.

| Instancia | IP privada | IP pública (sesión 18 nov) | AZ | Subred |
|---|---|---|---|---|
| NAT-1 | 10.0.1.10 | 13.220.34.110 | us-east-1a | Pública 1 |
| HAProxy-1 | 10.0.1.20 | 13.220.39.156 | us-east-1a | Pública 1 |
| BIND-primario | 10.0.1.30 | 184.198.170.195 | us-east-1a | Pública 1 |
| WordPress-1 | 10.0.2.10 | (sin pública) | us-east-1a | Privada 1 |
| NAT-2 | 10.0.3.10 | 3.86.114.200 | us-east-1b | Pública 2 |
| HAProxy-2 | 10.0.3.20 | 3.83.88.129 | us-east-1b | Pública 2 |
| BIND-secundario | 10.0.3.30 | 32.192.196.196 | us-east-1b | Pública 2 |
| WordPress-2 | 10.0.4.10 | (sin pública) | us-east-1b | Privada 2 |
| MariaDB | 10.0.4.20 | (sin pública) | us-east-1b | Privada 2 |

## IPs públicas para la zona DNS (registros A)

- `www` → 13.220.39.156 (HAProxy-1) y 3.83.88.129 (HAProxy-2)  ← DNS Round Robin
- `ns1` → 184.198.170.195 (BIND-primario)
- `ns2` → 32.192.196.196 (BIND-secundario)

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
