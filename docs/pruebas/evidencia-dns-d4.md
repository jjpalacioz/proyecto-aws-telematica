# Evidencia — Prueba DNS D4

**Prueba:** Consultar repetidamente `www` desde el autoritativo y desde resolvedores
recursivos; registrar las dos direcciones A, el orden de respuesta y el efecto del
TTL/caché. Explicar por qué esto NO prueba un reparto uniforme de conexiones HTTP.

**Fecha:** 19 nov 2026
**Dominio:** `xtz.lat`

## Procedimiento

```bash
# Al autoritativo (BIND-primario), varias veces:
for i in 1 2 3 4 5 6 ; do dig @23.21.163.138 www.xtz.lat A +short | tr '\n' ' '; echo; done
# A un resolvedor publico (Google):
for i in 1 2 3 ; do dig @8.8.8.8 www.xtz.lat A +short | tr '\n' ' '; echo; done
```

## Salida obtenida

```
=== autoritativo 23.21.163.138 ===
18.232.215.62 18.214.151.88
18.214.151.88 18.232.215.62
18.232.215.62 18.214.151.88
18.214.151.88 18.232.215.62
18.214.151.88 18.232.215.62
18.232.215.62 18.214.151.88

=== resolvedor publico 8.8.8.8 ===
18.232.215.62 18.214.151.88
18.214.151.88 18.232.215.62
18.232.215.62 18.214.151.88
```

## Interpretación

- `www.xtz.lat` tiene **dos registros A** (18.214.151.88 y 18.232.215.62, los dos HAProxy).
- El autoritativo **rota el orden** de las dos direcciones entre consultas: eso es
  **DNS Round Robin**.
- El resolvedor público (8.8.8.8) también devuelve las dos direcciones: la delegación
  funciona desde fuera.
- **Por qué esto NO prueba reparto uniforme de conexiones HTTP:** la mayoría de clientes
  usa la **primera** dirección de la lista que recibe, y el orden que ve un cliente
  depende de su resolvedor y de la caché (durante el TTL, un resolvedor puede entregar
  siempre el mismo orden). Así que DNS Round Robin reparte "a grandes rasgos" entre
  balanceadores, pero no garantiza 50/50, y no retira una IP caída automáticamente.
- El reparto fino, petición por petición, y el retiro de un backend caído lo hace
  **HAProxy** (balanceo HTTP), no el DNS. Ver pruebas B1 y B2.

## Protocolos
- DNS sobre UDP/53. Registros A múltiples para un mismo nombre. TTL de 60 s.
