# Proyecto N2 — SI3002

Sitio WordPress de XYZ S.A. en AWS Academy Learner Lab, región `us-east-1`. Nueve EC2 `t2.micro` con Ubuntu 24.04: NAT con nftables, HAProxy, BIND9 y MariaDB. El dominio publicado es http://www.xtz.lat.

Integrantes: Juan José Palacio, Alejandro Correa y Samuel Granados.

## Qué hay en el repositorio

```
scripts/aws/          VPC, security groups y las nueve EC2
scripts/nat/          NAT con nftables
scripts/haproxy/      los dos balanceadores
scripts/bind9/        primario, secundario y transferencia
scripts/wordpress/    MariaDB, WordPress y el banner de IP privada
diagramas/            arquitectura
docs/documento-final/ documento de entrega
```

El documento de entrega es `docs/documento-final/documento-final.md`. La versión para subir está en `documento-final-entrega.docx`.
