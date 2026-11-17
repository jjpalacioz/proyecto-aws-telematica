# Proyecto N2 — SI3002 Telemática

Despliegue de una aplicación web (WordPress) sobre una infraestructura de red en AWS, con alta disponibilidad y escalado horizontal.

- **Curso:** SI3002 — Despliegue de Aplicaciones y Servicios en Red
- **Fecha de entrega:** 20 de noviembre de 2026, en la sustentación, por la plataforma interactiva virtual
- **Cuenta AWS:** AWS Academy Learner Lab
- **Región:** `us-east-1` (Norte de Virginia)

La guía para el equipo, con el reparto de tareas y lo que ya está escrito, está en [`COMO-SE-HIZO.md`](COMO-SE-HIZO.md).

## Integrantes del equipo

- Juan José Palacio
- _(compañero/a de equipo)_

---

## 1. Arquitectura general

El proyecto despliega un sitio WordPress con alta disponibilidad usando:

- 1 VPC con 4 subredes (2 públicas, 2 privadas) repartidas en 2 zonas de disponibilidad.
- 2 instancias NAT caseras (nftables) — **prohibido** usar AWS NAT Gateway.
- 2 balanceadores de carga HAProxy — **prohibido** usar ALB administrado.
- 2 servidores DNS BIND9 (primario/secundario con transferencia de zona).
- 2 instancias WordPress (una por subred privada).
- 1 base de datos MariaDB compartida.
- Un dominio público real con delegación, usando DNS Round Robin hacia los dos balanceadores.

**Total: 9 instancias EC2.**

---

## 2. Direccionamiento IP

| Recurso | CIDR | Zona (AZ) |
|---|---|---|
| **VPC** | `10.0.0.0/16` | — |
| Subred **Pública 1** | `10.0.1.0/24` | `us-east-1a` |
| Subred **Privada 1** | `10.0.2.0/24` | `us-east-1a` |
| Subred **Pública 2** | `10.0.3.0/24` | `us-east-1b` |
| Subred **Privada 2** | `10.0.4.0/24` | `us-east-1b` |

---

## 3. Reparto de las 9 instancias EC2

| AZ | Subred | Instancias | IP privada sugerida |
|---|---|---|---|
| `us-east-1a` | Pública 1 (`10.0.1.0/24`) | NAT-1 | `10.0.1.10` |
| `us-east-1a` | Pública 1 | HAProxy-1 | `10.0.1.20` |
| `us-east-1a` | Pública 1 | BIND9-primario | `10.0.1.30` |
| `us-east-1a` | Privada 1 (`10.0.2.0/24`) | WordPress-1 | `10.0.2.10` |
| `us-east-1b` | Pública 2 (`10.0.3.0/24`) | NAT-2 | `10.0.3.10` |
| `us-east-1b` | Pública 2 | HAProxy-2 | `10.0.3.20` |
| `us-east-1b` | Pública 2 | BIND9-secundario | `10.0.3.30` |
| `us-east-1b` | Privada 2 (`10.0.4.0/24`) | WordPress-2 | `10.0.4.10` |
| `us-east-1b` | Privada 2 | Base de datos (MariaDB) | `10.0.4.20` |

---

## 4. Tipos de instancia (presupuesto de vCPU)

El Learner Lab tiene un límite de **32 vCPU** simultáneos.

`t3.micro` y `t3.small` tienen 2 vCPU cada uno. El total del diseño es 18 vCPU.

| Instancia | Tipo | vCPU por instancia | vCPU de la fila | RAM |
|---|---|---|---|---|
| 2× NAT | `t3.micro` | 2 | 4 | 1 GB c/u |
| 2× HAProxy | `t3.micro` | 2 | 4 | 1 GB c/u |
| 2× BIND9 | `t3.micro` | 2 | 4 | 1 GB c/u |
| 2× WordPress | `t3.small` | 2 | 4 | 2 GB c/u |
| 1× Base de datos | `t3.small` | 2 | 2 | 2 GB |
| **TOTAL** | | | **18 vCPU** | dentro de la referencia de 32 |

Todas las instancias usan **Ubuntu Server 24.04 LTS**.

---

## 5. Tablas de rutas (resumen)

| Tabla de rutas | Asociada a | Rutas |
|---|---|---|
| **Pública** | Subredes públicas 1 y 2 | `10.0.0.0/16` → local · `0.0.0.0/0` → Internet Gateway |
| **Privada AZ-a** | Subred privada 1 | `10.0.0.0/16` → local · `0.0.0.0/0` → ENI de NAT-1 |
| **Privada AZ-b** | Subred privada 2 | `10.0.0.0/16` → local · `0.0.0.0/0` → ENI de NAT-2 |

> Cada subred privada enruta su salida a Internet por la instancia NAT de **su misma AZ**.

---

## 6. Estructura del repositorio

```
proyecto-aws-telematica/
├── README.md                          <- plan corto
├── COMO-SE-HIZO.md                    <- guía del equipo y reparto de tareas
├── scripts/
│   ├── aws/                           <- VPC, security groups y las 9 EC2
│   ├── nat/                           <- NAT con nftables
│   ├── haproxy/                       <- los dos balanceadores
│   ├── bind9/                         <- primario, secundario y transferencia
│   └── wordpress/                     <- MariaDB, WordPress e IP privada
├── docs/
│   ├── pruebas/                       <- plantilla de las 11 pruebas y tráfico
│   ├── contenido-xyz.md               <- textos del sitio
│   └── documento-final/               <- borrador del documento de entrega
└── diagramas/                         <- arquitectura
```

---

## 7. Estado del proyecto

Escrito en el repositorio (falta ejecutarlo en el lab):

- [x] Plan de direccionamiento IP y reparto de instancias
- [x] Script NAT (nftables). En NAT-2: `bash configurar-nat.sh 10.0.4.0/24`
- [x] Script de VPC, rutas, security groups y lanzamiento de las 9 EC2
- [x] Config HAProxy (los dos, sin afinidad, con chequeo)
- [x] Scripts BIND9 primario/secundario
- [x] MariaDB, WordPress y la IP privada en el home
- [x] Diagrama, plantillas de las 11 pruebas y borrador del documento

Pendiente del equipo, en la cuenta y en el registrador:

- [ ] Correr la red y las 9 EC2 en el Learner Lab
- [ ] Ejecutar NAT, MariaDB, WordPress, HAProxy y BIND dentro de las instancias
- [ ] Dominio real y delegación pública
- [ ] Evidencia de N1–N4, D1–D5, B1–B2 y de las capturas de tráfico
- [ ] Documento final con nombres, figuras y resultados medidos, subido el 20 de noviembre
