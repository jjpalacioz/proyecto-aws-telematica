# Documento final — borrador

Este archivo es el borrador del entregable. Tiene la estructura que pide el enunciado y el texto técnico del diseño. **No está listo para subirse.** Faltan los nombres y códigos, las figuras exportadas, las capturas y los resultados medidos en el laboratorio. Esos huecos están entre corchetes. No se rellenan con números inventados.

Para la entrega del 20 de noviembre de 2026 se pasa a Word o a PDF. Con estilos de título, el procesador arma solo la tabla de contenido, la lista de figuras y la lista de tablas. La plataforma de subida es la plataforma interactiva virtual, el día de la sustentación.

Universidad: [UNIVERSIDAD]. Curso: SI3002 — Despliegue de Aplicaciones y Servicios en Red. Proyecto N2.

---

## Página de presentación

**Título:** Despliegue del sitio web de XYZ S.A. sobre una infraestructura de red en AWS, con alta disponibilidad y escalado horizontal.

**Curso:** SI3002.

**Estudiantes:**

- Juan José Palacio — código [CÓDIGO]
- [NOMBRE DEL SEGUNDO INTEGRANTE] — código [CÓDIGO]

**Fecha:** 20 de noviembre de 2026.

**Cuenta:** AWS Academy Learner Lab. Región: [confirmar; el diseño usa us-east-1].

---

## Tabla de contenido

Al pasar el documento a Word, generar este índice desde los títulos. El orden es el de las secciones siguientes: introducción; arquitectura, implementación y despliegue; pruebas; aspectos encontrados; conclusiones; referencias.

## Lista de figuras

1. Arquitectura lógica de la VPC y las nueve EC2. Origen: `diagramas/arquitectura.md`, exportada a imagen.
2. Secuencia de una petición HTTP de un visitante.
3. Las dos traducciones de una salida a Internet desde una subred privada.
4. Consola de AWS con la VPC, las cuatro subredes y las tablas de rutas. [PENDIENTE: captura]
5. Inventario de las nueve instancias con IP privada e IP pública. [PENDIENTE: captura]
6. Source/Destination Check desactivado en las dos instancias NAT. [PENDIENTE: captura]
7. Evidencias de las pruebas N1–N4, D1–D5 y B1–B2. [PENDIENTE: una figura por prueba, o las que el equipo decida numerar]
8. Capturas de tcpdump de DNS, del saludo TCP, de HTTP y de NAT. [PENDIENTE]

## Lista de tablas

1. Direccionamiento de la VPC y de las cuatro subredes.
2. Inventario de las nueve EC2.
3. Tablas de rutas.
4. Security groups.
5. Registros de la zona DNS.
6. Estado compartido y punto único de falla.
7. Comparación entre DNS Round Robin y HAProxy.
8. Resultados de las once pruebas. [PENDIENTE: se llena con lo medido]

---

## 1. Introducción

XYZ S.A. es una compañía de cosméticos con presencia en América Latina que entra al mercado colombiano con sedes en Medellín, Bogotá y Bucaramanga. El centro de datos de la sede principal queda en Medellín y allí siguen aplicaciones de la operación propia. El sitio público, con la información de la empresa y de sus productos, se le pidió al equipo desplegarlo en un operador de nube, de forma que varios visitantes puedan usarlo al mismo tiempo y que el servicio web pueda crecer de manera horizontal.

El trabajo diseña, implementa y despliega ese sitio con WordPress sobre Amazon Web Services. La infraestructura usa una VPC, dos zonas de disponibilidad, salida a Internet mediante NAT implementado por el equipo, balanceo HTTP implementado por el equipo y DNS autoritativo en BIND9. El tope es de nueve instancias EC2 simultáneas. El enunciado del proyecto es el documento del 5 de noviembre de 2026 del curso SI3002, con entrega el 20 de noviembre de 2026.

El alcance de este documento cubre el direccionamiento, las rutas, los flujos, el inventario, las decisiones de implementación, las pruebas obligatorias y los problemas encontrados. [PENDIENTE: una frase con el resultado global, escrita después de las pruebas. Ejemplo de forma, no de contenido: "Las once pruebas se ejecutaron el día [fecha] sobre la cuenta del laboratorio."]

