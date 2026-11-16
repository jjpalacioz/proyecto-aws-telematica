# NAT casero con nftables

Este instructivo explica qué hacer con `configurar-nat.sh`.

## ¿Qué máquinas lo usan?

- **NAT-1** → en subred pública 1 (`us-east-1a`). Atiende a la privada 1 (`10.0.2.0/24`).
- **NAT-2** → en subred pública 2 (`us-east-1b`). Atiende a la privada 2 (`10.0.4.0/24`).

Es el **mismo script** en las dos. Lo único que cambia es la variable `RED_PRIVADA` dentro del archivo:
- En NAT-1 déjala en `10.0.2.0/24`.
- En NAT-2 cámbiala a `10.0.4.0/24`.

## Pasos (se hacen 2 veces, una por cada NAT)

### 1. En la consola de AWS (ANTES de configurar nada por dentro)
Desactiva el chequeo de origen/destino, o el NAT no reenvía nada:
> EC2 → selecciona la instancia NAT → **Actions → Networking → Change source/destination check → Stop checking** → Save.

### 2. Entra a la instancia
Usa **Session Manager** (EC2 → selecciona la instancia → Connect → Session Manager).

### 3. Ejecuta el script
```bash
sudo su -
# pega aquí el contenido de configurar-nat.sh
# (en NAT-2 recuerda cambiar RED_PRIVADA a 10.0.4.0/24 antes de pegar)
```

### 4. Verifica
```bash
sysctl net.ipv4.ip_forward      # debe mostrar: net.ipv4.ip_forward = 1
nft list ruleset                # debe mostrar la regla "masquerade"
```

---

## Pruebas obligatorias del PDF (NAT N1–N4)

Estas pruebas se hacen DESPUÉS de tener todo montado. Las dejo aquí para que las tengas a mano. La evidencia (capturas, salidas de comandos) va en `docs/pruebas/`.

### NAT N1 — Salida a Internet desde una privada
Desde una instancia **privada** (WordPress), sin IP pública:
```bash
curl -s https://ifconfig.me          # te devuelve la IP pública vista desde afuera
ip route                              # muestra que la ruta por defecto va al NAT
```
**Qué registrar:** la IP pública que ve el destino (será la del NAT, no la del WordPress).

### NAT N2 — Ver la traducción con conntrack
En la instancia **NAT**, mientras la privada hace tráfico:
```bash
conntrack -L | grep <IP_privada>      # muestra la asociación antes/después de NAT
```
**Qué registrar:** cómo la IP privada + puerto se traducen a la IP del NAT + otro puerto.

### NAT N3 — Apagar IP forwarding y ver que falla
En la instancia **NAT**:
```bash
sysctl -w net.ipv4.ip_forward=0       # lo apagas
# desde la privada, intenta: curl https://ifconfig.me  -> ahora FALLA (timeout)
sysctl -w net.ipv4.ip_forward=1       # lo vuelves a encender (restaurar)
```
**Qué explicar:** sin forwarding, el NAT recibe el paquete pero no lo reenvía.

### NAT N4 — Conexión saliente vs. entrante
Compara:
- Una conexión que **inicia** la privada hacia afuera → funciona (el NAT la recuerda).
- Un intento de conexión **desde afuera hacia** la privada → NO funciona (no hay IP pública ni regla que lo permita).

**Qué explicar:** el NAT solo deja pasar respuestas a conexiones que empezaron desde adentro.
