# Análisis de tráfico

El enunciado pide analizar IP, ICMP, TCP, DNS y HTTP, y capturar tráfico que muestre la resolución DNS, el establecimiento TCP, el intercambio HTTP y la traducción NAT. Esto es adicional a las 11 pruebas. Los comandos de esas pruebas están en `plantilla-11-pruebas.md`.

Las capturas se guardan en `docs/pruebas/img/`. Un `tcpdump` de treinta segundos basta. No hace falta dejar un archivo pcap enorme en el repositorio: en el documento va la captura de pantalla o el recorte de la salida, con una frase de qué campo se está mirando.

En todas las EC2 la interfaz casi siempre se llama `ens5`. Si no, `ip route | awk '/default/ {print $5; exit}'`.

---

## IP

Qué mostrar: una privada tiene solo direcciones `10.0.x` (RFC 1918). Una pública tiene una `10.0.x` por dentro y una IP pública puesta por AWS, visible en la consola y en `curl -4 https://ifconfig.me`.

```bash
ip -4 addr
ip route
```

Lectura: la ruta `10.0.0.0/16 dev ens5` es el tráfico interno de la VPC. La ruta `default` de una pública apunta al router de la subred (el primer salto hacia el Internet Gateway). La ruta `default` de una privada apunta a `10.0.1.10` o a `10.0.3.10`, que son las instancias NAT.

---

## ICMP

Qué mostrar: un echo request y su echo reply entre dos máquinas de la VPC. El security group permite ICMP desde `10.0.0.0/16` para esta sección.

Desde WordPress-1:

```bash
ping -c 3 10.0.4.20
ping -c 3 10.0.1.20
```

En la máquina destino, durante el ping:

```bash
sudo tcpdump -n -i ens5 icmp -c 6
```

Lectura: se ven `echo request` y `echo reply` con las IP privadas en los dos sentidos. Ese tráfico no sale a Internet y no pasa por el NAT: el destino está dentro de `10.0.0.0/16`, así que usa la ruta local. Un ping desde la privada hacia `1.1.1.1` sí pasa por el NAT; si se captura en el NAT, el origen ya no es `10.0.2.10` en el lado que mira a Internet.

---

## TCP: saludo de tres vías

Qué mostrar: SYN, SYN-ACK y ACK de una conexión HTTP hacia un HAProxy, y otra desde el HAProxy hacia una WordPress.

En HAProxy-1, dejar corriendo:

```bash
sudo tcpdump -n -i ens5 "tcp port 80" -c 20
```

Desde el computador del equipo:

```bash
curl -4 -s -o /dev/null http://IP_PUBLICA_HAPROXY_1/
```

Lectura: hacia la IP pública se ve el saludo entre el cliente y el HAProxy. Hacia `10.0.2.10` o `10.0.4.10` se ve **otro** saludo, el que abre el balanceador hacia Apache. Son dos conexiones TCP. HAProxy no reenvía el mismo paquete: termina HTTP y abre una conexión nueva. Eso es lo que permite elegir el backend por petición.

---

## DNS

Qué mostrar: una consulta y su respuesta, con el id de transacción, el nombre `www` y las dos direcciones A.

En el BIND primario:

```bash
sudo tcpdump -n -i ens5 "udp port 53 or tcp port 53" -c 10
```

Desde el computador:

```bash
dig @IP_PUBLICA_NS1 www.TUDOMINIO A
```

Lectura: la consulta normal cabe en un datagrama UDP al puerto 53. La respuesta trae las dos A. Para la transferencia de zona (prueba D2), la captura en el primario durante `rndc retransfer` tiene que mostrar TCP 53 entre `10.0.1.30` y `10.0.3.30`. Conviene una captura UDP (consulta pública) y otra TCP (AXFR), para no mezclarlas.

---

## HTTP

Qué mostrar: la petición `GET /` y la respuesta `200`, más el encabezado que impide caché y el cuerpo donde va la IP privada.

En una WordPress, durante un `curl` desde el HAProxy:

```bash
sudo tcpdump -n -i ens5 -A "tcp port 80" -c 10
```

Desde el computador, para ver encabezados sin abrir el navegador:

```bash
curl -4 -D - -o /tmp/cuerpo.html http://IP_PUBLICA_HAPROXY_1/
grep -n "IPv4 privada" /tmp/cuerpo.html
```

Lectura: `Cache-Control: no-store` tiene que salir en la respuesta. `X-Servidor-Privado` trae la IP de la EC2 que armó la página. El cuerpo repite esa IP en el recuadro. Si el `curl` se repite, esa IP puede alternar entre `10.0.2.10` y `10.0.4.10`. El HTML viaja en la conexión que el cliente tiene con el HAProxy; Apache lo generó en la otra conexión.

---

## NAT

Qué mostrar: el mismo flujo antes y después de la traducción. Complementa N1 y N2 con una captura, no solo con conntrack.

En NAT-1:

```bash
sudo tcpdump -n -i ens5 host 10.0.2.10 -c 10
```

En otra terminal del NAT, o justo después, la tabla:

```bash
conntrack -L | grep 10.0.2.10
```

Desde WordPress-1, en ese momento:

```bash
curl -4 -s https://ifconfig.me ; echo
```

Lectura: en la interfaz del NAT se ve tráfico cuyo origen es `10.0.2.10` (lo que llega desde la privada). conntrack muestra la pareja traducida a `10.0.1.10` y un puerto distinto. El sitio externo no devuelve `10.0.2.10` ni `10.0.1.10`: devuelve la IP pública de NAT-1, que es el paso que hace el Internet Gateway sobre la instancia NAT. Las tres direcciones (privada de WordPress, privada del NAT, pública del NAT) tienen que quedar escritas juntas en el documento para que las dos traducciones no se cuenten como si fueran una sola.
