# Cómo se hizo el Proyecto N2 (SI3002)

Documento para el equipo. Explica el diseño, lo que ya está escrito en este repositorio y lo que todavía hay que hacer en la cuenta de AWS, en el registrador y en la sustentación.

**Entrega:** 20 de noviembre de 2026, el día de la sustentación, por la plataforma interactiva virtual.

**Cuenta prevista:** AWS Academy Learner Lab. **Región prevista:** `us-east-1`.

**Integrantes:** Juan José Palacio y el segundo integrante (el nombre sigue vacío en `README.md`).

## Cómo leer el estado

Hay dos sitios distintos y no hay que mezclarlos.

| Marca | Significado |
|---|---|
| Hecho en el repositorio | El diseño, el script o la plantilla ya están escritos. Se puede ejecutar o copiar. |
| Pendiente del equipo | Hay que hacerlo en el Learner Lab, en el registrador, con capturas o en el documento final. |

Hoy no hay VPC, ni instancias, ni security groups, ni dominio, ni capturas, ni documento listo para subir. El repositorio es el plan, los scripts y los borradores. La nota sale de lo que el equipo deje corriendo y de lo que documente con evidencia propia.

---

## Tabla para repartir

La columna **Quién** es una propuesta para no pisarse. Se puede cruzar. Lo que no se puede mover es la fecha del dominio y la de las pruebas: el 20 es la sustentación.

| # | Tarea | Para qué | Quién | Cuándo | Depende de | Se termina cuando |
|---|---|---|---|---|---|---|
| 1 | Escribir el nombre y los códigos de los dos integrantes en `README.md` y en la portada de `docs/documento-final/documento-ieee.md` | El enunciado pide equipo de mínimo dos personas | Los dos | 17 nov | — | Los dos nombres quedan escritos |
| 2 | Conseguir un dominio o un subdominio real cuyo registrador permita DNS propio (nameservers con IP) | Sin delegación pública el bloque de DNS no cumple | Integrante 2 | 17 nov, hoy | — | El dominio aparece activo en el registrador. Los NS se apuntan el 19, cuando existan las IP públicas |
| 3 | Correr `scripts/aws/comprobar-lab.sh` | Saber la región, si existe `LabRole` y si la cuenta deja usar Elastic IP | Integrante 1 | 17 nov | Lab encendido y credenciales vigentes | Queda anotado en el documento: región, rol sí/no, Elastic IP sí/no |
| 4 | Crear la VPC, las 4 subredes, el Internet Gateway, las rutas y los security groups (`scripts/aws/crear-red.sh`, o a mano con la sección de consola de este archivo) | Sin red no hay nada que instalar | Integrante 1 | 18 nov, mañana temprano | 3 | La VPC `10.0.0.0/16` se ve en la consola y existe `scripts/aws/ids.env` |
| 5 | Lanzar las 9 EC2 con las IP de este documento (`scripts/aws/lanzar-instancias.sh`) | El tope del curso es 9 máquinas a la vez | Integrante 1 | 18 nov | 4 | `mostrar-inventario.sh` lista 9 instancias `running` |
| 6 | Quitar Source/Destination Check a NAT-1 y NAT-2, y dejar la ruta de cada privada hacia el NAT de su AZ | El script de lanzamiento ya lo hace. Si se lanzó a mano, hay que hacerlo en la consola | Integrante 1 | 18 nov | 5 | En el inventario, SourceDestCheck de los dos NAT sale `false` |
| 7 | Ejecutar el NAT dentro de las dos EC2 | Las privadas no instalan paquetes hasta que esto funciona | Integrante 1 | 18 nov | 6 | En cada NAT, `sysctl net.ipv4.ip_forward` vale 1 y `nft list ruleset` muestra `masquerade`. En NAT-2 la red es `10.0.4.0/24` |
| 8 | Instalar MariaDB en `10.0.4.20` | Es la única base, y las dos WordPress dependen de ella | Integrante 2 | 18 nov | 7 (NAT-2) | `ss` muestra `3306` y la clave coincide con la del script de WordPress |
| 9 | Instalar WordPress-1 (`ROL=primario`) y WordPress-2 (`ROL=secundario`) | El sitio y la IP privada en cada respuesta | Integrante 2 | 18 nov | 8 | `curl` local en cada una muestra su propia IP (`10.0.2.10` y `10.0.4.10`) |
| 10 | Instalar HAProxy en las dos públicas | Balanceo HTTP y prueba de caída de un WordPress | Integrante 1 | 18 nov, tarde | 9 | Varios `curl` a cada IP pública alternan las dos IP privadas |
| 11 | Anotar las 4 IP públicas (2 HAProxy y 2 BIND) y no apagar esas EC2 | Esas IP son los registros A y la delegación. Si la instancia se detiene, la IP cambia | Los dos | 18 nov | 5 | La tabla de IP públicas está escrita en el documento |
| 12 | Configurar BIND primario y secundario | DNS autoritativo y transferencia de zona | Integrante 2 | 19 nov, temprano | 11 | `dig` de SOA contra las dos IP privadas devuelve el mismo serial |
| 13 | En el registrador, delegar el dominio a `ns1` y `ns2` con las IP públicas de los BIND | Es la delegación pública que pide el enunciado | Integrante 2 | 19 nov, en cuanto 12 esté listo | 2 y 12 | Desde otra red, `dig NS tudominio +trace` muestra esos NS |
| 14 | Revisar el texto de XYZ (empresa, Medellín, Bogotá, Bucaramanga, productos) en el escritorio de WordPress | El caso de negocio no lo reemplaza la infraestructura | Integrante 2 | 19 nov | 9 | El home habla de la empresa y de las tres sedes |
| 15 | Pruebas NAT N1, N2, N3 y N4, con salida de comandos y captura | Evidencia obligatoria | Integrante 1 | 19 nov | 7 | Cuatro bloques completos en `docs/pruebas/` |
| 16 | Pruebas DNS D1, D2, D3, D4 y D5 | Evidencia obligatoria | Integrante 2 | 19 nov | 13 para D1 público; D2–D5 pueden salir con `dig @IP` aunque la delegación siga propagándose | Cinco bloques completos |
| 17 | Pruebas de balanceo B1 y B2 | Evidencia obligatoria | Integrante 1 | 19 nov | 10 | Dos bloques completos. En B2 los dos HAProxy siguen respondiendo con la WordPress que quedó viva |
| 18 | Capturas de tráfico: DNS, TCP (saludo de tres vías), HTTP y NAT. También IP e ICMP | El enunciado las pide aparte de las 11 pruebas | Quien tenga la sesión en esa máquina | 19 nov | 10 y 12 | Archivos o capturas en `docs/pruebas/img/` |
| 19 | Pasar `docs/documento-final/documento-ieee.md` a PDF: portada, índices, figuras, problemas, conclusiones, referencias IEEE | Es el entregable | Los dos | 20 nov, mañana | 15–18 | El PDF está subido a la plataforma |
| 20 | Llegar a la sustentación con el lab encendido y las 9 EC2 en `running` | Si el lab se apaga, las IP públicas cambian y el dominio deja de apuntar | Los dos | 20 nov | 5–13 | Durante la sustentación el sitio responde y `dig` sigue viendo los NS propios |

