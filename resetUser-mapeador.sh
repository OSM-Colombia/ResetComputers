#!/bin/bash

# Este script borra el usuario "mapeador" si existe, y lo crea después.
# Con este script se puede asegurar que el computador queda listo después
# de terminar un taller, y así el siguiente usuario lo va a encontrar
# todo como se ha diseñado.
#
# Autor: Andrés Gómez - AngocA
# Version: 2024-10-16
declare -r VERSION="2024-10-16"

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

declare -r AUTOSTART_DIR="/home/${MAPPER_USERNAME}/.config/autostart"
declare -r MAPPER_SCRIPT="/home/${MAPPER_USERNAME}/runOnce.sh"
declare -r TARGET_AUTOSTART_SCRIPT="/home/${MAPPER_USERNAME}/.config/autostart/runOnce.sh"

declare EXECUTION_TIME
EXECUTION_TIME=$(date +%Y%m%d%H%M%S)
declare -r TEMP_DIR="${SCRIPT_BASE_DIRECTORY}/temp"
declare LOG="${TEMP_DIR}/output-${EXECUTION_TIME}.log"

# FUNCIONES.

# Atrapa cualquier senal y muestra en que punto se genero.
function trapErrorOn() {
 trap '{ printf "\nERROR: The script did not finish correctly. Line number: ${LINENO}.\n" ; exit ;}' \
   ERR
}

# Muestra la ayuda de como ejecutar este programa.
function help() {
 cat <<EOT
Este script permite resetear el usuario "MAPPER_USERNAME" de manera que todo lo
que se haya hecho o configurado en ese usuario se borra.
Esto es muy práctico, ya que cuando acaba un taller los usuarios dejan cambios
o contraseñas en el sistema, y el script borra todo eso, y prepara de nuevo el
ambiente para su siguiente uso.

El script se debe ejecutar como root.

Autor: Andrés Gómez Casanova - AngocA
Version: ${VERSION}
EOT
}

# Chequea que el entorno de ejecución sea el correcto.
# Que se esté ejecutando con root.
function checkEnv() {
 if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: Debes ejecutar este script como root."
  exit "${EXIT_ERROR_NON_ROOT}"
 fi
}

# Mata todos los procesos que se estén ejecutando con el usuario.
function killUser() {
 MAPPER_ID=$(id -u "${MAPPER_USERNAME}")
 set +e
 pkill -u "${MAPPER_ID}"
 set -e
}

# Borra el usuario completamente, incluyendo home y cualquier otra
# configuración.
function deletesUser() {
 # Verfica si el usuario está definido.
 set +e
 QTY=$(grep -c "${MAPPER_USERNAME}" /etc/passwd)
 set -e
 if [[ "${QTY}" -ne 0 ]]; then
  # El usuario existe, por lo tanto lo borra.
  userdel -f "${MAPPER_USERNAME}"
 fi
 
 # Verifica si el home directory existe.
 if [[ -d "/home/${MAPPER_USERNAME}" ]]; then
  # El directorio existe, por lo tanto se borra.
  rm -Rf "/home/${MAPPER_USERNAME:?}"
 fi
}

# Crea el usuario y asigna las propiedades que se tengan.
function createsUser() {
 # Crea el usuario.
 useradd -m -c "Mapeador" -s /bin/bash "${MAPPER_USERNAME}"
 
 # Asigna una contraseña.
 echo "${MAPPER_USERNAME}:${MAPPER_PASSWORD}" | chpasswd

 # Copia la imagen del usuario.
 umask 033
 cp "images/Imagen-${MAPPER_USERNAME}-icon" \
   "/var/lib/AccountsService/icons/${MAPPER_USERNAME}"
 # Copia la configuración para usar la imagen.
 cp "conf/${MAPPER_USERNAME}" \
   "/var/lib/AccountsService/users/${MAPPER_USERNAME}"

 cp "images/Imagen-${MAPPER_USERNAME}-358.jpg" \
   "/home/${MAPPER_USERNAME}/.face"
}

