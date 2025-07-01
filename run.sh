#!/bin/bash
set -e

# --- Configuración Interactiva ---
# Se ha modificado este script para que sea interactivo y utilice los archivos del proyecto actual
# en lugar de clonar un nuevo repositorio, para así preservar tus cambios (como la configuración de Nginx).

# Función para comprobar si un comando existe
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Comprobar si Docker y Docker Compose están instalados
if ! command_exists docker || (! command_exists docker-compose && ! docker compose version >/dev/null 2>&1); then
  echo "Error: Docker y/o Docker Compose no están instalados o no se encuentran en el PATH."
  echo "Por favor, instálalos antes de ejecutar este script."
  exit 1
fi


# Preguntar por el puerto para Nginx
read -p "Introduce el puerto para acceder a Odoo a través de Nginx (ej. 8080): " PORT
# Usar '80' como valor por defecto si no se introduce nada
PORT=${PORT:-80}

# Preguntar si se quiere configurar SSL
read -p "¿Quieres configurar SSL con Let's Encrypt? (s/n): " SETUP_SSL

if [[ "$SETUP_SSL" =~ ^[Ss]$ ]]; then
  # Preguntar por el dominio
  read -p "Introduce tu dominio (ej. odoo.example.com): " DOMAIN
  if [ -z "$DOMAIN" ]; then
    echo "Error: El dominio no puede estar vacío."
    exit 1
  fi
fi

echo "--------------------------------------------------"
echo "Iniciando Odoo con la siguiente configuración:"
echo "  - Directorio del proyecto: $(pwd)"
echo "  - Puerto de acceso (Nginx):  $PORT"
if [[ "$SETUP_SSL" =~ ^[Ss]$ ]]; then
  echo "  - Dominio (SSL):             $DOMAIN"
  echo "  - URL de acceso:             https://$DOMAIN"
else
  echo "  - URL de acceso:             http://localhost:$PORT"
fi
echo "--------------------------------------------------"
read -p "Presiona [Enter] para continuar o Ctrl+C para cancelar."

# Usar el directorio actual como destino
DESTINATION="."

# Se omite la clonación del repositorio para usar los archivos existentes.
# git clone --depth=1 https://github.com/minhng92/odoo-18-docker-compose $DESTINATION
# rm -rf $DESTINATION/.git

# Crear el directorio de PostgreSQL si no existe
mkdir -p $DESTINATION/postgresql

# Cambiar propietario y permisos. ¡CUIDADO! Esto afecta al directorio actual.
sudo chown -R $USER:$USER $DESTINATION
sudo chmod -R 700 $DESTINATION  # Solo el usuario tiene acceso

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Running on macOS. Skipping inotify configuration."
else
  # System configuration
  if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf)
  else
    echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
  fi
  sudo sysctl -p
fi

# Set Nginx port in docker-compose.yml
# Update docker-compose configuration for Nginx port
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS sed syntax with extended regex (-E) to make it robust
  # Reemplaza cualquier número de puerto existente mapeado al puerto 80 del contenedor.
  sed -i '' -E 's/"[0-9]+:80"/"'$PORT':80"/' $DESTINATION/docker-compose.yml
else
  # Linux sed syntax with extended regex (-r) to make it robust
  # Reemplaza cualquier número de puerto existente mapeado al puerto 80 del contenedor.
  sed -i -r 's/"[0-9]+:80"/"'$PORT':80"/' $DESTINATION/docker-compose.yml
fi

# Configuración de SSL si se ha solicitado
if [[ "$SETUP_SSL" =~ ^[Ss]$ ]]; then
  # Comprobar si Certbot está instalado
  if ! command_exists certbot; then
    echo "Certbot no está instalado. Por favor, instálalo para continuar."
    echo "Puedes encontrar instrucciones en: https://certbot.eff.org/"
    exit 1
  fi

  # Generar certificados
  echo "Generando certificados SSL para $DOMAIN..."
  sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m chochelius@gmail.com

  # Crear directorio para los certificados si no existe
  mkdir -p $DESTINATION/nginx/certs

  # Copiar certificados
  sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $DESTINATION/nginx/certs/
  sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $DESTINATION/nginx/certs/
  sudo chown -R $USER:$USER $DESTINATION/nginx/certs

  # Actualizar la configuración de Nginx para usar SSL
  # (Este es un ejemplo básico, puede que necesites ajustarlo)
  cat > $DESTINATION/nginx/odoo.conf <<EOL
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    # Resto de la configuración de Nginx...
    location / {
        proxy_pass http://odoo:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

  # Actualizar docker-compose.yml para mapear el puerto 443
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E 's/"[0-9]+:80"/"443:443"/' $DESTINATION/docker-compose.yml
  else
    sed -i -r 's/"[0-9]+:80"/"443:443"/' $DESTINATION/docker-compose.yml
  fi
fi


# Set file and directory permissions after installation
find $DESTINATION -type f -exec chmod 644 {} \;
find $DESTINATION -type d -exec chmod 755 {} \;

chmod +x $DESTINATION/entrypoint.sh
chmod +x $DESTINATION/run.sh
chmod +x $DESTINATION/stop.sh


# Run Odoo
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
  docker compose -f $DESTINATION/docker-compose.yml up -d
else
  docker-compose -f $DESTINATION/docker-compose.yml up -d
fi


if [[ "$SETUP_SSL" =~ ^[Ss]$ ]]; then
  echo "Odoo (via Nginx) started at https://$DOMAIN | Master Password: minhng.info"
else
  echo "Odoo (via Nginx) started at http://localhost:$PORT | Master Password: minhng.info"
fi