---

## 2. Arquitectura, implementación y despliegue

### 2.1 Direccionamiento

Se usa una VPC IPv4 `10.0.0.0/16` en [us-east-1]. Las direcciones `10.0.0.0/8` son privadas [8]. Hay cuatro subredes `/24`, dos por zona de disponibilidad. En cada zona hay una subred pública y una privada.

**Tabla 1. Subredes**

| Subred | CIDR | Zona | Uso |
|---|---|---|---|
| Pública 1 | 10.0.1.0/24 | us-east-1a | NAT-1, HAProxy-1, BIND primario |
| Privada 1 | 10.0.2.0/24 | us-east-1a | WordPress-1 |
| Pública 2 | 10.0.3.0/24 | us-east-1b | NAT-2, HAProxy-2, BIND secundario |
| Privada 2 | 10.0.4.0/24 | us-east-1b | WordPress-2 y MariaDB |

### 2.2 Inventario

Todas las instancias usan Ubuntu Server 24.04 LTS. `t3.micro` y `t3.small` aportan 2 vCPU cada uno. El total del diseño es 18 vCPU, dentro de una referencia de 32 vCPU del laboratorio. [PENDIENTE: anotar la cuota que mostró la cuenta.]

**Tabla 2. Nueve EC2**

| Nombre | IP privada | Subred | Tipo | Rol |
|---|---|---|---|---|
| NAT-1 | 10.0.1.10 | Pública 1 | t3.micro | NAT de la zona A |
| HAProxy-1 | 10.0.1.20 | Pública 1 | t3.micro | Balanceo HTTP |
| BIND primario | 10.0.1.30 | Pública 1 | t3.micro | DNS autoritativo primario |
| WordPress-1 | 10.0.2.10 | Privada 1 | t3.small | CMS, Apache y PHP |
| NAT-2 | 10.0.3.10 | Pública 2 | t3.micro | NAT de la zona B |
| HAProxy-2 | 10.0.3.20 | Pública 2 | t3.micro | Balanceo HTTP |
| BIND secundario | 10.0.3.30 | Pública 2 | t3.micro | DNS autoritativo secundario |
| WordPress-2 | 10.0.4.10 | Privada 2 | t3.small | CMS, Apache y PHP |
| MariaDB | 10.0.4.20 | Privada 2 | t3.small | Base única |

Las IP públicas de NAT-1, NAT-2, HAProxy-1, HAProxy-2, BIND primario y BIND secundario se anotan el día del despliegue, porque el laboratorio las asigna al arrancar. [PENDIENTE: tabla de IP públicas medidas.] Las tres instancias privadas no tienen IP pública.

Identificadores de instancia, id de la VPC, id del Internet Gateway e id de las tablas de rutas: [PENDIENTE, copiar de `scripts/aws/ids.env` y de la consola].

### 2.3 Rutas

AWS agrega en cada tabla la ruta local `10.0.0.0/16`. El equipo agrega la ruta por defecto.

**Tabla 3. Rutas**

| Tabla | Subredes | Ruta por defecto |
|---|---|---|
| Pública | 10.0.1.0/24 y 10.0.3.0/24 | 0.0.0.0/0 hacia el Internet Gateway |
| Privada de la zona A | 10.0.2.0/24 | 0.0.0.0/0 hacia la instancia NAT-1 |
| Privada de la zona B | 10.0.4.0/24 | 0.0.0.0/0 hacia la instancia NAT-2 |

El tráfico entre balanceador y WordPress, y entre WordPress y MariaDB, permanece en la ruta local. No usa el NAT. El NAT solo interviene cuando el destino está fuera de la VPC (instalación de paquetes, Session Manager de las privadas, la prueba de salida a Internet).

### 2.4 Controles de tráfico

Los security groups dejan pasar solo lo que el diseño necesita. La salida permanece abierta. Al ser listas con estado, la respuesta de una conexión iniciada adentro puede volver. El puerto 22 no se publica. Las listas de control de red de la VPC se dejan en su permiso por defecto.

