# Evidencia — Prueba NAT N1

**Prueba:** Desde una instancia privada sin IP pública, hacer una solicitud a un
destino externo y registrar la IP pública que observa el destino.

**Fecha:** 18 nov 2026
**Instancia de origen:** WordPress-1 (subred privada 1, sin IP pública)

## Procedimiento

Desde WordPress-1 (entrada por Session Manager, que a su vez sale a Internet por NAT-1):

```bash
hostname -I            # IP privada de la instancia
curl -s https://ifconfig.me   # IP pública vista desde Internet
ip route | grep default       # ruta por defecto
```

## Salida obtenida

```
=== IP privada de WordPress-1 ===
10.0.2.10
=== IP publica que ve internet (debe ser la de NAT-1) ===
13.220.34.110
=== Ruta por defecto ===
default via 10.0.2.1 dev enX0 proto dhcp src 10.0.2.10 metric 100
```

## Interpretación

- WordPress-1 tiene IP privada `10.0.2.10` y **no tiene IP pública**.
- Al salir a Internet, el destino observa la IP pública **13.220.34.110**, que es la
  IP pública de NAT-1. Esto demuestra la traducción de origen (SNAT/masquerade):
  NAT-1 reemplaza la IP privada de WordPress-1 por la suya propia.
- La ruta por defecto de la subred privada envía `0.0.0.0/0` hacia el router de la
  VPC, que según la tabla de rutas de AWS reenvía a la instancia NAT-1.

## Protocolos involucrados
- IP: direccionamiento origen/destino y la reescritura de la dirección de origen en el NAT.
- TCP + TLS: la petición HTTPS a ifconfig.me.
- La diferencia con el Internet Gateway: el IGW solo da salida a instancias con IP
  pública. WordPress-1 no la tiene; por eso necesita el NAT de Linux, que le presta
  la suya. El IGW nunca ve la IP `10.0.2.10`: para él, el cliente es NAT-1.
