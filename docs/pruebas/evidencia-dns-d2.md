# Evidencia — Prueba DNS D2

**Prueba:** Modificar un registro en el primario, actualizar el serial SOA y comprobar
la transferencia y sincronización en el secundario.

**Fecha:** 19 nov 2026
**Dominio:** `xtz.lat`
**Primario:** 10.0.1.30 (ns1)  ·  **Secundario:** 10.0.3.30 (ns2)

## Procedimiento

1. Estado inicial: ambos servidores con serial `2026111801`.
2. En el primario (como root) se sube el serial a `2026111802` y se agrega un registro
   de prueba `prueba.xtz.lat A 10.9.9.9`, y se recarga la zona:
   ```bash
   ZONA="/etc/bind/zones/db.xtz.lat"
   sed -i 's/2026111801/2026111802/' "$ZONA"
   echo "prueba   IN  A   10.9.9.9" >> "$ZONA"
   rndc reload xtz.lat
   ```
3. Se consulta a los dos servidores.

## Salida obtenida

```
=== primario ===
ns1.xtz.lat. hostmaster.xtz.lat. 2026111802 60 60 1209600 60
10.9.9.9
=== secundario ===
ns1.xtz.lat. hostmaster.xtz.lat. 2026111802 60 60 1209600 60
10.9.9.9
```

## Interpretación

- El primario pasó al serial `2026111802` e incorporó `prueba.xtz.lat`.
- El secundario, sin editarse a mano, muestra **el mismo serial nuevo** y **el registro
  nuevo**: recibió la zona completa por transferencia (AXFR/IXFR) tras el `notify` del
  primario.
- Esto prueba el mecanismo primario/secundario: el serial es la señal que usa el
  secundario para saber que hay una versión más nueva y pedir la transferencia. Si el
  serial no se sube, el secundario no se actualiza.

## Limpieza
El registro `prueba.xtz.lat` es solo para esta prueba. Se puede quitar de la zona y
volver a subir el serial antes de la entrega, si se desea dejar la zona limpia.

## Protocolos
- DNS NOTIFY (primario avisa al secundario) + transferencia de zona por TCP/53 (AXFR/IXFR).
