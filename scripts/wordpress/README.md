# WordPress y MariaDB

| Script | Máquina | IP |
|---|---|---|
| `configurar-mariadb.sh` | Base de datos | `10.0.4.20` |
| `configurar-wordpress.sh` con `ROL=primario` | WordPress-1 | `10.0.2.10` |
| `configurar-wordpress.sh` con `ROL=secundario` | WordPress-2 | `10.0.4.10` |

## Antes de ejecutarlos

1. Los dos NAT ya funcionan. Estas tres máquinas son privadas y `apt` sale por el NAT de su AZ.
2. Edita `DB_PASS` en `configurar-mariadb.sh` y en `configurar-wordpress.sh`. Tiene que quedar igual.
3. Edita `DOMINIO` en el script de WordPress. Es el mismo dominio de BIND.
4. En WordPress-2 cambia `ROL="secundario"`.

## Orden

```bash
# En 10.0.4.20
sudo bash configurar-mariadb.sh

# En 10.0.2.10
sudo bash configurar-wordpress.sh

# En 10.0.4.10, después de cambiar ROL
sudo bash configurar-wordpress.sh
```

## Qué queda compartido y qué no

- Compartido: la base MariaDB (páginas, entradas, usuarios, opciones). Las dos WordPress leen y escriben la misma base.
- No compartido: `wp-content/uploads` de cada EC2. Una imagen subida en un servidor no existe en el otro. El sitio de demostración usa texto en la base por eso.
- Un solo punto de falla: si se apaga `10.0.4.20`, las dos WordPress dejan de poder armar la página. El enunciado pide dejar esto escrito.

## La IP privada en el home

`wp-content/mu-plugins/mostrar-ip-privada.php` imprime, en cada HTML, la IPv4 de la EC2 que generó esa respuesta (`SERVER_ADDR`). También manda `Cache-Control: no-store` y desactiva la redirección canónica, para que la prueba B1 no se esconda detrás de una caché ni de un salto al otro balanceador.

Comprobación dentro de cada WordPress:

```bash
curl -s http://127.0.0.1/ | grep "IPv4 privada"
```

La guía general está en `COMO-SE-HIZO.md`.
