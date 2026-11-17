# Plantilla de las 11 pruebas

Cada prueba del enunciado lleva cinco cosas: procedimiento, comandos, evidencia, interpretación y protocolos. Aquí está el procedimiento y los comandos. La evidencia se pega el día que la máquina esté viva. La "lectura esperada" dice qué hay que poder explicar; no es un resultado ya medido. Si la salida real no coincide, se escribe lo que salió y por qué.

Capturas y salidas largas: `docs/pruebas/img/`.

Sustituyan `TUDOMINIO`, las IP públicas y los id de instancia por los del laboratorio.

Al terminar N3 y D3 y D5 y B2, el servicio que se apagó tiene que quedar encendido otra vez.

---

## NAT N1. Salida desde una privada

**Dónde.** WordPress-1 (`10.0.2.10`) o MariaDB (`10.0.4.20`). Repetir una vez en cada AZ deja claro que cada privada usa su propio NAT.

**Procedimiento.**

1. Confirmar que la instancia no tiene IP pública en la consola.
2. Ver la IP local y la ruta por defecto.
3. Pedir a un sitio externo la IP con la que la ve.

**Comandos.**

```bash
ip -4 addr
ip route
curl -4 -s https://ifconfig.me ; echo
```

En el NAT de esa AZ:

```bash
curl -4 -s https://ifconfig.me ; echo
```

**Evidencia.** Pegar las tres salidas y una captura de la consola donde la privada aparece sin IP pública.

**Lectura esperada.** La privada solo tiene una IPv4 `10.0.x`. La ruta `default` apunta al NAT de su AZ (`10.0.1.10` o `10.0.3.10`). `ifconfig.me` devuelve la IP pública de ese NAT, la misma que el NAT ve si hace la misma consulta. El destino no ve `10.0.2.10`.

**Protocolos.** IP (direcciones privada y pública), TCP (la conexión HTTPS hacia el sitio externo), NAT de Linux y, después, la traducción del Internet Gateway. El detalle de los dos pasos está en `analisis-trafico.md`.

---

## NAT N2. conntrack: antes y después

**Dónde.** En el NAT, mientras la privada de su AZ genera conexiones.

**Procedimiento.**

1. En la privada, dejar corriendo varias conexiones. Por ejemplo un bucle de `curl`.
2. En el NAT, listar conntrack filtrando por la IP privada.
3. Repetir desde la otra privada y mostrar que esa conexión aparece en el otro NAT.

**Comandos.** En la privada:

```bash
for i in 1 2 3 4 5; do curl -4 -s -o /dev/null -w "%{http_code}\n" https://example.com; done
```

En el NAT de esa AZ:

```bash
conntrack -L | grep 10.0.2.10
```

En NAT-2 el filtro es `10.0.4.10` o `10.0.4.20`.

**Evidencia.** Una línea de conntrack donde se lean las dos parejas: IP y puerto de origen privados, IP y puerto de origen ya traducidos.

**Lectura esperada.** La tupla original tiene origen `10.0.2.10` y un puerto alto. Después del masquerade el origen es `10.0.1.10` y otro puerto. El puerto cambia porque varias privadas (o varias conexiones) pueden salir a la vez y el NAT tiene que distinguirlas. La privada 1 solo aparece en NAT-1. La privada 2 solo aparece en NAT-2. Eso lo fija la tabla de rutas, no el security group.

**Protocolos.** IP, TCP o UDP según la conexión, y la tabla de estado del NAT (conntrack). ICMP también puede aparecer si se hizo un ping.

---

## NAT N3. Apagar el forwarding

**Dónde.** Un NAT, y la privada de su misma AZ.

**Procedimiento.**

1. Comprobar que la privada sí sale.
2. En el NAT, poner `ip_forward` en 0. No borrar las reglas de nftables.
3. Repetir la salida desde la privada y registrar el fallo.
4. Devolver `ip_forward` a 1 y comprobar que vuelve a funcionar.

**Comandos.** En el NAT:

```bash
sysctl net.ipv4.ip_forward
sysctl -w net.ipv4.ip_forward=0
```

En la privada:

```bash
curl -4 -v --max-time 10 https://ifconfig.me
```

De nuevo en el NAT, antes de dar por cerrada la prueba:

```bash
sysctl -w net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward
```

**Evidencia.** El `curl` exitoso, el timeout o el fallo con forwarding en 0, y la restauración.

