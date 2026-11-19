# Documento de evidencias y capturas — Proyecto N2 SI3002

> CÓMO USAR ESTE DOCUMENTO
> Cada prueba tiene su comando, su salida (ya registrada) y su interpretación.
> Donde dice **[CAPTURA: ...]** pega el pantallazo correspondiente desde tu computador.
> Luego exporta todo a Word/PDF para la sustentación.
>
> Dominio: xtz.lat
> IPs fijas: HAProxy-1 18.214.151.88 · HAProxy-2 18.232.215.62 ·
> BIND-primario/ns1 23.21.163.138 · BIND-secundario/ns2 52.2.122.81

---

## 0. El sitio funcionando

**[CAPTURA: navegador en http://www.xtz.lat — home de XYZ S.A. con el banner negro de IP privada arriba]**

**[CAPTURA: recargar y mostrar que el banner cambia de 10.0.2.10 a 10.0.4.10 (balanceo en vivo)]**

**[CAPTURA: una página interna, p.ej. http://www.xtz.lat/sedes/ con contenido]**

---

## 1. Infraestructura en AWS

**[CAPTURA: consola EC2 → Instances, mostrando las 9 instancias en estado running]**

**[CAPTURA: tabla del inventario (salida de lanzar-instancias / mostrar-inventario) con las 9 EC2 e IPs]**

Inventario de referencia:

| Instancia | IP privada | IP pública | AZ |
|---|---|---|---|
| NAT-1 | 10.0.1.10 | (normal) | us-east-1a |
| HAProxy-1 | 10.0.1.20 | 18.214.151.88 (EIP) | us-east-1a |
| BIND-primario | 10.0.1.30 | 23.21.163.138 (EIP) | us-east-1a |
| WordPress-1 | 10.0.2.10 | (sin pública) | us-east-1a |
| NAT-2 | 10.0.3.10 | (normal) | us-east-1b |
| HAProxy-2 | 10.0.3.20 | 18.232.215.62 (EIP) | us-east-1b |
| BIND-secundario | 10.0.3.30 | 52.2.122.81 (EIP) | us-east-1b |
| WordPress-2 | 10.0.4.10 | (sin pública) | us-east-1b |
| MariaDB | 10.0.4.20 | (sin pública) | us-east-1b |

---

## 2. NAT N1 — salida a Internet desde una privada

**Comando (en WordPress-1):**
```
hostname -I ; curl -s https://ifconfig.me ; ip route | grep default
```
**Salida obtenida:**
```
10.0.2.10
13.220.34.110            (IP publica de NAT-1 vista por Internet)
default via 10.0.2.1 ...
```
**[CAPTURA: terminal de WordPress-1 con la salida del curl mostrando la IP del NAT]**

**Interpretación:** WordPress-1 no tiene IP pública; al salir a Internet, el destino ve la
IP del NAT (SNAT/masquerade). El IGW solo enruta instancias con IP pública; la privada
necesita el NAT.

---

## 3. NAT N2 — traducción con conntrack

**Comando (NAT-1 escuchando, WordPress-1 generando tráfico):**
```
conntrack -E -p tcp | grep "10.0.2.10"
```
**Salida obtenida:**
```
[NEW]    tcp SYN_SENT    src=10.0.2.10 dst=13.217.79.194 sport=34726 dport=443 [UNREPLIED] src=13.217.79.194 dst=10.0.1.10 sport=443 dport=34726
[UPDATE] tcp ESTABLISHED src=10.0.2.10 ... dst=10.0.1.10 ... [ASSURED]
```
**[CAPTURA: terminal de NAT-1 con los eventos de conntrack]**

**Interpretación:** la tupla de respuesta llega a 10.0.1.10 (el NAT), no a 10.0.2.10. El
NAT reescribe el origen y conntrack recuerda la asociación para devolver la respuesta.

---

## 4. NAT N3 — apagar IP forwarding

**Comandos:**
```
# NAT-1:  sysctl -w net.ipv4.ip_forward=0   (apagar)
# WordPress-1: curl --max-time 10 https://ifconfig.me   -> timeout, sin IP
# NAT-1:  sysctl -w net.ipv4.ip_forward=1   (restaurar)
# WordPress-1: curl --max-time 10 https://ifconfig.me   -> 32.202.144.94
```
**[CAPTURA: NAT-1 mostrando ip_forward=0 y luego =1]**

**[CAPTURA: WordPress-1 mostrando que tras restaurar vuelve a salir (muestra IP)]**

**Interpretación:** sin IP forwarding el NAT recibe el paquete pero no lo reenvía; la
privada pierde Internet. Al restaurarlo, vuelve. El forwarding es condición necesaria.

---

## 5. NAT N4 — saliente vs entrante  (PENDIENTE de correr si se desea)

**Idea:** una conexión que inicia la privada hacia Internet funciona (el NAT la recuerda);
un intento desde Internet hacia 10.0.2.10 no funciona (no tiene IP pública y el NAT no
acepta conexiones entrantes no solicitadas).

**[CAPTURA: WordPress-1 curl saliente OK + CloudShell intentando llegar a 10.0.2.10 y fallando]**

---

## 6. DNS D1 — SOA, NS, A, CNAME en ambos autoritativos

**Comando:**
```
dig @23.21.163.138 xtz.lat SOA
dig @52.2.122.81  xtz.lat SOA
dig @23.21.163.138 xtz.lat NS
dig @23.21.163.138 www.xtz.lat A
dig @23.21.163.138 inicio.xtz.lat CNAME
dig xtz.lat NS +short     (delegacion publica)
```
**Salida obtenida:** ambos servidores dan serial 2026111801; www con 18.214.151.88 y
18.232.215.62; CNAME inicio -> www; delegación pública devuelve ns1 y ns2.

**[CAPTURA: CloudShell con la salida de D1 (SOA de los dos, NS, A, CNAME)]**

**Interpretación:** mismo serial en primario y secundario = transferencia de zona OK. Dos
A para www = DNS Round Robin. Delegación pública activa.

---

## 7. DNS D2 — cambio de serial y sincronización

**Comando:** subir serial a 2026111802 y agregar prueba.xtz.lat en el primario; recargar.
**Salida:** primario y secundario muestran serial 2026111802 y prueba.xtz.lat = 10.9.9.9.

**[CAPTURA: terminal con primario y secundario mostrando el mismo serial nuevo]**

**Interpretación:** al subir el serial, el secundario pide la transferencia y se sincroniza.

---

## 8. DNS D3 — primario caído, secundario responde

**Comando:** `systemctl stop named` en el primario; consultar a los dos; luego start.
**Salida:** primario "connection refused"; secundario sigue respondiendo SOA y www.

**[CAPTURA: terminal con primario rechazando y secundario respondiendo]**

**Interpretación:** con dos NS, si el primario cae el secundario mantiene el servicio
autoritativo. Alta disponibilidad del DNS.

---

## 9. DNS D4 — Round Robin

**Comando:** `dig @23.21.163.138 www.xtz.lat A +short` repetido; también a 8.8.8.8.
**Salida:** las dos IPs, con el orden rotando entre consultas.

**[CAPTURA: CloudShell con varias consultas mostrando el orden que rota]**

**Interpretación:** el DNS rota el orden (Round Robin) pero no garantiza reparto 50/50 ni
retira IPs caídas; eso lo hace HAProxy.

---

## 10. DNS D5 — balanceador caído sigue anunciado

**Comando:** `stop-instances` HAProxy-2; `dig @23.21.163.138 www.xtz.lat A +short`; start.
**Salida:** el DNS sigue devolviendo 18.232.215.62 aunque HAProxy-2 está apagado.

**[CAPTURA: CloudShell mostrando que el DNS sigue dando las 2 IPs con HAProxy-2 apagado]**

**Interpretación:** limitación de disponibilidad del DNS Round Robin: no sabe que un
balanceador cayó. Contraste con el health-check de HAProxy (B2).

---

## 11. Balanceo B1 — reparto entre las dos WordPress

**Comando (en un HAProxy o por la IP pública):**
```
for i in $(seq 8); do curl -s http://127.0.0.1/ | grep -o 'IPv4 privada: 10\.0\.[0-9.]*'; done
```
**Salida:** alterna 10.0.2.10 y 10.0.4.10.

**[CAPTURA: terminal con la lista de IPs alternando]**

**[CAPTURA: navegador, dos recargas de www.xtz.lat con banner distinto (10.0.2.10 y 10.0.4.10)]**

**Interpretación:** HAProxy reparte petición por petición entre las dos WordPress, sin
afinidad de sesión y sin caché, por eso el banner cambia.

---

## 12. Balanceo B2 — caída de una WordPress  (PENDIENTE de correr si se desea)

**Idea:** apagar WordPress-2; hacer varias peticiones a los HAProxy; el sitio sigue
respondiendo siempre con 10.0.2.10 (WordPress-1). Reencender WordPress-2.

**[CAPTURA: peticiones respondiendo solo con la WordPress viva mientras la otra está apagada]**

---

## 13. Seguridad y administración

**[CAPTURA: consola EC2 → Security Groups del proyecto]**

**[CAPTURA: Session Manager conectado a una instancia (sin usar SSH / puerto 22 cerrado)]**

Reglas resumidas:
- NAT: todo desde su subred privada.
- HAProxy: HTTP/80 desde Internet.
- BIND: 53 TCP/UDP desde Internet.
- WordPress: 80 solo desde los dos HAProxy.
- MariaDB: 3306 solo desde las dos WordPress.
- Puerto 22 cerrado en todas.
