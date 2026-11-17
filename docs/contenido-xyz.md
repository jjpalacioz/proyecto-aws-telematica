# Textos para el sitio de XYZ S.A.

El script de WordPress ya crea cinco páginas con una versión corta de este texto. Si quieren ampliarlas, se pegan en el escritorio (Páginas) de cualquiera de las dos instancias: el texto queda en MariaDB y lo ven las dos.

No hace falta subir fotos. Un archivo en `wp-content/uploads` se queda en el disco de la EC2 donde se subió.

## Inicio

XYZ S.A. llega a Colombia. Esta página presenta la compañía, las sedes desde las que va a operar y los productos que pone a disposición del mercado colombiano.

El recuadro negro de la parte superior identifica el servidor que atendió esta visita. Al recargar a través del balanceador, esa dirección puede cambiar: el sitio está repartido entre dos servidores.

## La empresa

XYZ S.A. es una compañía de cosméticos con presencia en América Latina. Como parte de su entrada a Colombia definió tres sedes y encargó este sitio para publicar la información de la empresa y el contenido de sus productos.

La operación que ya existía sigue en el centro de datos de la sede principal, en Medellín. El sitio público se desplegó aparte, en la nube, para poder atender a varios visitantes al mismo tiempo y crecer agregando servidores web.

## Sedes

### Medellín

Sede principal. Aquí está el centro de datos de la compañía y las aplicaciones que siguen corriendo en la infraestructura propia. El sitio que estás viendo no sale de ese centro de datos: está publicado en AWS.

### Bogotá

Sede comercial para la región Andina. Es el punto de contacto con distribución y canales.

### Bucaramanga

Sede de apoyo para Santander y el nororiente del país.

## Productos

Líneas disponibles para el mercado colombiano en esta demostración:

- **Línea Agua.** Limpiadores e hidratantes pensados para clima cálido y templado.
- **Línea Sol.** Protectores solares de uso diario.
- **Línea Color.** Labiales y mejillas.

Estos textos viven en la base de datos compartida. Por eso las dos copias del sitio muestran lo mismo. Las fotografías de producto, si se cargaran por el escritorio, quedarían en un solo servidor; esta demostración no las usa.

## Contacto

- Medellín: sede principal y centro de datos.
- Bogotá: sede comercial.
- Bucaramanga: sede de apoyo.

Correo de la demostración: contacto@`el-dominio-real`.