**Lectura esperada.** Con forwarding en 0 el núcleo acepta el paquete en la interfaz del NAT y no lo reenvía a la interfaz que sale a Internet. Las reglas de masquerade no llegan a aplicarse sobre un paquete que el sistema se niega a reenviar. Por eso el fallo es de reenvío, no de DNS ni de security group. El archivo `/etc/sysctl.d/99-nat.conf` no se toca: un reinicio volvería a dejarlo en 1, pero la prueba tiene que restaurarlo en caliente.

**Protocolos.** IP. El paquete entra al NAT y no se reenvía. No llega a haber traducción ni respuesta TCP.

---

## NAT N4. Sale lo que nació adentro

**Dónde.** Una privada, el NAT de su AZ, y un computador fuera de AWS.

**Procedimiento.**

1. Repetir una salida iniciada por la privada (N1). Tiene que funcionar.
2. Desde un computador externo, intentar una conexión nueva hacia la IP pública del NAT en un puerto que no está publicado (por ejemplo 8080) y hacia el puerto 80.
3. Anotar que la privada no tiene IP pública a la cual conectarse.
4. En el NAT, mirar si esa conexión externa creó una entrada de conntrack hacia `10.0.2.10`. No debería.

**Comandos.** Desde el computador del equipo, con la IP pública del NAT:

```bash
curl -4 -v --max-time 8 http://IP_PUBLICA_DEL_NAT/
nc -vz -w 5 IP_PUBLICA_DEL_NAT 8080
```

En el NAT, durante el intento:

```bash
conntrack -L | grep 10.0.2.10
nft list ruleset
```

**Evidencia.** El fallo del `curl` o de `nc` desde afuera, y la ausencia de una regla DNAT.

**Lectura esperada.** Hay tres controles, y conviene nombrarlos por separado.

1. La privada no tiene IP pública. Desde Internet no existe un destino `10.0.2.10`.
2. El NAT solo hace masquerade (origen). No hay DNAT ni un puerto reenviado hacia la privada. Un paquete que nace afuera no tiene una entrada previa en conntrack, así que no se asocia con ninguna conexión iniciada adentro.
3. El security group del NAT no permite entrar por el puerto 80 desde Internet, y el de WordPress solo acepta el 80 desde las IP de los HAProxy.

La conexión que sí funciona es la que empieza en la privada: conntrack guarda el estado y deja pasar la respuesta.

**Protocolos.** IP, TCP (SYN entrante que no completa), NAT con estado.

---

## DNS D1. SOA, NS, A, CNAME y la delegación

**Dónde.** Desde una máquina con `dig`: el computador del equipo y, para comparar, una de las EC2.

**Procedimiento.** Consultar los dos autoritativos directo, por su IP, y después consultar la delegación pública sin poner `@`.

**Comandos.**

```bash
dig @IP_PUBLICA_NS1 TUDOMINIO SOA
dig @IP_PUBLICA_NS1 TUDOMINIO NS
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
dig @IP_PUBLICA_NS1 inicio.TUDOMINIO CNAME
dig @IP_PUBLICA_NS2 TUDOMINIO SOA
dig @IP_PUBLICA_NS2 www.TUDOMINIO A
dig TUDOMINIO NS +trace
```

**Evidencia.** Las salidas completas, donde se vean `flags`, `aa`, el TTL, y las secciones ANSWER y AUTHORITY.

**Lectura esperada.** En la consulta directa, `status: NOERROR` y la bandera `aa` (respuesta autoritativa). SOA con el serial del primario. NS apuntando a `ns1` y `ns2`. Dos registros A en `www`. `inicio` como CNAME hacia `www`, y en la adicional o en una consulta seguida, las A de `www`. El `+trace` muestra la delegación desde la raíz hasta los NS propios. Si `+trace` se queda en los NS del registrador, la delegación todavía no está hecha o no se ha propagado: las consultas con `@IP` pueden estar bien y la entrega, aun así, no cumple hasta que el trace cambie.

**Protocolos.** DNS sobre UDP (la consulta normal) y, si la respuesta no cupo o es una transferencia, DNS sobre TCP. IP de por medio.

---

## DNS D2. Cambio en el primario y transferencia

**Dónde.** BIND primario y BIND secundario.

**Procedimiento.**