**Tabla 4. Entrada de los security groups**

| Grupo | Entrada permitida |
|---|---|
| NAT-1 | Todo el tráfico desde 10.0.2.0/24. ICMP desde 10.0.0.0/16 |
| NAT-2 | Todo el tráfico desde 10.0.4.0/24. ICMP desde 10.0.0.0/16 |
| HAProxy | TCP 80 desde Internet. ICMP desde 10.0.0.0/16 |
| BIND | TCP 53 y UDP 53 desde Internet. ICMP desde 10.0.0.0/16 |
| WordPress | TCP 80 solo desde 10.0.1.20 y 10.0.3.20 |
| MariaDB | TCP 3306 solo desde 10.0.2.10 y 10.0.4.10 |

La administración usa AWS Systems Manager Session Manager, con el perfil de instancia del laboratorio y el agente SSM de la AMI. Las instancias privadas alcanzan el servicio por el NAT de su zona. No se desplegó un bastión. [PENDIENTE: captura de una sesión de Session Manager y nota de si el perfil usado fue LabRole.]

### 2.5 NAT

Cada instancia NAT corre Ubuntu 24.04. El equipo configura el reenvío de IP y nftables. No se usa NAT Gateway ni una AMI preparada como NAT.

El reenvío queda en `net.ipv4.ip_forward=1`, también en `/etc/sysctl.d/99-nat.conf`, para que un reinicio no lo borre. nftables enmascara, en postrouting, el tráfico cuyo origen es la privada de esa zona y que sale por la interfaz de la instancia. Las reglas se guardan en `/etc/nftables.conf`. En NAT-1 la red enmascarada es `10.0.2.0/24`. En NAT-2 es `10.0.4.0/24`. Se instala conntrack para poder mostrar la asociación de direcciones y puertos.

En la consola de AWS, Source/Destination Check de las dos instancias NAT queda desactivado. Con el chequeo activo, la plataforma descarta el tráfico que no tiene como origen o destino la propia instancia, y el reenvío no ocurre.

La salida de una máquina privada sufre dos traducciones seguidas, y no son el mismo mecanismo.

1. **nftables en la EC2 NAT.** El origen `10.0.x.x:puerto` pasa a ser la IP privada del NAT y otro puerto. conntrack guarda la pareja para devolver la respuesta. Esta traducción la implementa el equipo.
2. **Internet Gateway.** La instancia NAT tiene IP pública. AWS presenta la IP privada de esa instancia como su IP pública hacia Internet. El gateway no ve la IP de WordPress. Ve la IP del NAT.

Una conexión que nace en Internet no tiene entrada previa en conntrack y no hay una regla de DNAT. La privada, además, no tiene IP pública, y los security groups no publican sus puertos de servicio hacia Internet. Por eso una conexión no solicitada no entra, mientras que la respuesta a una conexión iniciada adentro sí vuelve.

### 2.6 Aplicación web

El sitio usa WordPress sobre Apache y PHP, en las dos privadas. La base es una sola MariaDB en `10.0.4.20`. Escucha en el puerto 3306 y el usuario de la aplicación solo existe para `10.0.2.10` y `10.0.4.10`.

La instalación del sitio se hace una vez, en WordPress-1. WordPress-2 usa el mismo `wp-config.php` (misma base, mismas salts) y no vuelve a ejecutar la instalación. Las páginas de la demostración describen la empresa, las sedes de Medellín, Bogotá y Bucaramanga, y las líneas de producto. El contenido vive en la base.

En cada respuesta HTML, un complemento de carga obligatoria imprime la IPv4 privada de la EC2 que generó esa respuesta, leída de la dirección del servidor en esa petición. Apache y el complemento envían `Cache-Control: no-store`. No hay un plugin de caché de página. La redirección canónica de WordPress queda desactivada para que una petición directa a la IP de un balanceador no salte al otro a través del nombre DNS.

**Tabla 6. Estado compartido**

