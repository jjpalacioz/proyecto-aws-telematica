# Mapa de pruebas ↔ requisitos (NAT · DNS · Balanceo)

Documento que resume qué hace cada una de las **11 pruebas** de `docs/pruebas/` y la relaciona con los **requisitos del enunciado** del Proyecto N2 (SI3002) y con los **scripts y componentes** que las hacen posibles. Es el equivalente, para este proyecto de infraestructura en AWS, de un mapa de "pruebas ↔ backlog".

**Cómo se ejecutan:** manualmente, dentro de cada EC2 por **Session Manager** o desde el computador del equipo con `dig`, `curl`, `tcpdump` y `conntrack`. No hay runner automático; la evidencia se pega el día que las máquinas estén vivas en el Learner Lab.

**Entrega:** 20 de noviembre de 2026, en la sustentación. Región `us-east-1`, cuenta AWS Academy Learner Lab.

**Tipos de prueba**

| Tipo             | Descripción                                                                     |
| ---------------- | ------------------------------------------------------------------------------- |
| NAT              | Salida a Internet desde una subred privada por la instancia NAT de su AZ.       |
| DNS              | Autoridad de BIND9, transferencia de zona, delegación y DNS Round Robin.        |
| Balanceo         | Reparto HTTP de HAProxy entre las dos WordPress y tolerancia a caída de un nodo.|
| Análisis tráfico | Captura real de IP, ICMP, TCP, DNS y HTTP (adicional a las 11 pruebas).         |

Cada prueba del enunciado lleva cinco cosas: **procedimiento, comandos, evidencia, interpretación y protocolos**. Las evidencias se guardan en `docs/pruebas/img/`.

---

## Resumen de cobertura por prueba

| Prueba | Título                                   | Estado de la plantilla | Archivos de evidencia                                      |
| ------ | ---------------------------------------- | ---------------------- | ---------------------------------------------------------- |
| N1     | Salida desde una privada                 | Documentada            | `evidencia-nat-n1.md`                                      |
| N2     | conntrack: antes y después               | Plantilla lista        | `evidencia-nat-n2.md`                                      |
| N3     | Apagar el forwarding                     | Plantilla lista        | `evidencia-nat-n3.md`                                      |
| N4     | Sale lo que nació adentro                | Plantilla lista        | — (pendiente de evidencia)                                 |
| D1     | SOA, NS, A, CNAME y la delegación        | Plantilla lista        | `evidencia-dns-d1.md`                                      |
| D2     | Cambio en el primario y transferencia    | Plantilla lista        | `evidencia-dns-d2.md`                                      |
| D3     | El primario se detiene                   | Plantilla lista        | `evidencia-dns-d3.md`                                      |
| D4     | Las dos A, el orden, el TTL y la caché   | Plantilla lista        | `evidencia-dns-d4.md`                                      |
| D5     | Se apaga un balanceador y su A sigue     | Plantilla lista        | `evidencia-dns-d5.md`                                      |
| B1     | Las dos IP privadas, por los dos HAProxy | Verificada en lab      | — (balanceo B1 verificado 18 nov)                          |
| B2     | Se apaga una WordPress                   | Plantilla lista        | — (pendiente de evidencia)                                 |

> N1 y B1 ya se validaron en la sesión del 18 nov 2026 (ver `README.md`, estado del proyecto). El resto tiene plantilla con procedimiento y comandos, pero la evidencia medida se completa cuando el dominio real y los dos BIND estén activos.

---

## Detalle por prueba

### NAT N1 — Salida desde una privada

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | La privada no tiene IP pública; su ruta `default` apunta al NAT de su AZ; `ifconfig.me` devuelve la IP pública del NAT. |
| Dónde           | WordPress-1 (`10.0.2.10`) o MariaDB (`10.0.4.20`), repetido en cada AZ.                          |
| Comandos        | `ip -4 addr`, `ip route`, `curl -4 -s https://ifconfig.me`.                                      |
| Protocolos      | IP, TCP (HTTPS al sitio externo), NAT de Linux + traducción del Internet Gateway.               |
| Requisito       | **RF-NAT.1** NAT casero (nftables) · cada privada sale por el NAT de su AZ.                      |
| Componente      | `scripts/nat/configurar-nat.sh`, ruta privada creada por `scripts/aws/lanzar-instancias.sh`.    |