Si el 18 a mediodía las privadas todavía no salen a Internet, se para todo lo demás y se revisa el NAT. El resto de la instalación depende de ese paso.

---

## Lo que ya está en el repositorio

Esto no hay que volver a diseñarlo. Hay que ejecutarlo y entenderlo para la sustentación.

| Pieza | Dónde | Estado |
|---|---|---|
| Plan de direccionamiento, AZ e inventario de 9 EC2 | `README.md` y este archivo | Hecho en el repositorio |
| Script NAT con nftables, forwarding persistente y conntrack | `scripts/nat/configurar-nat.sh` | Hecho en el repositorio. Falta ejecutarlo en las dos EC2. En NAT-2: `bash configurar-nat.sh 10.0.4.0/24` |
| Script de la VPC, subredes, IGW, rutas y security groups | `scripts/aws/crear-red.sh` | Hecho en el repositorio. Falta correrlo en el lab |
| Lanzamiento de las 9 EC2, Source/Destination Check y rutas privadas | `scripts/aws/lanzar-instancias.sh` | Hecho en el repositorio. Falta correrlo |
| Comprobación del lab e inventario | `scripts/aws/comprobar-lab.sh`, `scripts/aws/mostrar-inventario.sh` | Hecho en el repositorio |
| HAProxy en los dos balanceadores, sin afinidad y con chequeo de salud | `scripts/haproxy/configurar-haproxy.sh` | Hecho en el repositorio. Falta ejecutarlo |
| BIND primario, zona SOA/NS/A/CNAME y BIND secundario con transferencia | `scripts/bind9/` | Hecho en el repositorio. Faltan el dominio y las IP públicas |
| MariaDB, las dos WordPress y el banner con la IPv4 privada | `scripts/wordpress/` | Hecho en el repositorio. Falta ejecutarlo |
| Textos base de XYZ S.A. | `docs/contenido-xyz.md` y las páginas que crea el script | Hecho como borrador. Falta revisarlo en el escritorio |
| Diagrama | `diagramas/arquitectura.md` | Hecho en el repositorio. Para el PDF hay que pasarlo a imagen |
| Plantilla de las 11 pruebas y del análisis de tráfico | `docs/pruebas/` | Hecho como plantilla. La evidencia está vacía a propósito |
| Borrador del documento con estructura pedida y texto técnico | `docs/documento-final/documento-ieee.md` | Hecho como borrador. Faltan nombres, capturas, resultados medidos y el PDF |
| VPC, instancias, dominio, capturas, sustentación | — | Pendiente del equipo |