| Elemento | Dónde está | Consecuencia |
|---|---|---|
| Páginas, usuarios y opciones | MariaDB | Las dos WordPress muestran el mismo sitio |
| Código, tema y complemento de la IP | Disco de cada EC2 | Se instala en las dos y tiene que quedar igual |
| Archivos subidos (`wp-content/uploads`) | Disco de la EC2 donde se subieron | No se comparten. La demostración no depende de imágenes subidas |
| MariaDB | Una sola EC2, en la zona B | Si esa instancia o esa zona fallan, las dos WordPress dejan de poder construir la página |

La base única es un punto único de falla y el enunciado pide dejarlo documentado. No se agregó una segunda base porque el máximo de instancias es nueve y el enunciado pide una sola EC2 de base de datos.

### 2.7 Balanceo HTTP

Hay un HAProxy en cada subred pública. Los dos tienen la misma configuración: round-robin entre `10.0.2.10:80` y `10.0.4.10:80`, chequeo HTTP cada tres segundos, dos fallos para marcar el backend como caído, reintentos hacia el otro backend, y cierre de la conexión hacia el servidor al terminar cada petición. No hay cookie de afinidad.

El cierre de la conexión de backend importa para la demostración. Con conexiones persistentes, varias peticiones de un mismo cliente se quedarían en el mismo WordPress y el turno no se vería. El banner de la IP privada, sin caché y sin afinidad, es lo que permite identificar qué instancia atendió cada solicitud.

**Tabla 7. DNS Round Robin y HAProxy**

| | DNS Round Robin | HAProxy |
|---|---|---|
| Reparte | El nombre `www`, con dos registros A | Cada petición HTTP entre las dos WordPress |
| Quién decide | El resolvedor y su caché, según el orden y el TTL | El balanceador, petición por petición |
| Reparto parejo | No está garantizado | En esta configuración, turna entre los backends sanos |
| Si un nodo se apaga | El registro A sigue publicado. Parte de los clientes sigue usando la IP caída hasta que venza el TTL | El chequeo saca a la WordPress caída. Los dos balanceadores siguen con la que responde |
| Qué no demuestra | Ver las dos A con `dig` no mide el reparto de las conexiones HTTP | — |

Los dos mecanismos conviven. Round Robin elige a cuál balanceador llega el cliente. HAProxy elige cuál WordPress responde. El TTL de la zona de laboratorio es de 60 segundos para que las pruebas de caché se puedan observar en la sustentación. En una operación real ese TTL sería más alto.

### 2.8 DNS

El dominio o subdominio usado es [PENDIENTE: el dominio real]. El equipo tiene el control en el registrador [PENDIENTE: nombre del registrador].

BIND9 corre en las dos subredes públicas, sin recursión. El primario guarda la zona. El secundario la recibe por transferencia hacia su IP privada `10.0.3.30` y la escribe en el directorio de caché del servicio. `allow-transfer` del primario solo incluye esa IP.

**Tabla 5. Registros**

| Nombre | Tipo | Valor |
|---|---|---|
| zona | SOA | ns1, serial AAAAMMDD01, TTL 60 |
| zona | NS | ns1 y ns2 |
| ns1 | A | IP pública del BIND primario [PENDIENTE] |
| ns2 | A | IP pública del BIND secundario [PENDIENTE] |
| zona y www | A | IP pública de HAProxy-1 [PENDIENTE] |
| zona y www | A | IP pública de HAProxy-2 [PENDIENTE] |
| inicio | CNAME | www |

En el registrador, los servidores de nombres del dominio se delegan a ns1 y ns2 con esas IP públicas (glue). [PENDIENTE: captura del registrador y un `dig NS +trace` desde una red externa.]

Sin esa delegación, consultar con `dig @IP-del-BIND` demuestra que el autoritativo responde, y no demuestra que Internet haya delegado la zona. El enunciado pide las dos cosas.

### 2.9 Despliegue y acceso

[PENDIENTE: relato corto de lo que realmente se hizo el día del laboratorio: consola o CloudShell, hora aproximada, incidentes. El procedimiento previsto está en `COMO-SE-HIZO.md` y no sustituye este relato.]