1. Anotar el serial actual en los dos (`dig SOA`).
2. En el primario, editar `/etc/bind/zones/db.TUDOMINIO`. Agregar un registro de prueba, por ejemplo `prueba A 10.0.1.20`, y subir el serial.
3. `rndc reload` en el primario.
4. En el secundario, `rndc retransfer TUDOMINIO` si no llegó solo.
5. Comparar serial y el registro nuevo en los dos.

**Comandos.**

```bash
dig @10.0.1.30 TUDOMINIO SOA +norecurse
dig @10.0.3.30 TUDOMINIO SOA +norecurse
sudo rndc reload
sudo rndc retransfer TUDOMINIO
dig @10.0.3.30 prueba.TUDOMINIO A
```

**Evidencia.** El serial antes y después, en los dos servidores, y el registro nuevo visto en el secundario.

**Lectura esperada.** El secundario no se entera si el serial no aumenta. La transferencia es AXFR/IXFR por TCP 53, desde `10.0.1.30` hacia `10.0.3.30`, que es lo que permite `allow-transfer`. El secundario queda con la misma zona, no con una zona editada a mano.

**Protocolos.** DNS, TCP (la transferencia), IP dentro de la VPC.

---

## DNS D3. El primario se detiene

**Dónde.** Los dos BIND.

**Procedimiento.**

1. `dig @IP_PUBLICA_NS2 www.TUDOMINIO A` y guardar la bandera `aa`.
2. En el primario: `sudo systemctl stop named` (o `bind9`, el que exista).
3. Repetir el `dig` contra el secundario.
4. Opcional: un `dig www.TUDOMINIO` sin `@`, para comentar qué hace el resolvedor.
5. Volver a arrancar el primario: `sudo systemctl start named`.

**Evidencia.** El `systemctl status` del primario detenido y el `dig` al secundario con `aa`.

**Lectura esperada.** El secundario sigue siendo autoritativo de la zona que ya recibió. Detener el primario no borra esa copia. Un resolvedor recursivo es otra cosa: puede contestar desde caché aunque un autoritativo esté caído, y esa respuesta no lleva `aa` del servidor de la empresa. Por eso la prueba se hace con `@` apuntando al secundario.

**Protocolos.** DNS. La disponibilidad del autoritativo secundario no depende de que el primario esté encendido en ese momento.

---

## DNS D4. Las dos A, el orden, el TTL y la caché

**Dónde.** Consultas directas a un BIND y consultas a un resolvedor público (por ejemplo `1.1.1.1` o `8.8.8.8`), repetidas.

**Procedimiento.**

1. Consultar `www` varias veces directo al autoritativo y anotar el orden de las dos A y el TTL.
2. Consultar el mismo nombre a un resolvedor, repetir enseguida y anotar si el TTL baja.
3. Esperar a que el TTL llegue a cero, o usar otro resolvedor, y volver a mirar el orden.

**Comandos.**

```bash
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
dig @1.1.1.1 www.TUDOMINIO A
dig @1.1.1.1 www.TUDOMINIO A
```

**Evidencia.** Al menos cuatro salidas, con las dos direcciones, el orden y el TTL visible.

**Lectura esperada.** La zona anuncia las dos A. El servidor puede rotar el orden (round robin de DNS). El resolvedor cachea la respuesta durante el TTL, que en esta zona es de 60 segundos: mientras la caché vive, el cliente puede recibir siempre el mismo orden y ni siquiera volver a preguntar al autoritativo. Eso no mide cuántas conexiones HTTP entraron a cada HAProxy. Para el reparto HTTP está la prueba B1, que mira la IP privada dentro de la página.

**Protocolos.** DNS y el comportamiento de caché del resolvedor. No es HTTP.

---

## DNS D5. Se apaga un balanceador y su A sigue

**Dónde.** HAProxy-1 o HAProxy-2, y un BIND.

**Procedimiento.**

1. `dig` de `www` y anotar las dos A.
2. Detener una instancia HAProxy o hacer `sudo systemctl stop haproxy` en ella.
3. Volver a consultar `www` en el autoritativo.
4. Intentar `curl` a la IP del balanceador detenido y a la del que sigue.
5. Volver a levantar el balanceador.

**Comandos.**

```bash
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
sudo systemctl stop haproxy
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
curl -4 -v --max-time 8 http://IP_DEL_HAPROXY_DETENIDO/
curl -4 -s --max-time 8 http://IP_DEL_HAPROXY_VIVO/ | grep "IPv4 privada"
sudo systemctl start haproxy
```

