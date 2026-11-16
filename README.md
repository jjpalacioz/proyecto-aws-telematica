# Proyecto N2 — SI3002 Telemática

Despliegue de una aplicación web (WordPress) sobre una infraestructura de red en AWS, con alta disponibilidad y escalado horizontal.

- **Curso:** SI3002 — Despliegue de Aplicaciones y Servicios en Red
- **Fecha de entrega:** 20 de noviembre de 2026
- **Cuenta AWS:** AWS Academy Learner Lab
- **Región:** `us-east-1` (Norte de Virginia)

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

| Instancia | Tipo | vCPU | RAM |
|---|---|---|---|
| 2× NAT | `t3.micro` | 2 | 1 GB c/u |
| 2× HAProxy | `t3.micro` | 2 | 1 GB c/u |
| 2× BIND9 | `t3.micro` | 2 | 1 GB c/u |
| 2× WordPress | `t3.small` | 4 | 2 GB c/u |
| 1× Base de datos | `t3.small` | 2 | 2 GB |
| **TOTAL** | | **12 vCPU** | ✅ < 32 |

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
├── README.md              <- este archivo (plan maestro)
├── scripts/
│   ├── nat/               <- configuración NAT con nftables
│   ├── haproxy/           <- configuración de los balanceadores
│   ├── bind9/             <- zonas DNS (primario y secundario)
│   └── wordpress/         <- user-data e IP-privada en el home
├── docs/
│   ├── pruebas/           <- evidencia de las 10 pruebas obligatorias
│   └── documento-final/   <- documento IEEE de entrega
└── diagramas/             <- diagrama de arquitectura
```

---

## 7. Estado del proyecto

- [x] Plan de direccionamiento IP
- [x] Reparto de instancias
- [ ] Scripts NAT (nftables)
- [ ] Config HAProxy
- [ ] Zonas BIND9
- [ ] user-data WordPress + IP privada en home
- [ ] Creación de VPC y subredes en AWS
- [ ] Lanzamiento de las 9 EC2
- [ ] Security Groups
- [ ] Dominio + DNS Round Robin
- [ ] Pruebas NAT (N1–N4)
- [ ] Pruebas DNS (D1–D5)
- [ ] Pruebas Balanceo (B1–B2)
- [ ] Documento final IEEE