# Crea un script para ser ejecutado por el usuario la primera vez que entra.
function createScript() {
 mkdir "/home/${MAPPER_USERNAME}/Imágenes"
 cp 'images/fondo.png' "/home/${MAPPER_USERNAME}/Imágenes"
 chown "${MAPPER_USERNAME}":"${MAPPER_USERNAME}" \
   "/home/${MAPPER_USERNAME}/Imágenes" \
   "/home/${MAPPER_USERNAME}/Imágenes/fondo.png"
 chmod 755 "/home/${MAPPER_USERNAME}/Imágenes"
 chmod 644 "/home/${MAPPER_USERNAME}/Imágenes/fondo.png"

 # Crea los directorios de autostart para poner un script ahi para que se
 # ejecute la primera vez que inicie sesion.
 mkdir -p "${AUTOSTART_DIR}"
 chown "${MAPPER_USERNAME}":"${MAPPER_USERNAME}" \
   "/home/${MAPPER_USERNAME}/.config/" "${AUTOSTART_DIR}"
 chmod 755 "/home/${MAPPER_USERNAME}/.config/" "${AUTOSTART_DIR}"

 # Crea un script bajo el usuario mapeador, para terminar de configurarlo
 # cuando inicie sesion.
 cat << EOF > "${MAPPER_SCRIPT}"
#!/bin/bash

# Script para ejecutar una vez que termina de configurar el usuario.
#
# Generado automáticamente.

echo "Iniciando script de configuration." > /home/${MAPPER_USERNAME}/output.txt

sleep 15
# Pone el fondo de pantalla.
PATH_TO_WALLPAPER="/home/${MAPPER_USERNAME}/Imágenes/fondo.png"
kwriteconfig5 \\
  --file \\
  "/home/${MAPPER_USERNAME}/.config/plasma-org.kde.plasma.desktop-appletsrc" \\
    --group 'Containments'                                                   \\
      --group '1'                                                            \\
        --group 'Wallpaper'                                                  \\
          --group 'org.kde.image'                                            \\
            --group 'General'                                                \\
              --key 'Image' "\${PATH_TO_WALLPAPER}"

kwriteconfig5 \\
  --file
  "/home/${MAPPER_USERNAME}/.config/plasma-org.kde.plasma.desktop-appletsrc" \\
    --group 'Containments'                                                   \\
      --group '1'                                                            \\
        --group 'Wallpaper'                                                  \\
          --group 'org.kde.image'                                            \\
            --group 'General'                                                \\
              --key 'FillMode' 6

kwriteconfig5 \\
  --file                                                                     \\
  "/home/${MAPPER_USERNAME}/.config/plasma-org.kde.plasma.desktop-appletsrc" \\
    --group 'Containments'                                                   \\
      --group '1'                                                            \\
        --group 'Wallpaper'                                                  \\
          --group 'org.kde.image'                                            \\
            --group 'General'                                                \\
              --key 'SlidePaths' '/usr/share/wallpapers/'

# Iniciar JOSM para que descargue Java y los plugins.
wget -P Descargas https://josm.openstreetmap.de/download/josm.jnlp
# Inicia JOSM.
javaws Descargas/josm.jnlp

# Se auto borra.
rm  "${TARGET_AUTOSTART_SCRIPT}"
EOF
 cp "conf/runOnce.sh.desktop" "${TARGET_AUTOSTART_SCRIPT}"
 chown "${MAPPER_USERNAME}":"${MAPPER_USERNAME}" "${MAPPER_SCRIPT}" \
   "${TARGET_AUTOSTART_SCRIPT}"
 chmod 755 "${MAPPER_SCRIPT}"
 chmod 600 "${TARGET_AUTOSTART_SCRIPT}"
}

# Instala el certificado de JOSM para que no pregunte.
function installCertif() {
 declare -l CERTIFDIR="/home/${MAPPER_USERNAME}/.config/icedtea-web/security/"
 umask 022
 mkdir -p "${CERTIFDIR}"
 cp certif/trusted.certs "${CERTIFDIR}"
 chown "${MAPPER_USERNAME}":"${MAPPER_USERNAME}" \
   "/home/${MAPPER_USERNAME}/.config/icedtea-web" "${CERTIFDIR}" \
   "${CERTIFDIR}"/trusted.certs

}

# MAIN.
mkdir -p "${SCRIPT_BASE_DIRECTORY}/temp"
echo "=====" >> "${LOG}" 2>&1
date +%Y%m%d-%H%M%S >> "${LOG}" 2>&1

# Activa la trampa que captura el error de ejecución.
trapErrorOn

declare TEMP
TEMP=$(getopt --options h --longoptions help --name "${APPL_NAME}" \
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
  * )
   echo "ERROR."
   break ;;
 esac
done
set -u

# Chequeos iniciales
echo "Chequeo del entorno..."
checkEnv >> "${LOG}" 2>&1

# Matar procesos del usuario.
echo "Matando procesos del usuario..."
killUser >> "${LOG}" 2>&1

# Borra todo rastro del usuario.
echo "Borrando usuario..."
deletesUser >> "${LOG}" 2>&1

# Crea el usuario incluyendo todas las propiedades.
echo "Creando usuario..."
createsUser >> "${LOG}" 2>&1

# Crea script para correr después del login.
echo "Haciendo ajustes en el nuevo usuario..."
createScript >> "${LOG}" 2>&1

# Instala el certificado de JOSM.
echo "Instalando certificado"
installCertif >> "${LOG}" 2>&1

echo "Usuario '${MAPPER_USERNAME}' reseteado"
echo "Usuario '${MAPPER_USERNAME}' reseteado" >> "${LOG}" 2>&1
date +%Y%m%d-%H%M%S >> "${LOG}" 2>&1