El checklist viejo de `README.md` marcaba el script NAT como pendiente. El script ya estaba. El checklist quedó corregido para separar "escrito" de "ejecutado en AWS".

---

## Qué pide el enunciado

El PDF es el Proyecto N2 de SI3002, publicado el 5 de noviembre de 2026. Son 6 páginas, sin rúbrica ni puntajes. Pide publicar el sitio de **XYZ S.A.** (cosméticos, entrada a Colombia, sedes en Medellín, Bogotá y Bucaramanga) con WordPress, alta disponibilidad y escalado horizontal, sobre **exactamente 9 EC2**.

La infraestructura que hay que poder mostrar:

| Capa | Qué tiene que existir |
|---|---|
| Red | 1 VPC IPv4. 4 subredes: 2 públicas y 2 privadas, en 2 AZ de la misma región. Cada AZ lleva una pública y una privada. Internet Gateway y tablas de rutas de AWS. Cada privada sale a Internet por el NAT de su misma AZ. |
| Cada subred pública | 1 NAT + 1 balanceador (HAProxy, NGINX o Apache) + 1 BIND9 |
| Cada subred privada | 1 WordPress (Apache o NGINX, Ubuntu 24.04 o posterior) |
| Base de datos | Una sola EC2 (MariaDB o PostgreSQL) en una privada, usada por los dos WordPress |
| Tope | 9 EC2 a la vez. Bastión no es obligatorio. Administración preferible por Session Manager. SSH de las privadas no se publica a Internet. |

El enunciado trata como incumplimiento usar NAT Gateway o una AMI NAT ya hecha, usar ALB o NLB, entregar un dominio que solo exista dentro del laboratorio, o pasar de 9 EC2.

Además hay que dejar escrito:

- Cómo se comparten archivos y estado, y que la base es un único punto de falla.
- Que el DNS Round Robin no reparte parejo y no quita solo un balanceador caído, y compararlo con el balanceo HTTP.
- 11 pruebas (N1–N4, D1–D5, B1–B2). Cada una con procedimiento, comandos, evidencia, interpretación y protocolos.
- Análisis de tráfico real: IP, ICMP, TCP, DNS y HTTP, cubriendo resolución DNS, el saludo TCP, el intercambio HTTP y la traducción NAT.

El documento final lleva portada, tabla de contenido, lista de figuras, lista de tablas, introducción, arquitectura/implementación/despliegue, problemas y recomendaciones, conclusiones y referencias IEEE.

---

## Decisiones que ya están tomadas

El equipo las puede explicar. No hace falta volver a discutirlas el 18 de noviembre.

1. **Región `us-east-1`, AZ `us-east-1a` y `us-east-1b`.** El Learner Lab suele estar en esa región. `comprobar-lab.sh` lo confirma antes de crear nada. Si el lab estuviera en otra región, se cambian las AZ y se mantiene el mismo esquema de dos AZ.
2. **Una sola VPC `10.0.0.0/16`.** Cabe el direccionamiento privado del enunciado (RFC 1918) y deja las cuatro `/24` con espacio de sobra.
3. **NAT con Ubuntu 24.04 y nftables**, hecho por el equipo. IP forwarding persistente, masquerade de la privada de esa AZ, conntrack instalado, Source/Destination Check desactivado en AWS.
4. **Balanceo con HAProxy**, uno por subred pública. Cada uno conoce las dos WordPress. Round-robin, chequeo HTTP, sin cookie de sesión y sin caché.
5. **DNS con BIND9** primario/secundario y transferencia de zona. `www` tiene dos registros A. Hay un CNAME `inicio` para la prueba D1.
6. **MariaDB** en la privada 2 (`10.0.4.20`). Una sola instancia, como pide el enunciado.
7. **WordPress sobre Apache**, en español, con un mu-plugin que imprime la IPv4 privada de la EC2 que generó esa respuesta.
8. **Session Manager** como administración. El puerto 22 no se abre.
9. **Textos del sitio en la base de datos**, iguales para las dos WordPress. Las imágenes subidas no se comparten, y el sitio de la demo no depende de ellas.
10. **TTL de 60 segundos** en la zona, solo para el laboratorio, para que D2, D4 y D5 no se queden pegadas a una caché de horas.

---

## Direccionamiento y las 9 máquinas

