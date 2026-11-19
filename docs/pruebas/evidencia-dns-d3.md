# Evidencia — Prueba DNS D3

**Prueba:** Detener temporalmente el DNS primario y comprobar que el secundario sigue
respondiendo autoritativamente. Distinguir disponibilidad del autoritativo del
comportamiento del resolvedor recursivo.

**Fecha:** 19 nov 2026
**Dominio:** `xtz.lat`
**Primario:** 10.0.1.30 (ns1)  ·  **Secundario:** 10.0.3.30 (ns2)

## Procedimiento

```bash
# En el primario:
systemctl stop named          # se detiene el DNS primario
# Consultas:
dig @10.0.1.30 xtz.lat SOA +short +time=3 +tries=1   # primario (debe fallar)
dig @10.0.3.30 xtz.lat SOA +short                    # secundario (debe responder)
dig @10.0.3.30 www.xtz.lat A +short
# Restaurar:
systemctl start named
```

## Salida obtenida

```
=== primario (detenido) ===
;; communications error to 10.0.1.30#53: connection refused
;; no servers could be reached

=== secundario (sigue respondiendo) ===
ns1.xtz.lat. hostmaster.xtz.lat. 2026111802 60 60 1209600 60
18.214.151.88
18.232.215.62

=== primario de nuevo arriba ===
ns1.xtz.lat. hostmaster.xtz.lat. 2026111802 60 60 1209600 60
```

## Interpretación

- Con el primario detenido, consultarlo directamente da `connection refused`: el
  servicio no está escuchando en el 53 de 10.0.1.30.
- El secundario sigue respondiendo de forma **autoritativa** el SOA y los registros A de
  `www`. El dominio sigue resolviendo porque hay dos NS publicados y uno sigue vivo.
- Distinción importante: esta prueba se hace con `dig @IP-del-secundario`, que consulta
  directo al autoritativo. Un **resolvedor recursivo público** podría seguir entregando
  la respuesta desde su caché aunque los dos autoritativos estuvieran caídos (mientras no
  venza el TTL); por eso la prueba de disponibilidad del autoritativo se hace consultando
  al servidor directamente, no a través de un resolvedor.
- Tras reiniciar el primario, vuelve a responder con el mismo serial.

## Protocolos
- DNS sobre UDP/53. "connection refused" indica que no hay servicio escuchando (no es
  un timeout de red, sino rechazo de conexión porque named está detenido).
