# Chuleta de comandos — para la sustentación

Comandos clave usados en el proyecto, con qué hace cada uno. Por si el profe pregunta
"¿qué comandos usaste?".

## NAT (instancias NAT-1 y NAT-2)

| Comando | Qué hace |
|---|---|
| `sysctl -w net.ipv4.ip_forward=1` | Activa IP forwarding: Linux actúa como router. Sin esto el NAT no reenvía. |
| `nft add rule ip nat postrouting ip saddr 10.0.2.0/24 oifname "enX0" masquerade` | Regla de NAT: reescribe la IP de origen de la red privada por la del NAT (masquerade). |
| `nft list ruleset` | Muestra las reglas de NAT activas. |
| `conntrack -L` / `conntrack -E` | Tabla/eventos de traducción de conexiones (qué se tradujo a qué). |

## DNS (instancias BIND)

| Comando | Qué hace |
|---|---|
| `named-checkzone xtz.lat /etc/bind/zones/db.xtz.lat` | Verifica que el archivo de zona esté bien. |
| `named-checkconf` | Verifica la configuración de BIND. |
| `rndc reload xtz.lat` | Recarga la zona tras un cambio. |
| `rndc retransfer xtz.lat` | Fuerza al secundario a pedir la zona al primario. |
| `dig @23.21.163.138 xtz.lat SOA` | Consulta el SOA (serial). |
| `dig www.xtz.lat A` | Consulta las IPs del sitio (muestra Round Robin). |
| `dig NS xtz.lat` | Muestra la delegación (ns1, ns2). |

## Balanceo (instancias HAProxy)

| Comando | Qué hace |
|---|---|
| `systemctl status haproxy` | Ver que HAProxy corre. |
| `for i in $(seq 8); do curl -s http://127.0.0.1/ \| grep 'IPv4 privada'; done` | Demuestra el balanceo: la IP alterna entre los dos WordPress. |

## AWS / administración (CloudShell)

| Comando | Qué hace |
|---|---|
| `aws ec2 describe-instances` | Lista las instancias (ver las 9). |
| `aws ec2 run-instances ...` | Lanza una instancia EC2. |
| `aws ec2 modify-instance-attribute --no-source-dest-check` | Desactiva el Source/Dest Check del NAT (clave). |
| `aws ec2 allocate-address` / `associate-address` | Reserva y asigna una Elastic IP (IP fija). |

## Conexión

| Cómo | Qué es |
|---|---|
| AWS Session Manager | Entrada a las máquinas sin abrir SSH (puerto 22 cerrado). |
| `sudo su -` | Pasar a root dentro de la máquina. |

## Los 5 que hay que saberse sí o sí

1. `sysctl -w net.ipv4.ip_forward=1`  — activar el router/NAT
2. `nft ... masquerade`               — la regla de traducción del NAT
3. `dig www.xtz.lat`                  — consultar el DNS
4. `rndc reload` / `rndc retransfer`  — recargar / transferir la zona DNS
5. `aws ec2 modify-instance-attribute --no-source-dest-check` — desactivar chequeo del NAT