| Recurso | CIDR o IP | AZ | Sale a Internet por |
|---|---|---|---|
| VPC | `10.0.0.0/16` | — | — |
| Pública 1 | `10.0.1.0/24` | `us-east-1a` | Internet Gateway |
| NAT-1 | `10.0.1.10` | `us-east-1a` | Internet Gateway |
| HAProxy-1 | `10.0.1.20` | `us-east-1a` | Internet Gateway |
| BIND primario | `10.0.1.30` | `us-east-1a` | Internet Gateway |
| Privada 1 | `10.0.2.0/24` | `us-east-1a` | NAT-1 |
| WordPress-1 | `10.0.2.10` | `us-east-1a` | NAT-1 |
| Pública 2 | `10.0.3.0/24` | `us-east-1b` | Internet Gateway |
| NAT-2 | `10.0.3.10` | `us-east-1b` | Internet Gateway |
| HAProxy-2 | `10.0.3.20` | `us-east-1b` | Internet Gateway |
| BIND secundario | `10.0.3.30` | `us-east-1b` | Internet Gateway |
| Privada 2 | `10.0.4.0/24` | `us-east-1b` | NAT-2 |
| WordPress-2 | `10.0.4.10` | `us-east-1b` | NAT-2 |
| MariaDB | `10.0.4.20` | `us-east-1b` | NAT-2 |

Rutas:

| Tabla | Asociada a | Rutas |
|---|---|---|
| Pública | `10.0.1.0/24` y `10.0.3.0/24` | `10.0.0.0/16` local. `0.0.0.0/0` al Internet Gateway |
| Privada AZ-a | `10.0.2.0/24` | `10.0.0.0/16` local. `0.0.0.0/0` a la instancia NAT-1 |
| Privada AZ-b | `10.0.4.0/24` | `10.0.0.0/16` local. `0.0.0.0/0` a la instancia NAT-2 |

La ruta `10.0.0.0/16 → local` la crea AWS sola en cada tabla. El tráfico entre HAProxy y WordPress, y entre WordPress y MariaDB, usa esa ruta. **No pasa por el NAT.** El NAT solo entra cuando el destino está fuera de la VPC.

### Tipos de instancia y vCPU

`t3.micro` y `t3.small` tienen **2 vCPU** cada uno. El cuadro viejo del README sumaba 12 porque contaba el `t3.micro` como si tuviera 1. El número que hay que usar es este:

| Instancias | Tipo | vCPU de cada una | vCPU de la fila | RAM |
|---|---|---|---|---|
| 2 NAT | `t3.micro` | 2 | 4 | 1 GB |
| 2 HAProxy | `t3.micro` | 2 | 4 | 1 GB |
| 2 BIND | `t3.micro` | 2 | 4 | 1 GB |
| 2 WordPress | `t3.small` | 2 | 4 | 2 GB |
| 1 MariaDB | `t3.small` | 2 | 2 | 2 GB |
| **9 EC2** | | | **18 vCPU** | |

18 está por debajo del límite de 32 vCPU que se venía usando como referencia del Learner Lab. El límite que de verdad importa el día del despliegue es el de la cuenta: no lanzar una décima EC2.

Todas las AMI son **Ubuntu Server 24.04 LTS**.

---

## Orden real de montaje

El orden importa. Una privada sin NAT no puede hacer `apt` ni registrarse en Session Manager, porque las dos cosas salen a Internet.

1. Confirmar región, rol y Elastic IP.
2. Crear la red y los security groups.
3. Lanzar las 9 EC2. Quitar Source/Destination Check a los NAT. Poner las rutas privadas.
4. Entrar por Session Manager a **NAT-1 y NAT-2** (tienen IP pública, no necesitan el NAT para existir) y ejecutar el script de nftables.
5. Recién ahí, MariaDB y las dos WordPress.
6. Los dos HAProxy.
7. Anotar IP públicas. Configurar BIND. Delegar en el registrador.
8. Las 11 pruebas y las capturas de tráfico.
9. El PDF.

HAProxy y BIND están en subredes públicas: su `apt` sale por el Internet Gateway, no por el NAT. Se pueden instalar en paralelo con la base, pero HAProxy conviene dejarlo para cuando WordPress ya responde, y BIND para cuando las cuatro IP públicas ya están anotadas.

---

## Cómo está hecha cada capa

### Red (AWS)

`scripts/aws/crear-red.sh` crea la VPC, las cuatro subredes, el Internet Gateway, la tabla pública con `0.0.0.0/0` hacia el IGW, y dos tablas privadas asociadas pero todavía sin ruta por defecto. Activa DNS hostnames en la VPC. En las subredes públicas enciende la asignación automática de IP pública. En las privadas no.

`scripts/aws/lanzar-instancias.sh` lee `ids.env`, lanza las 9 máquinas con la IP privada de la tabla, adjunta el instance profile `LabRole` (si existe; se puede desactivar con `INSTANCE_PROFILE=`), espera a que estén `running`, desactiva Source/Destination Check en los dos NAT y crea la ruta `0.0.0.0/0` de cada privada hacia el NAT de su AZ.

Si se corren otra vez, buscan el tag `Project=si3002-n2` y no duplican la VPC ni las instancias. El tope de 9 se respeta por eso.

El puerto 22 no se abre en ningún security group.

