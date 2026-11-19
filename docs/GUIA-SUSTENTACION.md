# Guía de sustentación — Proyecto N2 SI3002

Explicación del proyecto + preguntas típicas del profesor con sus respuestas.

## 1. Qué es el proyecto

Infraestructura en AWS para el sitio web de XYZ S.A. (cosméticos), con alta
disponibilidad y escalado horizontal, usando 9 instancias EC2. DNS, NAT y balanceo
están implementados a mano (no con servicios administrados de AWS).

## 2. Analogía (centro comercial)

- Dominio `xtz.lat` = la dirección del centro comercial.
- 2 DNS (BIND9) = el directorio que dice en qué IP está el sitio.
- 2 balanceadores (HAProxy) = los porteros que reparten visitantes entre 2 tiendas.
- 2 WordPress = dos tiendas idénticas (el sitio).
- 1 base de datos (MariaDB) = la bodega central compartida.
- 2 NAT = la puerta de servicio por la que las tiendas internas salen a Internet.

## 3. Recorrido de una visita a www.xtz.lat

1. El navegador pregunta a los DNS (BIND) dónde está www.xtz.lat.
   Responden dos IPs (los dos HAProxy): esto es DNS Round Robin.
2. El navegador se conecta a uno de los HAProxy.
3. El HAProxy reparte la petición a WordPress-1 o WordPress-2: balanceo HTTP.
4. El WordPress pide el contenido a MariaDB y arma la página, mostrando su IP privada.
5. La respuesta vuelve al navegador.

## 4. Direccionamiento (de memoria para la sustentación)

- VPC 10.0.0.0/16, 4 subredes /24, 2 AZ (us-east-1a y us-east-1b).
- Pública 1 (10.0.1.0/24): NAT-1, HAProxy-1, BIND-primario.
- Privada 1 (10.0.2.0/24): WordPress-1.
- Pública 2 (10.0.3.0/24): NAT-2, HAProxy-2, BIND-secundario.
- Privada 2 (10.0.4.0/24): WordPress-2, MariaDB.
- Elastic IP fijas: HAProxy-1 18.214.151.88, HAProxy-2 18.232.215.62,
  BIND-primario (ns1) 23.21.163.138, BIND-secundario (ns2) 52.2.122.81.

## 5. Preguntas típicas del profesor (con respuesta)

### P: ¿Diferencia entre tu NAT de Linux y el Internet Gateway de AWS?
El Internet Gateway solo da salida a instancias que tienen IP pública. Las WordPress y la
base no tienen IP pública, así que no pueden usar el IGW directamente. El NAT (una EC2 en
subred pública con nftables) les presta su IP pública: reescribe el origen de los paquetes
(SNAT/masquerade) y recuerda la conexión con conntrack para devolver la respuesta. El IGW
nunca ve la IP privada 10.0.2.10; para él, el cliente es el NAT.

### P: ¿Por qué hay que desactivar el Source/Destination Check en los NAT?
Por defecto AWS descarta el tráfico que no va dirigido a la propia instancia (anti-spoofing).
Un NAT justamente reenvía tráfico de otros (de la subred privada), así que hay que
desactivar ese chequeo o AWS tira esos paquetes.

### P: ¿Qué es el IP forwarding y por qué lo activaste?
Es un ajuste del kernel (net.ipv4.ip_forward=1) que permite a Linux reenviar paquetes entre
interfaces, es decir, comportarse como router. Sin él, el NAT recibe el paquete pero no lo
pasa (lo demostramos en la prueba N3).

### P: ¿Qué diferencia hay entre DNS Round Robin y el balanceo de HAProxy?
- DNS Round Robin reparte entre balanceadores: publica dos registros A para www y rota el
  orden. No garantiza 50/50 (el cliente suele tomar la primera IP, y las cachés fijan el
  orden durante el TTL) y no retira una IP caída automáticamente (prueba D5).
- HAProxy reparte entre servidores web, petición por petición, con health-check: si una
  WordPress cae, la saca del reparto sola (prueba B2).
  Son complementarios: uno elige balanceador, el otro elige servidor web.

### P: ¿Cómo funciona el primario/secundario de DNS?
El primario tiene la zona original. El secundario pide una copia (transferencia de zona,
AXFR) cuando el serial del SOA sube. El primario avisa con NOTIFY. Si el primario se cae,
el secundario sigue respondiendo autoritativamente (prueba D3). El serial es la señal de
"hay cambios" (prueba D2).

### P: ¿Cuál es el punto único de falla del sistema?
La base de datos: es una sola EC2 (MariaDB) en la privada 2. Si se cae, las dos WordPress
siguen vivas pero el sitio no se arma porque no hay datos. El enunciado pide una sola base,
así que se documenta como punto único de falla. Mitigación futura (no implementada por el
tope de 9 EC2): una réplica de base en la otra AZ.

### P: ¿Cómo se comparte el estado entre las dos WordPress?
El contenido (páginas, entradas, opciones) vive en MariaDB, compartido. El código y el
tema están en el disco de cada WordPress (iguales). Las salts de wp-config son iguales en
las dos para que una sesión sirva en cualquiera. Lo que NO se comparte: los archivos
subidos (wp-content/uploads) quedan en el disco de una sola instancia; por eso el sitio de
demostración usa texto en la base y no depende de imágenes subidas.

### P: ¿Por qué el banner muestra la IP privada?
Un mu-plugin de WordPress lee SERVER_ADDR (la IP de la EC2 que atendió) y la imprime. Como
HAProxy reparte sin afinidad de sesión y se desactiva la caché, al recargar cambia la IP:
así se evidencia que las dos WordPress atienden (prueba B1).

### P: ¿Por qué usaste t2.micro y no t3.small?
El Learner Lab de este equipo topa en 9 instancias simultáneas y en pocos vCPU. Con 9
t2.micro (1 vCPU c/u = 9 vCPU) caben las nueve. Las WordPress y la base van algo justas de
RAM pero suficientes para la demostración.

### P: ¿Cómo administras las máquinas sin abrir SSH?
Con AWS Systems Manager Session Manager (agente SSM + rol LabInstanceProfile). El puerto 22
no está abierto a Internet en ningún security group. Las privadas alcanzan a SSM saliendo
por el NAT.

## 6. Seguridad (security groups) — resumen

- NAT: acepta todo desde su subred privada.
- HAProxy: acepta HTTP/80 desde Internet.
- BIND: acepta DNS 53 (TCP y UDP) desde Internet.
- WordPress: acepta HTTP/80 solo desde los dos HAProxy.
- MariaDB: acepta 3306 solo desde las dos WordPress.
- ICMP permitido dentro de la VPC (para el análisis de protocolos).
- Puerto 22 cerrado en todo.
