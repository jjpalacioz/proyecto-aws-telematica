# Evidencia — Prueba DNS D5

**Prueba:** Detener temporalmente uno de los balanceadores y comprobar que su registro A
sigue siendo anunciado por DNS. Explicar la limitación de disponibilidad de DNS Round
Robin y restaurar el servicio.

**Fecha:** 19 nov 2026
**Dominio:** `xtz.lat`

## Procedimiento

```bash
# Apagar HAProxy-2 (su Elastic IP es 18.232.215.62):
aws ec2 stop-instances --instance-ids <id-de-HAProxy-2>
sleep 40
# El DNS sigue anunciando las dos IPs:
dig @23.21.163.138 www.xtz.lat A +short
# Restaurar:
aws ec2 start-instances --instance-ids <id-de-HAProxy-2>
```

## Salida obtenida

```
=== El DNS sigue devolviendo las 2 IPs aunque HAProxy-2 este apagado ===
18.232.215.62      <- IP de HAProxy-2, que estaba APAGADO
18.214.151.88      <- IP de HAProxy-1
```

## Interpretación

- Con HAProxy-2 apagado, el DNS **sigue publicando su registro A** (18.232.215.62). El
  DNS autoritativo no monitorea el estado de los balanceadores: solo entrega lo que tiene
  en la zona.
- Consecuencia: una parte de los clientes que reciban primero la IP 18.232.215.62
  intentarán conectarse a un balanceador caído y fallarán hasta que el registro se quite
  a mano o venza alguna caché. **DNS Round Robin no retira automáticamente un nodo caído.**
- Contraste con HAProxy (balanceo HTTP): HAProxy hace health-check de sus backends y saca
  del reparto al WordPress que no responde, sin intervención manual (prueba B2).
- Por eso en la arquitectura se usan los dos mecanismos a distinto nivel: DNS Round Robin
  reparte entre balanceadores (a grandes rasgos) y HAProxy reparte entre servidores web
  (con health-check). Son complementarios, no equivalentes.

## Nota
HAProxy-2 tiene Elastic IP, así que al reiniciarlo mantiene 18.232.215.62 y no hay que
tocar la zona DNS. Tras arrancar, conviene verificar que el servicio haproxy quedó activo.