**Si CloudShell o la CLI fallan**, la misma red se puede armar en la consola. El diseño no cambia:

1. VPC → Create VPC → VPC only → nombre `si3002-vpc` → IPv4 `10.0.0.0/16`.
2. En la VPC, activar DNS hostnames.
3. Crear las cuatro subredes con el CIDR y la AZ de la tabla. En las dos públicas: Actions → Edit subnet settings → Auto-assign public IPv4.
4. Internet Gateway → Create → Attach to this VPC.
5. Route tables: una pública asociada a las dos públicas, con ruta `0.0.0.0/0` al Internet Gateway. Dos privadas, cada una asociada a su subred privada. La ruta `0.0.0.0/0` de cada privada se agrega **después** de tener el NAT, y el target es la instancia NAT (no un NAT Gateway).
6. Security groups como en la tabla de más abajo.
7. Launch instances, Ubuntu Server 24.04, el tipo de la tabla, la subred correcta, el security group correcto. En Advanced details: instance profile `LabRole` si aparece, y la IP privada de la tabla. En las privadas, no asignar IP pública.
8. En NAT-1 y NAT-2: Actions → Networking → Change source/destination check → Stop.

Si la consola obliga a elegir un key pair, se crea y se guarda. Aun así el puerto 22 se queda cerrado. La entrada de administración es Session Manager.

### Security groups

El script los crea así. La salida queda en la regla por defecto (permite salir). El security group de AWS es con estado: la respuesta de una conexión que salió puede volver sin una regla de entrada.

| Grupo | Entrada | Por qué |
|---|---|---|
| NAT-1 | Todo desde `10.0.2.0/24`. ICMP desde `10.0.0.0/16` | Solo la privada de su AZ le entrega tráfico para traducir |
| NAT-2 | Todo desde `10.0.4.0/24`. ICMP desde `10.0.0.0/16` | Igual, para la otra AZ |
| HAProxy | TCP 80 desde `0.0.0.0/0`. ICMP desde la VPC | El sitio es público. El balanceo es HTTP, no un balanceador de AWS |
| BIND | TCP 53 y UDP 53 desde `0.0.0.0/0`. ICMP desde la VPC | Tiene que responder consultas públicas. La transferencia de zona usa TCP 53 |
| WordPress | TCP 80 solo desde `10.0.1.20/32` y `10.0.3.20/32` | Solo los dos balanceadores hablan con Apache |
| MariaDB | TCP 3306 solo desde `10.0.2.10/32` y `10.0.4.10/32` | Solo las dos WordPress hablan con la base |

ICMP desde la VPC está abierto a propósito: el enunciado pide analizar ICMP, y un ping entre máquinas de la VPC tiene que poder verse.

Las listas de control de red (NACL) se dejan en el permiso por defecto. Cerrarlas es la forma más rápida de dejar la VPC incomunicada.

### NAT, y las dos traducciones

El script `scripts/nat/configurar-nat.sh` hace, en la EC2 NAT:

1. `net.ipv4.ip_forward=1`, también en `/etc/sysctl.d/99-nat.conf` para que sobreviva un reinicio.
2. Instala `nftables` y `conntrack`.
3. En la cadena de postrouting, enmascara con `masquerade` lo que venga de la red privada y salga por la interfaz de esa instancia.
4. Guarda las reglas en `/etc/nftables.conf` y habilita el servicio.

En NAT-1 la red es `10.0.2.0/24`. En NAT-2 hay que pasar `10.0.4.0/24`.

Eso solo funciona si AWS dejó de descartar el tráfico que no va dirigido a la propia instancia. Por eso Source/Destination Check va en **Stop**. Sin ese clic, el forwarding y nftables no alcanzan a ver los paquetes.

Hay **dos traducciones distintas** en la salida de una privada. El enunciado pide diferenciarlas.

```
WordPress-1  10.0.2.10:puerto-alto
        |  ruta 0.0.0.0/0 de la privada 1  ->  instancia NAT-1
        v
NAT-1  (Linux, nftables masquerade, tabla conntrack)
        el origen pasa a ser la IP privada del NAT: 10.0.1.10:otro-puerto
        |  NAT-1 está en una subred pública y tiene IP pública
        v
Internet Gateway de AWS
        presenta 10.0.1.10 como la IP pública de NAT-1
        v
El servidor de Internet ve la IP pública de NAT-1
```

- **nftables** traduce la IP de la máquina privada a la IP privada del NAT, y cambia el puerto. `conntrack` recuerda esa pareja para devolver la respuesta. Esto se ve en la prueba N2, dentro de la EC2 NAT.
- **El Internet Gateway** hace el paso que AWS hace con cualquier EC2 que tiene IP pública: la IP privada de esa EC2 (aquí, la del NAT) se ve afuera como su IP pública. El Internet Gateway no conoce a `10.0.2.10`. Para él, el cliente es el NAT.

