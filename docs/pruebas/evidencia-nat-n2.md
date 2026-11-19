# Evidencia — Prueba NAT N2

**Prueba:** Generar conexiones TCP desde clientes privados y analizar con conntrack las
asociaciones de direcciones y puertos antes y después de NAT. Identificar qué NAT atiende
cada subred privada y explicar la traducción de puertos.

**Fecha:** 19 nov 2026
**Cliente privado:** WordPress-1 (10.0.2.10)  ·  **NAT:** NAT-1 (10.0.1.10)

## Procedimiento

En NAT-1 (como root) se escuchan los eventos de conntrack de ese cliente:
```bash
conntrack -E -p tcp | grep --line-buffered "10.0.2.10"
```
En WordPress-1 se genera tráfico TCP/443 hacia Internet:
```bash
curl -s https://api.github.com > /dev/null
curl -s https://www.google.com > /dev/null
```

## Salida obtenida (en NAT-1)

```
[NEW]    tcp SYN_SENT    src=10.0.2.10 dst=13.217.79.194 sport=34726 dport=443 [UNREPLIED] src=13.217.79.194 dst=10.0.1.10 sport=443 dport=34726
[UPDATE] tcp SYN_RECV    src=10.0.2.10 dst=13.217.79.194 sport=34726 dport=443          src=13.217.79.194 dst=10.0.1.10 sport=443 dport=34726
[UPDATE] tcp ESTABLISHED src=10.0.2.10 dst=13.217.79.194 sport=34726 dport=443          src=13.217.79.194 dst=10.0.1.10 sport=443 dport=34726 [ASSURED]
[NEW]    tcp SYN_SENT    src=10.0.2.10 dst=98.87.175.214 sport=45126 dport=443 ...
[UPDATE] tcp ESTABLISHED src=10.0.2.10 dst=98.87.175.214 sport=45126 dport=443 ... [ASSURED]
```

## Interpretación

Cada entrada de conntrack tiene dos tuplas:

- **Tupla original (ida):** `src=10.0.2.10 ... dport=443`. Es el paquete tal como sale
  del cliente privado WordPress-1 hacia el servidor de Internet.
- **Tupla de respuesta (vuelta):** `... dst=10.0.1.10 ...`. Es cómo debe volver la
  respuesta: dirigida a **10.0.1.10, la IP de NAT-1**, no a 10.0.2.10.

Esto evidencia la traducción de origen (SNAT/masquerade): NAT-1 reescribe el origen de la
máquina privada por su propia dirección y recuerda la asociación en la tabla conntrack
para reenviar la respuesta al cliente correcto. El puerto de origen (sport) se usa para
diferenciar conexiones; si dos clientes usaran el mismo puerto, el NAT lo reescribiría
(PAT) para que la pareja (IP,puerto) sea única.

- NAT-1 atiende la subred privada 1 (10.0.2.0/24). NAT-2 atiende la privada 2 (10.0.4.0/24).
- Estados observados: `SYN_SENT` → `SYN_RECV` → `ESTABLISHED [ASSURED]`, que es el
  progreso normal del saludo TCP de tres vías visto desde el seguimiento de conexiones.

## Protocolos
- IP + TCP. Seguimiento de conexiones (conntrack) y traducción de direcciones/puertos (NAT).