El orden de construcción es el de las dependencias: red, instancias, NAT dentro de las dos EC2, MariaDB, las dos WordPress, los dos HAProxy, los dos BIND y, al final, la delegación. Las privadas no instalan paquetes hasta que el NAT de su zona reenvía.

### 2.10 Pruebas

Cada prueba siguiente se completa con la salida real. El procedimiento y los comandos están en `docs/pruebas/plantilla-11-pruebas.md`. El análisis de protocolos con captura está en `docs/pruebas/analisis-trafico.md`.

**Tabla 8. Resultados.** Una fila por prueba. La columna de resultado se llena después de ejecutar.

| Prueba | Qué se quería ver | Resultado medido | Figura |
|---|---|---|---|
| N1 | Desde una privada, el destino externo ve la IP pública del NAT de su AZ | [PENDIENTE] | [PENDIENTE] |
| N2 | conntrack muestra IP y puerto antes y después, y cada privada aparece en su NAT | [PENDIENTE] | [PENDIENTE] |
| N3 | Con `ip_forward=0` la salida falla. Al volver a 1, se restaura | [PENDIENTE] | [PENDIENTE] |
| N4 | La conexión iniciada adentro funciona. Una conexión entrante no solicitada no llega a la privada | [PENDIENTE] | [PENDIENTE] |
| D1 | SOA, NS, A y CNAME en los dos autoritativos, con `aa` y TTL, más la delegación pública | [PENDIENTE] | [PENDIENTE] |
| D2 | Al subir el serial, el secundario recibe el registro nuevo | [PENDIENTE] | [PENDIENTE] |
| D3 | Con el primario detenido, el secundario sigue respondiendo con `aa` | [PENDIENTE] | [PENDIENTE] |
| D4 | Dos A, orden y efecto del TTL. Eso no mide el reparto HTTP | [PENDIENTE] | [PENDIENTE] |
| D5 | Con un HAProxy detenido, su A sigue en la zona | [PENDIENTE] | [PENDIENTE] |
| B1 | Cada balanceador entrega las dos IP privadas en el home, sin caché ni afinidad | [PENDIENTE] | [PENDIENTE] |
| B2 | Con una WordPress detenida, los dos balanceadores siguen respondiendo con la otra | [PENDIENTE] | [PENDIENTE] |

Interpretación y protocolos de cada fila: redactar a partir de la salida real, usando la lectura de la plantilla solo donde coincida con lo observado.

Análisis de tráfico (IP, ICMP, TCP, DNS, HTTP y NAT): [PENDIENTE. Pegar el recorte de `tcpdump` y la frase de qué campo se observa. La guía de comandos está en `docs/pruebas/analisis-trafico.md`.]

---

## 3. Aspectos encontrados, problemas y recomendaciones

Esta sección se completa con lo que pase en el laboratorio. Los puntos de abajo son los que el diseño ya deja previstos. Si alguno no ocurrió, se dice. Si ocurrió otro, se agrega con la causa y cómo se resolvió.

1. **IP públicas que cambian al detener una instancia.** Los registros A y la delegación usan esas IP. [PENDIENTE: anotar si la cuenta permitió Elastic IP. Si no, la medida fue no detener los dos BIND ni los dos HAProxy hasta después de la sustentación.]
2. **Session Manager en las privadas.** El agente sale a Internet por el NAT. Hasta que nftables, el forwarding, la ruta y Source/Destination Check no están, la privada no aparece en el administrador de sesiones. [PENDIENTE: tiempo real que tardó.]
3. **Base de datos única.** Caer `10.0.4.20` deja el sitio sin página aunque los balanceadores y una WordPress sigan encendidos. Es una limitación pedida por el tope de nueve EC2 y por la base única. Recomendación posterior al curso: réplica en la otra zona, que hoy no cabe en el inventario.
4. **Archivos subidos.** No hay un disco compartido. Recomendación: no usar la biblioteca de medios para la demostración, o más adelante un sistema de archivos común. No se desplegó, para no abrir otro servicio ni otra instancia.
5. **DNS Round Robin y caché.** Un balanceador apagado sigue anunciado. Recomendación de operación: TTL corto solo mientras duran las pruebas; en producción, un TTL mayor y un mecanismo de salud delante del DNS, que este enunciado no permite sustituir por un DNS administrado en lugar de BIND.
6. **Propagación de la delegación.** [PENDIENTE: a qué hora se cambiaron los NS y a qué hora `dig +trace` los mostró.]
7. **[PENDIENTE: problemas que aparezcan al instalar: AppArmor, puerto 53, clave de MariaDB, cuota de la cuenta.]**

