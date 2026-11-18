# Cómo retomar el proyecto (guía rápida)

Estado al 18 nov 2026. Todo lo de infraestructura ya está montado en el Learner Lab.

## Lo que YA quedó funcionando

- Red (VPC, 4 subredes, 2 AZ, rutas, security groups)
- 9 EC2 (t2.micro) corriendo
- 4 Elastic IP fijas (no cambian con reinicios):
  - HAProxy-1: 18.214.151.88
  - HAProxy-2: 18.232.215.62
  - BIND-primario (ns1): 23.21.163.138
  - BIND-secundario (ns2): 52.2.122.81
- Los 2 NAT (nftables) funcionando
- MariaDB (base compartida, 10.0.4.20)
- WordPress-1 (10.0.2.10) y WordPress-2 (10.0.4.10) con banner de IP privada
- Los 2 HAProxy balanceando entre las dos WordPress
- Los 2 BIND (primario/secundario) autoritativos de **xtz.lat** con transferencia de zona

**Dominio real:** `xtz.lat` (Namecheap)
**Dominio temporal que todavía usan las WordPress:** `xyz-lab.com` (hay que cambiarlo)

## Lo que falta

### 1. Delegación en Namecheap (la hacen los compañeros)
En Namecheap → Domain List → xtz.lat → Manage → Advanced DNS → Personal DNS Server:
- ns1 -> 23.21.163.138
- ns2 -> 52.2.122.81
Luego, pestaña Domain → Nameservers → Custom DNS:
- ns1.xtz.lat
- ns2.xtz.lat

### 2. Cuando la delegación esté hecha: comprobar que resuelve desde fuera
Desde cualquier PC (o el celular con datos):
```
dig NS xtz.lat +trace
dig www.xtz.lat A
dig @23.21.163.138 xtz.lat SOA
dig @52.2.122.81 xtz.lat SOA
```
La delegación puede tardar minutos u horas en propagarse (TTL). Mientras tanto,
`dig @23.21.163.138 ...` (consulta directa al BIND) ya funciona.

### 3. Cambiar el dominio temporal por el real en las dos WordPress
En WordPress-1 y WordPress-2 (Session Manager, como root):
```
cd /var/www/html
wp option update home 'http://www.xtz.lat' --allow-root
wp option update siteurl 'http://www.xtz.lat' --allow-root
```

### 4. Pruebas que faltan (evidencia para el documento)
- NAT: N2 (conntrack), N3 (apagar ip_forward), N4 (entrante vs saliente)
- DNS: D1 a D5 (dig contra los dos BIND, cambiar serial, apagar primario, round robin)
- Balanceo: B2 (apagar una WordPress y ver que el sitio sigue)
- Capturas de tráfico (tcpdump): DNS, TCP (3-way handshake), HTTP, NAT

### 5. Documento final IEEE (docs/documento-final/documento-ieee.md)
Rellenar nombres, pegar figuras y resultados medidos, exportar a PDF, subir el 20 nov.

## IMPORTANTE sobre el Learner Lab
- Se apaga solo cada ~4 horas. Al reiniciar, las 9 EC2 quedan "stopped" y luego arrancan.
- Las 4 Elastic IP NO cambian. Las IP privadas tampoco.
- Lo configurado adentro (NAT, WordPress, BIND, MariaDB) queda guardado en disco.
- Hacer las pruebas de DNS y la demo con el lab encendido, idealmente en una sola sesión.
- El día de la sustentación: encender el lab, esperar que las 9 estén "running", y verificar
  que el sitio responde y que dig sigue viendo los NS propios.