---

### NAT N2 — conntrack: antes y después

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | La tupla original (`10.0.2.10:puerto`) se traduce por masquerade a `10.0.1.10:otro-puerto`; la privada 1 solo aparece en NAT-1 y la 2 en NAT-2. |
| Dónde           | En el NAT, mientras la privada de su AZ genera conexiones (`conntrack -L`).                      |
| Comandos        | Bucle de `curl` en la privada + `conntrack -L \| grep 10.0.2.10` en el NAT.                      |
| Protocolos      | IP, TCP/UDP, tabla de estado del NAT (conntrack).                                               |
| Requisito       | **RF-NAT.2** Traducción con estado (masquerade) separada por AZ.                                 |
| Componente      | `scripts/nat/configurar-nat.sh` (masquerade + conntrack).                                        |

---

### NAT N3 — Apagar el forwarding

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Con `ip_forward=0` el núcleo acepta el paquete pero no lo reenvía; la salida falla por reenvío, no por DNS ni security group. Restaura a 1 al final. |
| Dónde           | Un NAT y la privada de su misma AZ.                                                              |
| Comandos        | `sysctl -w net.ipv4.ip_forward=0`, `curl -4 -v --max-time 10 https://ifconfig.me`, restaurar a 1.|
| Protocolos      | IP (el paquete entra al NAT y no se reenvía).                                                    |
| Requisito       | **RF-NAT.3** El reenvío IP es condición necesaria del NAT por instancia.                         |
| Componente      | `scripts/nat/configurar-nat.sh` + `/etc/sysctl.d/99-nat.conf`.                                    |

---

### NAT N4 — Sale lo que nació adentro

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Tres controles: la privada no tiene IP pública, el NAT solo hace masquerade (sin DNAT), y el security group bloquea la entrada. Una conexión que nace afuera no crea entrada en conntrack. |
| Dónde           | Una privada, el NAT de su AZ y un computador fuera de AWS.                                       |
| Comandos        | `curl` y `nc -vz` desde fuera hacia la IP pública del NAT; `conntrack -L`, `nft list ruleset`.  |
| Protocolos      | IP, TCP (SYN entrante que no completa), NAT con estado.                                          |
| Requisito       | **RF-NAT.4** / **RF-SEG.1** El NAT no publica servicios hacia adentro; SSH privado no se expone. |
| Componente      | `scripts/nat/configurar-nat.sh` (sin DNAT) + security groups de `scripts/aws/crear-red.sh`.      |

---

### DNS D1 — SOA, NS, A, CNAME y la delegación

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Respuesta autoritativa (`aa`), SOA con el serial del primario, NS `ns1`/`ns2`, dos A en `www`, CNAME `inicio`→`www`, y la delegación con `+trace`. |
| Dónde           | Computador del equipo y una EC2, con `dig`.                                                      |
| Comandos        | `dig @IP_NS1 TUDOMINIO SOA/NS`, `dig @IP_NS1 www.TUDOMINIO A`, `dig TUDOMINIO NS +trace`.        |
| Protocolos      | DNS sobre UDP y TCP, IP.                                                                         |
| Requisito       | **RF-DNS.1** BIND9 autoritativo con delegación pública real (no dominio "de laboratorio").       |
| Componente      | `scripts/bind9/configurar-bind-primario.sh` (zona SOA/NS/A/CNAME).                                |

---

### DNS D2 — Cambio en el primario y transferencia

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | El secundario solo se actualiza si sube el serial; la transferencia es AXFR/IXFR por TCP 53 de `10.0.1.30` a `10.0.3.30`. |
| Dónde           | BIND primario y secundario.                                                                      |
| Comandos        | `dig SOA +norecurse` en los dos, `rndc reload`, `rndc retransfer TUDOMINIO`, `dig prueba.TUDOMINIO A`. |
| Protocolos      | DNS, TCP (la transferencia), IP dentro de la VPC.                                               |
| Requisito       | **RF-DNS.2** Transferencia de zona primario → secundario.                                        |
| Componente      | `scripts/bind9/` (`allow-transfer`/`also-notify` a `10.0.3.30`).                                  |

