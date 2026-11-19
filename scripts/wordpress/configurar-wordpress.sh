#!/bin/bash
# =============================================================================
#  WordPress + Apache, con la IPv4 privada visible en cada respuesta
#  Proyecto N2 - SI3002 Telemática
# =============================================================================
#
#  DÓNDE SE EJECUTA
#    WordPress-1 (ROL=primario)    10.0.2.10   privada 1   us-east-1a
#    WordPress-2 (ROL=secundario)  10.0.4.10   privada 2   us-east-1b
#
#  ORDEN
#    1. MariaDB ya configurada con configurar-mariadb.sh
#    2. Este script con ROL=primario en WordPress-1 (crea el sitio y las páginas)
#    3. Este script con ROL=secundario en WordPress-2 (mismo código, misma base,
#       no vuelve a instalar)
#
#  LA CLAVE DB_PASS TIENE QUE SER LA MISMA que en configurar-mariadb.sh.
#
#  LA IP PRIVADA
#    Un mu-plugin imprime en cada respuesta la IPv4 de ESTA EC2.
#    No hay plugin de caché. Apache manda Cache-Control: no-store.
#    HAProxy no usa afinidad de sesión. Con eso se puede hacer la prueba B1.
# =============================================================================

set -euo pipefail
trap 'echo "Falló en la línea $LINENO. Revisa la salida de arriba."' ERR

# ----- EDITAR ESTO -----------------------------------------------------------
ROL="primario"          # primario  -> WordPress-1 (instala el sitio)
                        # secundario -> WordPress-2 (se une a la misma base)
DOMINIO=""              # el mismo dominio real de BIND, sin www
DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASS="CambiarAntesDeEjecutar-XYZ2026"
DB_HOST="10.0.4.20"
WP_ADMIN_USER="adminxyz"
WP_ADMIN_PASS="CambiarAdmin-XYZ2026"
WP_ADMIN_EMAIL=""       # si lo dejas vacío, usa admin@DOMINIO
# Las dos máquinas tienen que usar LAS MISMAS salts. No las regeneres en una sola.
SALT_AUTH="xyz-lab-AUTH-KEY-si3002-n2-2026-no-usar-fuera-del-lab"
SALT_SECURE="xyz-lab-SECURE-AUTH-KEY-si3002-n2-2026"
SALT_LOGGED="xyz-lab-LOGGED-IN-KEY-si3002-n2-2026"
SALT_NONCE="xyz-lab-NONCE-KEY-si3002-n2-2026"
SALT_AUTH_S="xyz-lab-AUTH-SALT-si3002-n2-2026"
SALT_SECURE_S="xyz-lab-SECURE-AUTH-SALT-si3002-n2-2026"
SALT_LOGGED_S="xyz-lab-LOGGED-IN-SALT-si3002-n2-2026"
SALT_NONCE_S="xyz-lab-NONCE-SALT-si3002-n2-2026"
# -----------------------------------------------------------------------------

if [[ "$ROL" != "primario" && "$ROL" != "secundario" ]]; then
  echo "ROL tiene que ser 'primario' o 'secundario'."
  exit 1
fi
if [[ -z "$DOMINIO" ]]; then
  echo "Define DOMINIO (el mismo de BIND, sin www)."
  exit 1
fi
if [[ -z "$WP_ADMIN_EMAIL" ]]; then
  WP_ADMIN_EMAIL="admin@${DOMINIO}"
fi

echo ">> Comprobando salida a Internet por el NAT de esta AZ..."
if ! curl -4 -fsS --max-time 25 https://ifconfig.me >/dev/null; then
  echo "Esta privada no sale a Internet. Configura el NAT de su misma AZ antes de seguir."
  exit 1
fi

echo ">> Comprobando MariaDB en ${DB_HOST}:3306 ..."
apt-get update -y
export DEBIAN_FRONTEND=noninteractive
apt-get install -y apache2 php php-mysql php-xml php-mbstring php-curl php-zip php-gd php-intl unzip curl ca-certificates mariadb-client
if ! php -r "\$e=0; \$s=''; \$c=@fsockopen('${DB_HOST}', 3306, \$e, \$s, 5); exit(\$c ? 0 : 1);"; then
  echo "No hay TCP hacia ${DB_HOST}:3306."
  echo "Revisa que MariaDB esté arriba, bind-address 0.0.0.0, y el security group"
  echo "permita 3306 desde 10.0.2.10 y 10.0.4.10."
  exit 1
fi

echo ">> Instalando WP-CLI..."
curl -fsSL -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
install -m 755 /tmp/wp-cli.phar /usr/local/bin/wp
wp --info --allow-root >/dev/null