**Evidencia.** Los dos `dig` (mismo par de A) y el fallo del `curl` a la IP detenida.

**Lectura esperada.** BIND no mira si HAProxy está vivo. El registro A se queda publicado hasta que alguien lo borre o venza la caché de quien ya lo tenía. Durante el TTL, una parte de los visitantes sigue intentando el balanceador caído. El otro balanceador, si el cliente llega a él, sigue atendiendo. Esa es la limitación de disponibilidad del DNS Round Robin. No es un fallo de configuración: es el comportamiento que el enunciado pide mostrar.

**Protocolos.** DNS (el anuncio sigue) y TCP/HTTP (la conexión al nodo caído no se completa, la del nodo vivo sí).

---

## Balanceo B1. Las dos IP privadas, por los dos HAProxy

**Dónde.** El computador del equipo, contra la IP pública de cada HAProxy. Hacerlo con `curl`, no con el navegador, para no pelear con la caché del navegador.

**Procedimiento.**

1. Confirmar en las estadísticas locales, por Session Manager, que `wp1` y `wp2` están UP: `curl -s http://127.0.0.1:8404/stats`.
2. Lanzar varias peticiones a HAProxy-1 y anotar la IP del recuadro.
3. Lo mismo contra HAProxy-2.

**Comandos.**

```bash
for i in 1 2 3 4 5 6; do
  curl -4 -s --max-time 10 http://IP_PUBLICA_HAPROXY_1/ | grep -o "10\.0\.[0-9.]*" | head -n 1
done
for i in 1 2 3 4 5 6; do
  curl -4 -s --max-time 10 http://IP_PUBLICA_HAPROXY_2/ | grep -o "10\.0\.[0-9.]*" | head -n 1
done
```

**Evidencia.** Las dos listas. Tienen que aparecer `10.0.2.10` y `10.0.4.10` en cada balanceador.

**Lectura esperada.** Cada HAProxy turna entre las dos WordPress. No hay cookie de afinidad. `http-server-close` evita que varias peticiones se queden pegadas a la misma conexión de backend. El banner sale de PHP en esa petición (`SERVER_ADDR`), con `Cache-Control: no-store`. Si una de las dos IP no aparece, revisar el chequeo de salud y el security group de WordPress (solo acepta a `10.0.1.20` y `10.0.3.20`).

**Protocolos.** HTTP sobre TCP. El balanceo es de capa de aplicación: HAProxy abre su propia conexión hacia la WordPress elegida. DNS no interviene en este `curl`, porque se usó la IP del balanceador.

---

## Balanceo B2. Se apaga una WordPress

**Dónde.** Las dos HAProxy y una WordPress.

**Procedimiento.**

1. Con las dos WordPress vivas, repetir un par de `curl` para tener la línea de base.
2. En WordPress-1: `sudo systemctl stop apache2`. Esperar unos 10 segundos (el chequeo usa 3 s y dos fallos).
3. Repetir los bucles de B1 contra los dos HAProxy.
4. Mirar las estadísticas: `wp1` en DOWN, `wp2` en UP.
5. Volver a arrancar Apache: `sudo systemctl start apache2`.

**Comandos.**

```bash
sudo systemctl stop apache2
curl -s http://127.0.0.1:8404/stats | grep -E "wp1|wp2"
```

Y los mismos bucles de `curl` de B1.

**Evidencia.** Antes y después, más el trozo de estadísticas con un backend DOWN. Todas las respuestas nuevas, en los dos HAProxy, muestran `10.0.4.10` mientras Apache de la primera está detenido.

**Lectura esperada.** Los dos balanceadores conocen las dos WordPress, también la de la otra AZ. Al fallar el chequeo, round-robin solo tiene un destino sano. El sitio sigue respondiendo por los dos HAProxy. Esto es distinto de D5: aquí el nodo malo se deja de usar solo. En D5, el registro DNS del balanceador caído sigue anunciado.

**Protocolos.** HTTP (el chequeo `GET /` y la petición del usuario) y TCP (la conexión hacia el backend que ya no acepta, y la conexión hacia el que sí).

---

## Cierre

Cuando las once estén hechas, copiar la evidencia y la interpretación definitiva a `docs/documento-final/documento-ieee.md`, en la sección de pruebas. La lectura esperada de esta plantilla se puede usar como base, corregida con lo que realmente salió en el lab.