---

### DNS D3 — El primario se detiene

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | El secundario sigue autoritativo (`aa`) aunque el primario esté detenido; se distingue de la caché de un resolvedor recursivo. |
| Dónde           | Los dos BIND.                                                                                    |
| Comandos        | `systemctl stop named` en el primario, `dig @IP_NS2 www.TUDOMINIO A`, luego `systemctl start`.  |
| Protocolos      | DNS.                                                                                             |
| Requisito       | **RF-DNS.3** Alta disponibilidad del servicio DNS autoritativo.                                  |
| Componente      | `scripts/bind9/configurar-bind-secundario.sh` (`type secondary`).                                |

---

### DNS D4 — Las dos A, el orden, el TTL y la caché

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | La zona anuncia dos A; el servidor rota el orden (round robin DNS); el resolvedor cachea durante el TTL (60 s). Ver dos A ≠ reparto HTTP mitad y mitad. |
| Dónde           | Consultas directas al autoritativo y a un resolvedor público, repetidas.                        |
| Comandos        | `dig @IP_NS1 www.TUDOMINIO A` (x2), `dig @1.1.1.1 www.TUDOMINIO A` (x2).                         |
| Protocolos      | DNS y comportamiento de caché del resolvedor (no es HTTP).                                       |
| Requisito       | **RF-DNS.4** DNS Round Robin hacia los dos balanceadores + análisis de sus límites.              |
| Componente      | `scripts/bind9/configurar-bind-primario.sh` (dos A de `www`, TTL 60).                             |

---

### DNS D5 — Se apaga un balanceador y su A sigue

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | BIND no comprueba salud: el registro A del balanceador caído sigue anunciado hasta que venza la caché. Es la limitación de disponibilidad del Round Robin. |
| Dónde           | Un HAProxy y un BIND.                                                                            |
| Comandos        | `dig www.TUDOMINIO A`, `systemctl stop haproxy`, `dig` de nuevo, `curl` a la IP caída y a la viva. |
| Protocolos      | DNS (el anuncio sigue) y TCP/HTTP (la conexión al nodo caído no completa).                       |
| Requisito       | **RF-DNS.4** / **RF-DOC.2** Documentar que Round Robin no retira solo un nodo caído.             |
| Componente      | `scripts/bind9/` + `scripts/haproxy/configurar-haproxy.sh`.                                       |

---

### Balanceo B1 — Las dos IP privadas, por los dos HAProxy

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Cada HAProxy turna entre `10.0.2.10` y `10.0.4.10` (sin afinidad de sesión); el banner sale de PHP (`SERVER_ADDR`) con `Cache-Control: no-store`. |
| Dónde           | Computador del equipo, contra la IP pública de cada HAProxy, con `curl`.                         |
| Comandos        | Bucles de `curl -4 -s http://IP_PUBLICA_HAPROXY_N/ \| grep -o "10\.0\.[0-9.]*"`.                 |
| Protocolos      | HTTP sobre TCP (balanceo de capa de aplicación).                                                 |
| Requisito       | **RF-BAL.1** Balanceo HTTP casero (HAProxy), no ALB/NLB administrado.                             |
| Componente      | `scripts/haproxy/configurar-haproxy.sh` + mu-plugin `mostrar-ip-privada.php` de `scripts/wordpress/`. |

---

### Balanceo B2 — Se apaga una WordPress

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Al fallar el chequeo de salud, los dos HAProxy se quedan con la WordPress viva (`10.0.4.10`); el sitio sigue respondiendo. Se distingue de D5 (aquí el nodo malo se retira solo). |
| Dónde           | Las dos HAProxy y una WordPress.                                                                 |
| Comandos        | `systemctl stop apache2`, `curl http://127.0.0.1:8404/stats \| grep -E "wp1\|wp2"`, bucles de B1.|
| Protocolos      | HTTP (chequeo `GET /` y petición del usuario) y TCP.                                              |
| Requisito       | **RF-BAL.2** Alta disponibilidad por chequeo de salud y redispatch.                              |
| Componente      | `scripts/haproxy/configurar-haproxy.sh` (chequeo 3 s / 2 fallos, `option redispatch`).           |

