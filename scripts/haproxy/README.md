# HAProxy

El mismo script se ejecuta en **HAProxy-1** (`10.0.1.20`) y en **HAProxy-2** (`10.0.3.20`).

```bash
sudo bash configurar-haproxy.sh
```

Qué deja configurado:

- Escucha en el puerto 80.
- Reparte en round-robin entre `10.0.2.10` y `10.0.4.10`.
- Chequeo HTTP cada 3 segundos. Dos fallos seguidos sacan al servidor.
- Sin cookie de afinidad y sin caché.
- `option http-server-close` para que varias peticiones seguidas no se queden en el mismo WordPress.
- Estadísticas en `http://127.0.0.1:8404/stats` (solo desde la propia EC2).

Hay que correrlo **después** de que las dos WordPress respondan en el puerto 80. Si se corre antes, HAProxy arranca igual y marca los backends DOWN hasta que WordPress responda.

Comprobación rápida, dentro de la instancia:

```bash
systemctl status haproxy
curl -s http://127.0.0.1:8404/stats | grep -E 'wp1|wp2'
```

La guía del proyecto y las pruebas B1 y B2 están en `COMO-SE-HIZO.md` y en `docs/pruebas/plantilla-11-pruebas.md`.
