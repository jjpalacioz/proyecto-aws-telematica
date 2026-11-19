# Diagramas de arquitectura

Estos dibujos describen el diseño del repositorio. Para el PDF de la entrega hay que exportarlos a imagen (captura de un visor de Mermaid, draw.io o la herramienta que usen) y numerarlos como figuras.

Todavía no hay una consola de AWS que fotografiar. Esas capturas salen el día que la VPC esté creada.

## Diagrama de arquitectura AWS (draw.io)

El archivo [`arquitectura-aws.drawio`](arquitectura-aws.drawio) contiene el diagrama de arquitectura con los iconos oficiales de AWS, listo para editar y exportar.

**Cómo abrirlo y exportarlo:**

1. Entra a [app.diagrams.net](https://app.diagrams.net) (draw.io).
2. `File → Open from → Device` y elige `arquitectura-aws.drawio`. También se puede importar desde GitHub con `File → Open from → GitHub`.
3. Para la figura del documento: `File → Export as → PNG` (o SVG/PDF), con fondo transparente o blanco.

**Qué muestra:**

- VPC `10.0.0.0/16` con las dos AZ (`us-east-1a` y `us-east-1b`).
- Las 4 subredes (2 públicas, 2 privadas) y las 9 instancias EC2 con su IP.
- Flujos: DNS `:53` (Round Robin a los dos BIND9), HTTP `:80` (Internet Gateway → HAProxy → WordPress, balanceo cruzado), MySQL `:3306` (WordPress → MariaDB).
- Salida a Internet de cada subred privada por la instancia NAT de su misma AZ.
- Transferencia de zona del BIND9 primario al secundario.

## Figura. Vista lógica de las 9 EC2

```mermaid
flowchart TB
  usuarios((Usuarios))
  igw[Internet Gateway]

  subgraph vpc ["VPC 10.0.0.0/16 · us-east-1"]
    subgraph aza ["us-east-1a"]
      subgraph pub1 ["Pública 10.0.1.0/24"]
        nat1["NAT-1<br/>10.0.1.10"]
        hap1["HAProxy-1<br/>10.0.1.20"]
        dns1["BIND primario<br/>10.0.1.30"]
      end
      subgraph priv1 ["Privada 10.0.2.0/24"]
        wp1["WordPress-1<br/>10.0.2.10"]
      end
    end
    subgraph azb ["us-east-1b"]
      subgraph pub2 ["Pública 10.0.3.0/24"]
        nat2["NAT-2<br/>10.0.3.10"]
        hap2["HAProxy-2<br/>10.0.3.20"]
        dns2["BIND secundario<br/>10.0.3.30"]
      end
      subgraph priv2 ["Privada 10.0.4.0/24"]
        wp2["WordPress-2<br/>10.0.4.10"]
        db[("MariaDB<br/>10.0.4.20")]
      end
    end
  end

  usuarios -->|DNS| dns1
  usuarios -->|DNS| dns2
  usuarios -->|HTTP| igw
  igw --> hap1
  igw --> hap2
  igw --> nat1
  igw --> nat2
  hap1 -->|HTTP| wp1
  hap1 -->|HTTP| wp2
  hap2 -->|HTTP| wp1
  hap2 -->|HTTP| wp2
  wp1 -->|MySQL| db
  wp2 -->|MySQL| db
  wp1 -->|salida| nat1
  db -->|salida| nat2
  wp2 -->|salida| nat2
  dns1 -.->|transferencia de zona| dns2
```

El tráfico HTTP entre un HAProxy y una WordPress, y el tráfico MySQL entre WordPress y MariaDB, usan la ruta local `10.0.0.0/16`. No pasan por el NAT.

## Figura. Petición de un visitante

```mermaid
sequenceDiagram
  participant U as Navegador
  participant R as Resolvedor
  participant D as BIND
  participant H as HAProxy
  participant W as WordPress
  participant B as MariaDB
  U->>R: ¿www.dominio A?
  R->>D: consulta autoritativa
  D-->>R: dos A, las IP públicas de los HAProxy
  R-->>U: una o las dos A, según orden y TTL
  U->>H: TCP 80 e HTTP GET
  H->>W: elige 10.0.2.10 o 10.0.4.10
  W->>B: lee la página
  B-->>W: contenido
  W-->>H: HTML con la IPv4 privada de esta EC2
  H-->>U: la misma respuesta
```

## Figura. Salida a Internet desde una privada

Hay dos traducciones, una detrás de la otra.

```mermaid
sequenceDiagram
  participant P as Privada 10.0.2.10
  participant N as NAT-1 nftables
  participant G as Internet Gateway
  participant X as Servidor en Internet
  P->>N: origen 10.0.2.10:puerto
  Note over N: masquerade y conntrack<br/>origen = 10.0.1.10:otro puerto
  N->>G: sale la instancia NAT
  Note over G: la IP pública de NAT-1<br/>es la que ve el destino
  G->>X: origen = IP pública de NAT-1
  X-->>G: respuesta
  G-->>N: entrega a 10.0.1.10
  Note over N: conntrack devuelve el paquete a 10.0.2.10
  N-->>P: respuesta
```

## Vista en texto, por si el visor no dibuja Mermaid

```
Internet
   |
   |  Internet Gateway
   |
   +-- us-east-1a
   |     Pública 10.0.1.0/24:  NAT-1 .10   HAProxy-1 .20   BIND primario .30
   |     Privada 10.0.2.0/24:  WordPress-1 .10
   |     La privada 1 sale por NAT-1
   |
   +-- us-east-1b
         Pública 10.0.3.0/24:  NAT-2 .10   HAProxy-2 .20   BIND secundario .30
         Privada 10.0.4.0/24:  WordPress-2 .10   MariaDB .20
         La privada 2 sale por NAT-2

HAProxy-1 y HAProxy-2 hablan con las dos WordPress.
Las dos WordPress hablan con MariaDB.
BIND primario transfiere la zona a BIND secundario.
```
