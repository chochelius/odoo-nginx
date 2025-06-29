#!/bin/bash

# --- Configuración Interactiva ---
# Se ha modificado este script para que sea interactivo y utilice los archivos del proyecto actual
# en lugar de clonar un nuevo repositorio, para así preservar tus cambios (como la configuración de Nginx).

# Preguntar por el puerto para Nginx
read -p "Introduce el puerto para acceder a Odoo a través de Nginx (ej. 8080): " PORT
# Usar '80' como valor por defecto si no se introduce nada
PORT=${PORT:-80}

echo "--------------------------------------------------"
echo "Iniciando Odoo con la siguiente configuración:"
echo "  - Directorio del proyecto: $(pwd)"
echo "  - Puerto de acceso (Nginx):  $PORT"
echo "  - URL de acceso:             http://localhost:$PORT"
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
  sed -i '' -E 's/"[0-9]+:80"/"'$PORT':80"/g' $DESTINATION/docker-compose.yml
else
  # Linux sed syntax with extended regex (-r) to make it robust
  # Reemplaza cualquier número de puerto existente mapeado al puerto 80 del contenedor.
  sed -i -r 's/"[0-9]+:80"/"'$PORT':80"/g' $DESTINATION/docker-compose.yml
fi

# Set file and directory permissions after installation
find $DESTINATION -type f -exec chmod 644 {} \;
find $DESTINATION -type d -exec chmod 755 {} \;

chmod +x $DESTINATION/entrypoint.sh

# Run Odoo
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
  docker compose -f $DESTINATION/docker-compose.yml up -d
else
  docker-compose -f $DESTINATION/docker-compose.yml up -d
fi


echo "Odoo (via Nginx) started at http://localhost:$PORT | Master Password: minhng.info"