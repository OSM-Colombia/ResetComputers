#!/bin/bash

# Este script borra el usuario "mapeador" si existe, y lo crea después.
# Con este script se puede asegurar que el computador queda listo después
# de terminar un taller, y así el siguiente usuario lo va a encontrar
# todo como se ha diseñado.
#
# Autor: Andrés Gómez - AngocA
# Version: 2024-09-30
declare -r VERSION="2024-09-30"

# Modificadores para hacer el script más robusto.
set -u
set -e
set -o pipefail

# Directorio del script.
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Nombre del script.
# shellcheck disable=SC2155
declare -r APPL_NAME=$(basename "${0}")

# Código de error cuando el script no se ejecuta como root.
declare -r EXIT_ERROR_NON_ROOT=254

declare -r MAPPER_USERNAME="mapeador"

declare -r MAPPER_PASSWORD="osm-2004"

function trapErrorOn() {
 trap '{ printf "\nERROR: The script did not finish correctly. Line number: ${LINENO}.\n" ; exit ;}' \
   ERR
}

function help() {
 cat <<EOT
Este script permite resetear el usuario "mapeador" de manera que todo lo que se
haya hecho o configurado en ese usuario se borra.
Esto es muy práctico, ya que cuando acaba un taller los usuarios dejan cambios
o contraseñas en el sistema, y el script borra todo eso, y prepara de nuevo el
ambiente para su siguiente uso.

El script se debe ejecutar como root.

Autor: Andrés Gómez Casanova - AngocA
Version: ${VERSION}
EOT
}

function checkEnv() {
 if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Debes ejecutar este script como root."
  exit "${EXIT_ERROR_NON_ROOT}"
 fi
}

# Borra el usuario completamente, incluyendo home y cualquier otra
# configuración.
function deletesUser() {
 # Verfica si el usuario está definido.
 set +e
 QTY=$(cat /etc/passwd | grep ${MAPPER_USERNAME} | wc -l)
 set -e
 if [[ "${QTY}" -ne 0 ]]; then
  # El usuario existe, por lo tanto lo borra.
  userdel -f ${MAPPER_USERNAME}
 fi
 
 # Verifica si el home directory existe.
 if [[ -d "/home/${MAPPER_USERNAME}" ]]; then
  # El directorio existe, por lo tanto se borra.
  rm -Rf "/home/${MAPPER_USERNAME}"
 fi
}

# Crea el usuario y asigna las propiedades que se tengan.
function createsUser() {
 # Crea el usuario.
 useradd -m -c "Mapeador" -s /bin/bash "${MAPPER_USERNAME}"
 
 # Copia la imagen del usuario.
 umask 033
 cp "images/Imagen-${MAPPER_USERNAME}-icon" \
   "/var/lib/AccountsService/icons/${MAPPER_USERNAME}"
 
 # Copia la configuración para usar la imagen.
 cp "conf/${MAPPER_USERNAME}" \
   "/var/lib/AccountsService/users/${MAPPER_USERNAME}"

 # Asigna una contraseña.
 echo "${MAPPER_USERNAME}:${MAPPER_PASSWORD}" | chpasswd
}

# Activa la trampa que captura el error de ejecución.
trapErrorOn

declare -r TEMP=$(getopt --options h --longoptions help --name "${APPL_NAME}" \
  -- "${@}")
eval set -- "${TEMP}"
set +u
while true ; do
 case "${1}" in
 -h | --help )
  help
  exit ;;
 -- )
  shift 1
  break ;;
 esac
done
set -u

# Chequeos iniciales
checkEnv

# Borra todo rastro del usuario.
deletesUser

# Crea el usuario incluyendo todas las propiedades.
createsUser