No hay regla de DNAT. Una conexión que nace afuera no tiene una entrada previa en conntrack y no se reenvía hacia la privada. Eso, junto con la ausencia de IP pública en la privada y con el security group, es la prueba N4.

N3 apaga el forwarding (`sysctl -w net.ipv4.ip_forward=0`). El NAT recibe el paquete y no lo reenvía. La prueba tiene que volver a dejarlo en 1 antes de seguir, porque si no MariaDB y WordPress se quedan sin `apt` y sin Session Manager.

### Base de datos y estado compartido

`scripts/wordpress/configurar-mariadb.sh` instala MariaDB en `10.0.4.20`, lo pone a escuchar en `0.0.0.0:3306` y crea el usuario `wordpress` solo para `10.0.2.10` y `10.0.4.10`. La clave está al inicio del script y **tiene que ser la misma** en `configurar-wordpress.sh`. Conviene cambiarla antes de ejecutarlos si el repositorio se va a compartir.

Qué está compartido:

| Dato | Dónde vive | Qué pasa |
|---|---|---|
| Páginas, entradas, usuarios, opciones, comentarios | MariaDB `10.0.4.20` | Las dos WordPress leen y escriben lo mismo |
| Código de WordPress, tema y el mu-plugin de la IP | Disco local de cada EC2 | El script lo instala en las dos. Tiene que quedar igual |
| Salts de `wp-config.php` | Las dos EC2 | Van fijas e iguales en el script, para que una cookie sirva en cualquiera de las dos |
| `wp-content/uploads` | Disco local de la EC2 donde se subió el archivo | **No se comparte.** Una foto subida en WordPress-1 da 404 cuando la petición la atiende WordPress-2 |

Por eso el sitio de demostración usa texto guardado en la base y no depende de una imagen subida. Hay que decirlo en el documento con esas palabras.

Punto único de falla: si se apaga `10.0.4.20`, o se cae la AZ `us-east-1b`, las dos WordPress siguen encendidas y los dos HAProxy también pueden estarlo, pero el sitio deja de armarse porque no hay base. El enunciado obliga a una sola EC2 de base, así que esto se documenta. No se "arregla" con una segunda base, porque serían 10 EC2.

Recomendación para la sección de problemas, sin implementarla: una réplica en la otra AZ, o un almacenamiento compartido para `uploads`. Las dos cosas se salen del tope o del enunciado si sustituyen la EC2 única. Se dejan como trabajo futuro.

### WordPress y la IP privada en cada respuesta

`configurar-wordpress.sh` se corre dos veces.

- En `10.0.2.10`, `ROL=primario`. Descarga WordPress en español, crea `wp-config.php`, instala el sitio, crea las páginas Inicio, La empresa, Sedes, Productos y Contacto, y deja Inicio como portada.
- En `10.0.4.10`, `ROL=secundario`. Mismo código y misma base. No vuelve a instalar, porque pisaría el sitio.

El archivo `wp-content/mu-plugins/mostrar-ip-privada.php` hace tres cosas en cada petición:

1. Lee `$_SERVER['SERVER_ADDR']`, que es la IPv4 de la EC2 donde corre Apache, y la imprime en un recuadro al inicio de la página.
2. Manda `Cache-Control: no-store` y un encabezado `X-Servidor-Privado`.
3. Desactiva la redirección canónica de WordPress, para que un `curl` directo a la IP de un HAProxy no salte al otro balanceador por el nombre `www`.

Apache, además, activa `mod_headers` con el mismo `Cache-Control`. No se instala ningún plugin de caché.

`WP_HOME` sigue al encabezado `Host` de esa petición. Así la prueba B1 puede pegarle a cada balanceador por su IP.

La clave de administrador queda al inicio del script (`WP_ADMIN_USER`, por defecto `adminxyz`). Hay que anotarla y cambiarla si el repo se publica.

### HAProxy, y en qué se diferencia del DNS Round Robin

El mismo `scripts/haproxy/configurar-haproxy.sh` se ejecuta en `10.0.1.20` y en `10.0.3.20`. Los dos archivos quedan iguales: cada balanceador tiene los backends `10.0.2.10` y `10.0.4.10`.

Decisiones metidas en la configuración, y por qué:

| Decisión | Para qué prueba |
|---|---|
| `balance roundrobin` | B1: las peticiones seguidas van turnándose |
| No hay línea `cookie` | Una afinidad de sesión escondería el turno y B1 fallaría |
| `option http-server-close` | Sin esto, varias peticiones por la misma conexión TCP se quedan en el mismo WordPress |
| Chequeo `GET /` cada 3 s, dos fallos lo sacan | B2: al apagar un WordPress, los dos HAProxy se quedan con el que responde |
| `option redispatch` y 3 reintentos | Una petición que cae en el servidor que acaba de morir se manda al otro |
| Estadísticas solo en `127.0.0.1:8404` | Se pueden mirar por Session Manager y no se publican a Internet |