---

### Análisis de tráfico — IP, ICMP, TCP, DNS, HTTP, NAT

| Aspecto         | Contenido                                                                                       |
| --------------- | ----------------------------------------------------------------------------------------------- |
| Qué verifica    | Captura real con `tcpdump` de: direcciones IP (privada/pública), echo request/reply (ICMP), saludo TCP de tres vías, consulta/respuesta DNS, `GET /` + `200` HTTP, y el flujo NAT antes/después de traducir. |
| Dónde           | Según el protocolo: HAProxy, WordPress, BIND primario, NAT-1.                                    |
| Comandos        | `tcpdump` por protocolo (ver `analisis-trafico.md`) + `conntrack -L`.                             |
| Protocolos      | IP, ICMP, TCP, DNS, HTTP, NAT.                                                                   |
| Requisito       | **RF-DOC.1** Análisis de tráfico real exigido por el enunciado, adicional a las 11 pruebas.      |
| Componente      | `docs/pruebas/analisis-trafico.md`.                                                               |

---

## Brechas respecto al estado actual del proyecto

| Brecha | Detalle                                                                                                              |
| ------ | ------------------------------------------------------------------------------------------------------------------- |
| **N4** | Plantilla lista, pero sin evidencia pegada: falta el intento de conexión entrante desde fuera y la ausencia de DNAT. |
| **D1** | Depende del **dominio real y la delegación** en el registrador; hasta entonces solo valida con `dig @IP` (pendiente del equipo). |
| **D2–D5** | Necesitan los dos BIND configurados con el dominio real; hoy están como plantilla con comandos.                  |
| **B2** | Verificado el balanceo base (B1), falta pegar la evidencia de la caída de una WordPress (estadísticas con un backend DOWN). |
| **Tráfico** | Faltan las capturas `tcpdump` de DNS, TCP, HTTP y NAT en `docs/pruebas/img/`.                                   |
| **Doc** | Falta pasar la evidencia medida a `docs/documento-final/documento-ieee.md` y exportar el PDF (entrega 20 nov).     |

---

## Matriz inversa rápida (requisito → prueba → componente)

```text
RF-NAT.1  Salida privada por NAT de su AZ      →  N1   →  scripts/nat/configurar-nat.sh
RF-NAT.2  Masquerade con estado por AZ         →  N2   →  scripts/nat/configurar-nat.sh
RF-NAT.3  IP forwarding habilitado             →  N3   →  scripts/nat/ + /etc/sysctl.d/99-nat.conf
RF-NAT.4  Sin DNAT (solo sale lo de adentro)   →  N4   →  scripts/nat/ + security groups
RF-DNS.1  BIND9 autoritativo + delegación      →  D1   →  scripts/bind9/configurar-bind-primario.sh
RF-DNS.2  Transferencia de zona                →  D2   →  scripts/bind9/ (allow-transfer)
RF-DNS.3  Alta disponibilidad DNS              →  D3   →  scripts/bind9/configurar-bind-secundario.sh
RF-DNS.4  DNS Round Robin (dos A)              →  D4,D5 → scripts/bind9/configurar-bind-primario.sh
RF-BAL.1  Balanceo HTTP casero (HAProxy)       →  B1   →  scripts/haproxy/configurar-haproxy.sh
RF-BAL.2  Chequeo de salud + redispatch        →  B2   →  scripts/haproxy/configurar-haproxy.sh
RF-SEG.1  SSH privado no expuesto / sin DNAT   →  N4   →  scripts/aws/crear-red.sh (security groups)
RF-DOC.1  Análisis de tráfico real             →  —    →  docs/pruebas/analisis-trafico.md
RF-DOC.2  Comparar Round Robin vs HAProxy      →  D5,B2 → docs/documento-final/documento-ieee.md
```

> Los identificadores `RF-*` son una numeración propia de este mapa para rastrear cada requisito del enunciado contra su prueba. El enunciado del curso no los numera así; se usan aquí solo como índice de trazabilidad.
