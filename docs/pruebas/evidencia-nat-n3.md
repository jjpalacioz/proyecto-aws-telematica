# Evidencia — Prueba NAT N3

**Prueba:** Desactivar temporalmente IP forwarding en una instancia NAT, repetir la
conexión desde la subred privada correspondiente y explicar la falla. Restaurar al final.

**Fecha:** 19 nov 2026
**NAT:** NAT-1 (10.0.1.10)  ·  **Cliente privado:** WordPress-1 (10.0.2.10)

## Procedimiento

```bash
# En NAT-1 (root): apagar el reenvio de paquetes
sysctl -w net.ipv4.ip_forward=0        # -> net.ipv4.ip_forward = 0

# En WordPress-1: intentar salir a Internet -> falla (timeout, sin IP)
curl -s --max-time 10 https://ifconfig.me    # queda vacio

# En NAT-1 (root): restaurar
sysctl -w net.ipv4.ip_forward=1        # -> net.ipv4.ip_forward = 1

# En WordPress-1: reintentar -> ahora si responde con la IP publica del NAT
curl -s --max-time 10 https://ifconfig.me    # -> 32.202.144.94 (IP publica de NAT-1)
```

## Salida obtenida

```
# NAT-1
net.ipv4.ip_forward = 0     (forwarding APAGADO)
net.ipv4.ip_forward = 1     (forwarding ENCENDIDO de nuevo)

# WordPress-1, tras restaurar:
32.202.144.94               (sale a Internet de nuevo con la IP del NAT)
```

## Interpretación

- Con `net.ipv4.ip_forward=0`, el kernel de Linux de NAT-1 **deja de reenviar** paquetes
  entre interfaces: recibe los paquetes de WordPress-1 pero no los pasa hacia Internet,
  así que la conexión desde la subred privada se queda sin respuesta (timeout).
- Esto demuestra que el reenvío de IP es **condición necesaria** para que la instancia
  actúe como router/NAT. Las reglas de nftables (masquerade) por sí solas no bastan si el
  kernel no reenvía.
- Al volver a `net.ipv4.ip_forward=1`, WordPress-1 recupera la salida y el destino observa
  la IP pública de NAT-1 (32.202.144.94), confirmando que el NAT volvió a funcionar.
- Nota: la IP pública de NAT-1 cambió respecto a sesiones anteriores porque los NAT usan
  IP pública normal (no Elastic). Eso no afecta al proyecto: las privadas los alcanzan por
  su IP privada fija (10.0.1.10), que es la que está en la tabla de rutas.

## Protocolos
- IP (reenvío a nivel de kernel). El sysctl net.ipv4.ip_forward controla si el host
  reenvía datagramas IP que no son para él.