Comparación que hay que saberse para el documento y para la sustentación:

| | DNS Round Robin | HAProxy |
|---|---|---|
| Qué reparte | El nombre `www`. Devuelve dos direcciones A | La petición HTTP, entre las dos WordPress |
| Quién elige | El resolvedor y la caché del cliente, según orden y TTL | El balanceador, en cada petición |
| ¿Reparte parejo? | No hay garantía. Un resolvedor puede entregar siempre la misma A mientras dure el TTL | En esta configuración, turna petición por petición entre los backends que estén sanos |
| Si se apaga un nodo | El registro A sigue anunciado. Parte de los clientes sigue intentando la IP muerta hasta que venza la caché. Es la prueba D5 | El chequeo de salud saca al WordPress caído. Los dos balanceadores siguen respondiendo con el que queda. Es la prueba B2 |
| Qué no prueba | Ver las dos A con `dig` no prueba que las conexiones HTTP se repartan mitad y mitad. Es la aclaración de D4 | Ver la IP privada en el home sí prueba qué WordPress atendió esa petición HTTP |

Los dos mecanismos se usan juntos y hacen trabajos distintos. Round Robin elige **cuál balanceador** recibe al cliente. HAProxy elige **cuál WordPress** atiende esa petición. Que uno funcione no demuestra el otro.

### DNS

`configurar-bind-primario.sh` se edita antes de correrlo. Hay que llenar:

- `DOMINIO` (real, sin `www` y sin `http://`)
- IP pública del BIND secundario
- IP pública de HAProxy-1
- IP pública de HAProxy-2

La IP pública del propio primario la detecta con `curl -4 https://ifconfig.me` si se deja vacía.

La zona que escribe:

- SOA con serial `AAAAMMDD01` y TTL 60.
- NS `ns1` y `ns2`.
- A de `ns1` y `ns2` hacia las IP **públicas** de los BIND.
- Dos A del dominio y dos A de `www` hacia las IP **públicas** de los HAProxy.
- CNAME `inicio` hacia `www`.

`allow-transfer` y `also-notify` apuntan a la IP **privada** del secundario (`10.0.3.30`). La transferencia viaja por dentro de la VPC.

El secundario no tiene una copia editada a mano. Declara la zona como `type secondary`, guarda el archivo en `/var/cache/bind` (ahí AppArmor deja escribir) y pide la zona con `rndc retransfer`.

Los dos servidores van con `recursion no`. Son autoritativos de esta zona. No resuelven el resto de Internet para los clientes.

**Delegación.** En el registrador, los servidores de nombres del dominio quedan en `ns1.tudominio` y `ns2.tudominio`, con las IP públicas de las dos EC2 BIND (registros glue). Hasta que eso no esté, `dig @IP-del-BIND` funciona y un `dig` normal desde un celular no: el mundo sigue preguntándole a los DNS del registrador.

Un nombre que solo resuelva dentro de una máquina, o un dominio "de mentira" sin delegación, el enunciado lo rechaza.

Para la prueba D2 se edita la zona en el primario, se sube el serial, `rndc reload`, y en el secundario `rndc retransfer`. Si el serial no cambia, el secundario no se entera.

Para D3 se detiene el servicio en el primario (`systemctl stop named`) y el secundario sigue respondiendo con la bandera autoritativa. Después se vuelve a arrancar. Hay que distinguir eso de un resolvedor público: el resolvedor puede seguir entregando la respuesta desde su caché aunque los dos autoritativos estuvieran caídos. Por eso D3 se hace con `dig @IP-del-secundario`, que no usa esa caché.

### Contenido del sitio

El caso es la empresa, no solo la red. El script crea cinco páginas con un texto corto. `docs/contenido-xyz.md` trae una versión más larga para pegar en el escritorio si quieren enriquecerla: compañía, sede principal en Medellín (centro de datos on-premise), sedes en Bogotá y Bucaramanga, y tres líneas de producto inventadas para la demo (Agua, Sol y Color). No usan marcas reales.

### Administración

Camino previsto:

1. EC2 → seleccionar la instancia → Connect → Session Manager.
2. Las seis máquinas públicas aparecen cuando el agente SSM arranca y el rol está adjunto. Suele tardar uno o dos minutos.
3. Las tres privadas aparecen cuando, además, el NAT de su AZ ya traduce. El agente sale a Internet por ese NAT (HTTPS hacia los servicios de SSM). No hace falta un bastión ni un VPC endpoint. Si la cuenta dejara crear endpoints de interfaz, el enunciado los permite, pero con 9 EC2 ya en el tope no hace falta.

Si Session Manager no ofrece conexión en una pública: revisar que la instancia tenga `LabRole` (o el perfil que el lab sí deje usar) y que el security group permita salir. Si no aparece en una privada: revisar primero N1 desde esa privada. Sin salida a Internet, SSM no registra.

