#!/bin/bash

# Este script detiene y elimina los contenedores, redes y, opcionalmente,
# los volúmenes definidos en el archivo docker-compose.yml de este proyecto.

echo "--------------------------------------------------"
echo "Deteniendo los servicios de Odoo (db, odoo18, nginx)..."
echo "Esto detendrá y eliminará los contenedores."
echo "--------------------------------------------------"
read -p "Presiona [Enter] para continuar o Ctrl+C para cancelar."

# Usar el directorio actual como la ubicación del archivo docker-compose.yml
DESTINATION="."

# Verificar si se debe usar 'docker compose' (v2) o 'docker-compose' (v1)
# para mantener la consistencia con run.sh
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
  docker compose -f $DESTINATION/docker-compose.yml down
else
  docker-compose -f $DESTINATION/docker-compose.yml down
fi

echo "--------------------------------------------------"
echo "Todos los contenedores del proyecto han sido detenidos y eliminados."
echo "--------------------------------------------------"
