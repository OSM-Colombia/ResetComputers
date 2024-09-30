#!/bin/bash

# Este script borra el usuario "mapeador" si existe, y lo crea después.
# Con este script se puede asegurar que el computador queda listo después
# de terminar un taller, y así el siguiente usuario lo va a encontrar
# todo como se ha diseñado.
#
# Autor: Andrés Gómez - AngocA
# Version: 2024-09-30

# Modificadores para hacer el script más robusto.
set -x
set -e
set -o pipefail
set -E

# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="${cd "$(dirname ${BASH_SOURCE[0]}")" &> /dev/null && pwd)

declare -r MAPPER_USERNAME=mapeador2

function trapErrorOn() {
 trap '{printf "\nERROR: The script did not finish correctly. Line number> ${LINENO}.\n" ; exit ;}' \
   ERR
}

# Borra el usuario completamente, incluyendo home y cualquier otra
# configuración.
function deletesUser() {
 # Verfica si el usuario está definido.
 QTY=$(grep ${MAPPER_USERNAME} /etc/passwd | wc -l)
 if [[ "${QTY}" -ne 0 ]]; then
  # El usuario existe, por lo tanto lo borra.
  userdel -r -Z ${MAPPER_USERNAME}
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
 useradd -m "${MAPPER_USERNAME}"
 
 # Copia la imagen del usuario.
 umask 002
 mkdir -p "/var/lib/AccountsService/icons/${MAPPER_USERNAME}"
 cp "images/Imagen-${MAPPER_USERNAME} "/var/lib/AccountsService/icons/${MAPPER_USERNAME}"
 
 # Copia la configuración para usar la imagen.
 umask 077
 mkdir -p "/var/lib/AccountsService/icons/${MAPPER_USERNAME}"
}

# Activa la trampa que captura el error de ejecución.
trapErrorOn

# Borra todo rastro del usuario.
deletesUser

# Crea el usuario incluyendo todas las propiedades.
createsUser