---

## Pruebas y documento

La plantilla de las 11 pruebas, con procedimiento, comandos, hueco para la evidencia, interpretación esperada y protocolos, está en `docs/pruebas/plantilla-11-pruebas.md`.

El análisis de IP, ICMP, TCP, DNS, HTTP y NAT está en `docs/pruebas/analisis-trafico.md`.

El borrador del entregable, con la estructura que pide el PDF y el texto técnico ya redactado, está en `docs/documento-final/documento-ieee.md`. Los resultados medidos están marcados como pendientes. No se inventan capturas. El archivo se pasa a Word o a PDF, se pegan las figuras y se sube el 20.

El diagrama de arquitectura, el de la petición HTTP y el de las dos traducciones NAT están en `diagramas/arquitectura.md`. Para el PDF hay que exportarlos a imagen (captura o la herramienta que usen).

---

## Riesgos que ya se conocen

| Riesgo | Qué hacer |
|---|---|
| El lab se detiene o alguien apaga una EC2 pública | La IP pública cambia. Hay que actualizar la zona BIND y la delegación, o el sitio y el DNS dejan de coincidir. Después de delegar, esas cuatro instancias no se apagan hasta pasada la sustentación |
| La cuenta no deja crear Elastic IP | Se trabaja con las IP públicas automáticas y se acepta el riesgo de arriba. Queda escrito en el documento. El 17 se comprueba |
| `LabRole` no se puede adjuntar | Las públicas se administran por EC2 Instance Connect, abriendo el 22 solo desde la IP del equipo y cerrándolo al terminar. Las privadas siguen sin 22 hacia Internet. Sin rol y sin NAT, Session Manager no entra a las privadas |
| La delegación DNS se hace el jueves en la noche | Puede no propagarse para el viernes. El dominio se compra el 17 y los NS se cambian el 19 en la mañana |
| Se lanza una EC2 de más "para probar" | El enunciado fija el máximo en 9 simultáneas. Se termina lo que sobre antes de seguir |
| Las dos WordPress no tienen la misma clave de base o las mismas salts | Una de las dos no conecta, o el escritorio solo funciona en una. Las variables de los dos scripts se editan juntas |
| Se sube una imagen en una sola WordPress | Se ve en un refresco y en el siguiente no. El contenido de la demo es texto |
| N3 se queda con el forwarding en 0 | Se cae la salida de esa AZ. El script y la plantilla dicen que hay que restaurarlo |
| Caché del navegador o del resolvedor | B1 se hace con `curl`, que no guarda la página. D4 se mira el TTL y se explica que la caché no es un reparto HTTP |

---

## Lo que hay que poder explicar el 20

Cada integrante tiene que poder decirlo sin leer el script entero.

1. Por qué hay cuatro subredes y por qué la privada 1 no sale por NAT-2.
2. La diferencia entre el masquerade de Linux y el Internet Gateway.
3. Qué pasa si Source/Destination Check sigue activo.
4. Qué estado está en MariaDB, qué archivos no se comparten, y qué se cae si muere la base.
5. Por qué la IP del home sale de PHP en cada petición, y qué se apagó (caché y afinidad) para que B1 se vea.
6. Por qué cada HAProxy conoce las dos WordPress, incluida la de la otra AZ.
7. Por qué `dig` de las dos A de `www` no demuestra un reparto parejo de HTTP, y por qué al apagar un HAProxy su registro A sigue existiendo.
8. Cómo se ve que el secundario recibió la zona (mismo serial, respuesta autoritativa con el primario apagado).
9. Por qué el SSH de las privadas no está en Internet y cómo se entra entonces.
10. Qué se haría después del curso con la base única y con los uploads, sin afirmar que eso ya está desplegado.

---

## Mapa de archivos

```
COMO-SE-HIZO.md                         este archivo
README.md                               plan corto y checklist
PDF-ProyectoDespliegueServicio-2026.pdf enunciado
scripts/aws/                            comprobar, crear red, lanzar, inventario
scripts/nat/                            nftables
scripts/haproxy/                        los dos balanceadores
scripts/bind9/                          primario y secundario
scripts/wordpress/                      MariaDB y las dos WordPress
diagramas/arquitectura.md               diagramas
docs/pruebas/plantilla-11-pruebas.md    N1–N4, D1–D5, B1–B2
docs/pruebas/analisis-trafico.md        IP, ICMP, TCP, DNS, HTTP, NAT
docs/pruebas/img/                       aquí van las capturas
docs/contenido-xyz.md                   textos para el sitio
docs/documento-final/documento-ieee.md  borrador del entregable
```

`scripts/aws/ids.env` lo genera `crear-red.sh` en el lab. Está en `.gitignore` porque identifica recursos de la cuenta.