---

## 4. Conclusiones

[PENDIENTE: redactar después de las pruebas, en cuatro o cinco frases, con lo que sí se demostró. La siguiente lista es el esqueleto, no el texto final.]

- El sitio de XYZ S.A. quedó publicado con WordPress sobre nueve EC2, en dos zonas, con el direccionamiento y las rutas de la sección 2.
- La salida de las privadas a Internet la hace un NAT en Ubuntu 24.04 con nftables, distinto del Internet Gateway, que solo publica la IP de la instancia NAT.
- El balanceo HTTP reparte y retira un WordPress caído. El DNS Round Robin anuncia los dos balanceadores y no retira solo al que se apaga.
- La base compartida mantiene el mismo contenido en las dos WordPress, y es un punto único de falla. Los archivos subidos no se comparten.
- [Una frase sobre la delegación pública y sobre lo que las capturas mostraron de TCP, DNS, HTTP y NAT.]

---

## Referencias

[1] Enunciado del Proyecto N2, curso SI3002, Despliegue de Aplicaciones y Servicios en Red, 5 de noviembre de 2026.

[2] J. Postel, "Internet Protocol," RFC 791, septiembre de 1981.

[3] J. Postel, "Internet Control Message Protocol," RFC 792, septiembre de 1981.

[4] "Transmission Control Protocol (TCP)," RFC 9293, agosto de 2022.

[5] R. Fielding, M. Nottingham y J. Reschke, "HTTP Semantics," RFC 9110, junio de 2022.

[6] P. Mockapetris, "Domain names - concepts and facilities," RFC 1034, noviembre de 1987.

[7] P. Mockapetris, "Domain names - implementation and specification," RFC 1035, noviembre de 1987.

[8] Y. Rekhter, B. Moskowitz, D. Karrenberg, G. J. de Groot y E. Lear, "Address Allocation for Private Internets," RFC 1918, febrero de 1996.

[9] P. Srisuresh y K. Egevang, "Traditional IP Network Address Translator (Traditional NAT)," RFC 3022, enero de 2001.

[10] Amazon Web Services, "Amazon VPC User Guide." [En línea]. Disponible: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html. Consultado: 17 de noviembre de 2026.

[11] Amazon Web Services, "AWS Systems Manager Session Manager." [En línea]. Disponible: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html. Consultado: 17 de noviembre de 2026.

[12] The netfilter project, "nftables wiki." [En línea]. Disponible: https://wiki.nftables.org/. Consultado: 17 de noviembre de 2026.

[13] HAProxy Technologies, "HAProxy version 2.8 Configuration Manual." [En línea]. Disponible: https://docs.haproxy.org/2.8/configuration.html. Consultado: 17 de noviembre de 2026.

[14] Internet Systems Consortium, "BIND 9 Administrator Reference Manual." [En línea]. Disponible: https://bind9.readthedocs.io/en/stable/. Consultado: 17 de noviembre de 2026.

[15] WordPress.org, "Requirements." [En línea]. Disponible: https://wordpress.org/about/requirements/. Consultado: 17 de noviembre de 2026.

[16] Canonical, "Ubuntu 24.04 LTS." [En línea]. Disponible: https://ubuntu.com/server/docs. Consultado: 17 de noviembre de 2026.

[17] MariaDB Foundation, "MariaDB Server documentation." [En línea]. Disponible: https://mariadb.com/kb/en/documentation/. Consultado: 17 de noviembre de 2026.
