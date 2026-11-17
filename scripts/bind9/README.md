# BIND9 primario y secundario

| Script | Máquina | IP privada |
|---|---|---|
| `configurar-bind-primario.sh` | BIND primario | `10.0.1.30` |
| `configurar-bind-secundario.sh` | BIND secundario | `10.0.3.30` |

## Antes de ejecutarlos

1. Las cuatro máquinas públicas ya tienen IP pública: los dos BIND y los dos HAProxy.
2. Anota esas IP. En cada máquina: `curl -4 https://ifconfig.me`.
3. Edita `DOMINIO` en los dos scripts. Tiene que ser un dominio o subdominio **real**, con control en el registrador. Un nombre inventado solo dentro del laboratorio no cumple el enunciado.
4. En el primario, llena `IP_NS2_PUBLICA`, `IP_WEB_1` y `IP_WEB_2`.

## Orden

```bash
# 1) En BIND-primario (10.0.1.30), después de editar las variables:
sudo bash configurar-bind-primario.sh

# 2) En BIND-secundario (10.0.3.30), con el mismo DOMINIO:
sudo bash configurar-bind-secundario.sh
```

## Qué publica la zona

- SOA, con TTL de 60 segundos para que las pruebas D2, D4 y D5 no se queden pegadas a una caché larga.
- NS de `ns1` y `ns2`.
- A de `ns1` y `ns2` hacia las IP públicas de los dos BIND.
- Dos A de `www` hacia las IP públicas de los dos HAProxy (DNS Round Robin).
- Dos A del dominio pelado hacia los mismos HAProxy.
- CNAME `inicio` hacia `www` (la prueba D1 pide un CNAME).

La transferencia de zona sale del primario hacia la IP privada del secundario (`10.0.3.30`), por TCP 53.

## Delegación en el registrador

En el registrador del dominio, los servidores de nombres del dominio quedan así:

- `ns1.TUDOMINIO` → IP pública del BIND primario
- `ns2.TUDOMINIO` → IP pública del BIND secundario

Eso es la delegación pública. Sin ese paso, `dig` contra las IP de las EC2 funciona, pero desde un resolvedor de Internet el dominio sigue en los DNS del registrador y la entrega no cumple.

Si el Learner Lab cambia las IP públicas al detener una instancia, hay que actualizar la zona **y** la delegación. Conviene no apagar estas cuatro EC2 después de delegar. Si la cuenta deja crear Elastic IP, asócialas a los dos BIND y a los dos HAProxy y usa esas IP en la zona.

## Cambio de un registro (prueba D2)

1. Edita `/etc/bind/zones/db.TUDOMINIO` en el primario.
2. Sube el serial del SOA (el número de 10 dígitos). Si no sube, el secundario no se entera.
3. `sudo rndc reload`
4. En el secundario: `sudo rndc retransfer TUDOMINIO`
5. Compara `dig @IP_PRIMARIO TUDOMINIO SOA` y `dig @IP_SECUNDARIO TUDOMINIO SOA`.

La guía general está en `COMO-SE-HIZO.md`. Las pruebas D1–D5 están en `docs/pruebas/plantilla-11-pruebas.md`.
