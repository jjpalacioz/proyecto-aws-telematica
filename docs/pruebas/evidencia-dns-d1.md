# Evidencia — Prueba DNS D1

**Prueba:** Consultar directamente a los dos servidores DNS autoritativos los registros
SOA, NS, A y CNAME. Identificar respuesta autoritativa, TTL y la delegación pública.

**Fecha:** 19 nov 2026
**Dominio:** `xtz.lat`
**Autoritativos:** ns1 (23.21.163.138, BIND-primario) y ns2 (52.2.122.81, BIND-secundario)

## Procedimiento y comandos

Desde AWS CloudShell (con bind-utils instalado):

```bash
dig @23.21.163.138 xtz.lat SOA +noall +answer +authority
dig @52.2.122.81  xtz.lat SOA +noall +answer
dig @23.21.163.138 xtz.lat NS  +noall +answer
dig @23.21.163.138 www.xtz.lat A +noall +answer
dig @23.21.163.138 inicio.xtz.lat CNAME +noall +answer
dig xtz.lat NS +short      # delegacion publica, sin fijar servidor
```

## Salida obtenida

```
===== SOA PRIMARIO =====
xtz.lat.  60  IN  SOA  ns1.xtz.lat. hostmaster.xtz.lat. 2026111801 60 60 1209600 60
xtz.lat.  60  IN  NS   ns2.xtz.lat.
xtz.lat.  60  IN  NS   ns1.xtz.lat.

===== SOA SECUNDARIO =====
xtz.lat.  60  IN  SOA  ns1.xtz.lat. hostmaster.xtz.lat. 2026111801 60 60 1209600 60

===== NS =====
xtz.lat.  60  IN  NS   ns1.xtz.lat.
xtz.lat.  60  IN  NS   ns2.xtz.lat.

===== A de www =====
www.xtz.lat.  60  IN  A  18.214.151.88
www.xtz.lat.  60  IN  A  18.232.215.62

===== CNAME inicio =====
inicio.xtz.lat.  60  IN  CNAME  www.xtz.lat.

===== delegacion publica =====
ns2.xtz.lat.
ns1.xtz.lat.
```

## Interpretación

- Los dos servidores autoritativos responden el registro SOA con **el mismo serial
  `2026111801`**, lo que confirma que la transferencia de zona primario→secundario
  está sincronizada.
- Hay dos registros NS (`ns1`, `ns2`) y dos registros A para `www` (18.214.151.88 y
  18.232.215.62), que son las dos instancias HAProxy: esto implementa **DNS Round Robin**.
- El CNAME `inicio.xtz.lat` apunta a `www.xtz.lat`.
- El TTL de todos los registros es 60 s (bajo a propósito, para que en el laboratorio
  las cachés no retengan respuestas viejas durante las pruebas D2/D4/D5).
- La consulta sin fijar servidor (`dig xtz.lat NS`) devuelve ns1 y ns2: la **delegación
  pública** está activa, el registrador delegó el dominio a nuestros servidores.

## Protocolos
- DNS sobre UDP/53 para las consultas.
- Registros SOA, NS, A y CNAME (los cuatro tipos que pide el enunciado).