WEB="/var/www/html"
rm -f "$WEB/index.html"
mkdir -p "$WEB"
cd "$WEB"

if [[ ! -f "$WEB/wp-load.php" ]]; then
  echo ">> Descargando WordPress..."
  # Intenta en español; si el locale no está disponible en el mirror, baja en inglés.
  # El idioma se puede cambiar luego con: wp language core install es_ES --activate
  wp core download --allow-root --locale=es_ES \
    || wp core download --allow-root
fi

echo ">> Escribiendo wp-config.php (las salts son iguales en las dos EC2)..."
cat > "$WEB/wp-config.php" <<EOF
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASS}');
define('DB_HOST', '${DB_HOST}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY',         '${SALT_AUTH}');
define('SECURE_AUTH_KEY',  '${SALT_SECURE}');
define('LOGGED_IN_KEY',    '${SALT_LOGGED}');
define('NONCE_KEY',        '${SALT_NONCE}');
define('AUTH_SALT',        '${SALT_AUTH_S}');
define('SECURE_AUTH_SALT', '${SALT_SECURE_S}');
define('LOGGED_IN_SALT',   '${SALT_LOGGED_S}');
define('NONCE_SALT',       '${SALT_NONCE_S}');

\$table_prefix = 'wp_';
define('WP_CACHE', false);
define('DISABLE_WP_CRON', false);
define('WP_DEBUG', false);

# La URL sigue al Host de esta petición (IP del balanceador o www).
# Así un curl directo al HAProxy no redirige al otro balanceador vía DNS.
if (isset(\$_SERVER['HTTP_HOST']) && \$_SERVER['HTTP_HOST'] !== '') {
    define('WP_HOME', 'http://' . \$_SERVER['HTTP_HOST']);
    define('WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST']);
}

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
EOF

echo ">> Plugin que muestra la IPv4 privada y apaga la caché de página..."
mkdir -p "$WEB/wp-content/mu-plugins"
cat > "$WEB/wp-content/mu-plugins/mostrar-ip-privada.php" <<'PHP'
<?php
/**
 * Plugin Name: Mostrar IPv4 privada
 * Description: En cada respuesta HTML muestra la IPv4 privada de esta EC2 y evita caché.
 */

if (!function_exists('xyz_ipv4_privada')) {
    function xyz_ipv4_privada(): string
    {
        $ip = $_SERVER['SERVER_ADDR'] ?? '';
        if ($ip !== '' && $ip !== '127.0.0.1' && strpos($ip, ':') === false) {
            return $ip;
        }
        $salida = @shell_exec('hostname -I');
        if (is_string($salida)) {
            foreach (preg_split('/\s+/', trim($salida)) as $candidata) {
                if (filter_var($candidata, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                    return $candidata;
                }
            }
        }
        return $ip !== '' ? $ip : 'desconocida';
    }
}

add_action('send_headers', function () {
    if (headers_sent()) {
        return;
    }
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');
    header('Expires: 0');
    header('X-Servidor-Privado: ' . xyz_ipv4_privada());
});

add_filter('redirect_canonical', '__return_false');

function xyz_banner_ip(): void
{
    static $ya = false;
    if ($ya) {
        return;
    }
    $ya = true;
    $ip = esc_html(xyz_ipv4_privada());
    echo '<div id="xyz-ip-privada" style="position:sticky;top:0;z-index:99999;background:#111;color:#fff;text-align:center;padding:14px 16px;font:700 18px/1.4 ui-monospace,monospace;">'
        . 'Esta respuesta la atendió la instancia con IPv4 privada: ' . $ip
        . '</div>';
}

add_action('wp_body_open', 'xyz_banner_ip');
add_action('wp_footer', 'xyz_banner_ip');
PHP
chown -R www-data:www-data "$WEB"

echo ">> Apache sin caché en las respuestas..."
a2enmod rewrite headers
cat > /etc/apache2/conf-available/xyz-nocache.conf <<'EOF'
<IfModule mod_headers.c>
    Header always set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
    Header always set Pragma "no-cache"
</IfModule>
EOF
a2enconf xyz-nocache
cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:80>
    ServerName www.${DOMINIO}
    DocumentRoot ${WEB}
    <Directory ${WEB}>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# .htaccess de WordPress: necesario para los permalinks bonitos (/sedes/, /contacto/).
# wp rewrite flush no siempre lo crea (permisos), así que se escribe explícitamente.
cat > "$WEB/.htaccess" <<'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS
chown www-data:www-data "$WEB/.htaccess"

if [[ "$ROL" == "primario" ]]; then
  if ! wp core is-installed --allow-root >/dev/null 2>&1; then
    echo ">> Instalando el sitio (solo en el primario)..."
    wp core install \
      --allow-root \
      --url="http://www.${DOMINIO}" \
      --title="XYZ S.A." \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$WP_ADMIN_PASS" \
      --admin_email="$WP_ADMIN_EMAIL" \
      --skip-email
  else
    echo ">> WordPress ya estaba instalado. No se pisan las páginas."
  fi

  wp option update blogname "XYZ S.A." --allow-root
  wp option update blogdescription "Cosmética en Colombia" --allow-root
  wp rewrite structure '/%postname%/' --hard --allow-root || true

  crear_pagina() {
    local titulo="$1"
    local contenido="$2"
    local id
    id="$(wp db query --allow-root --skip-column-names \
      "SELECT ID FROM wp_posts WHERE post_title='${titulo}' AND post_type='page' AND post_status <> 'trash' LIMIT 1;" \
      | tr -d '[:space:]')"
    if [[ -n "$id" ]]; then
      wp post update "$id" --allow-root --post_content="$contenido" --post_status=publish >/dev/null
      echo "$id"
    else
      wp post create --allow-root --post_type=page --post_status=publish \
        --post_title="$titulo" --post_content="$contenido" --porcelain
    fi
  }

  INICIO="$(crear_pagina "Inicio" "<p>XYZ S.A. llega a Colombia. Esta página presenta la compañía, sus sedes y los productos disponibles en el mercado colombiano.</p><p>El recuadro negro de arriba identifica qué servidor de la nube atendió esta visita. Si recargas desde el balanceador, esa dirección puede cambiar: el sitio está repartido entre dos servidores.</p>")"
  crear_pagina "La empresa" "<p>XYZ S.A. es una compañía de cosméticos con presencia en América Latina. Para entrar a Colombia definió tres sedes y publicó este sitio con la información de la empresa y de sus productos.</p><p>El centro de datos principal de la operación colombiana está en Medellín. El sitio web que estás viendo corre en la nube, separado de las aplicaciones que siguen en ese centro de datos.</p>" >/dev/null
  crear_pagina "Sedes" "<h2>Medellín</h2><p>Sede principal y centro de datos. Aquí está la operación on-premise de la compañía. El sitio público, en cambio, está desplegado en AWS.</p><h2>Bogotá</h2><p>Sede comercial para la región Andina y punto de contacto con distribución y canales.</p><h2>Bucaramanga</h2><p>Sede de apoyo para Santander y el nororiente del país.</p>" >/dev/null
  crear_pagina "Productos" "<p>Líneas disponibles para el mercado colombiano:</p><ul><li><strong>Línea Agua</strong>: limpiadores e hidratantes para clima cálido y templado.</li><li><strong>Línea Sol</strong>: protectores solares de uso diario.</li><li><strong>Línea Color</strong>: labiales y mejillas.</li></ul><p>Los textos viven en la base de datos compartida. Las fotos que se suban por el escritorio quedan en el disco de un solo servidor; por eso este sitio de demostración usa texto y no depende de una imagen subida.</p>" >/dev/null
  crear_pagina "Contacto" "<p>Medellín: sede principal. Bogotá y Bucaramanga: sedes de atención.</p><p>Correo de contacto del sitio de demostración: contacto@${DOMINIO}</p>" >/dev/null

  wp option update show_on_front page --allow-root
  wp option update page_on_front "$INICIO" --allow-root

  # Dejar el sitio en español si el paquete de idioma está disponible (no es crítico).
  wp language core install es_ES --activate --allow-root 2>/dev/null \
    && wp site switch-language es_ES --allow-root 2>/dev/null || true
else
  echo ">> Rol secundario: no se vuelve a instalar WordPress."
  echo "   Esta EC2 usa la base ${DB_HOST} y el mismo código."
  if ! wp core is-installed --allow-root >/dev/null 2>&1; then
    echo "La base todavía no tiene WordPress. Ejecuta primero este script con ROL=primario en 10.0.2.10."
    exit 1
  fi
fi

chown -R www-data:www-data "$WEB"
systemctl enable apache2
systemctl restart apache2

IP_LOCAL="$(hostname -I | awk '{print $1}')"
echo ""
echo "============================================================"
echo " WORDPRESS LISTO (${ROL}) en ${IP_LOCAL}"
echo "============================================================"
echo " Prueba local (tiene que verse la IP ${IP_LOCAL} en el HTML):"
echo "   curl -s http://127.0.0.1/ | grep -o '10\\.0\\.[0-9.]*' | head"
echo " Usuario del escritorio: ${WP_ADMIN_USER}"
echo " Escritorio: http://www.${DOMINIO}/wp-admin/  (también vía la IP del HAProxy)"
echo "============================================================"
