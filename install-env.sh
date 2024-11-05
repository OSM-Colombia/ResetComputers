#!/bin/bash

# Prepara el ambiente para que todo se pueda configurar.
# Se debe ejecutar con root.
#
# Autor: Andres Gomez - AngocA
# Version: 2024-11-04
declare -r VERSION="2024-11-04"

# Código de error cuando el script no se ejecuta como root.
declare -r EXIT_ERROR_NON_ROOT=254

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

# Personliza el usuari administrador
function customizeAdmin() {
 # Cambiar imagen de usuario.
 umask 033
 ADMIN_USERNAME=administrador
 cp "images/Imagen-${ADMIN_USERNAME}-icon" \
  "/var/lib/AccountsService/icons/${ADMIN_USERNAME}"
 # Copia la configuración para usar la imagen.
 cp "conf/${ADMIN_USERNAME}" \
  "/var/lib/AccountsService/users/${ADMIN_USERNAME}"

 cp "images/Imagen-${ADMIN_USERNAME}-358.jpg" \
  "/home/${ADMIN_USERNAME}/.face"
}

# Instala JOSM.
function installJosm() {
 # Instala OpenWebStart
 wget "$(wget -q -O - https://api.github.com/repos/karakun/OpenWebStart/releases/latest \
   | jq -r '.assets[] | select(.name | contains ("deb")) | .browser_download_url')"
 dpkg -i OpenWebStart_linux_*.deb

 # Descarga josm.jnlp
 wget https://josm.openstreetmap.de/download/josm.jnlp
}

# Instala otras herramientas posiblemente necesarias.
function installTools() {
 # Instala Mapillary
 cd ../../Descargas
 wget -U Mozilla https://tools.mapillary.com/uploader/download/linux
 mv linux Mapillary
 chmod +x Mapillary
 cd

 # Instala Gimp.
 apt install -y gimp
 apt install -y gimp-help-es
 apt install -y gimp-plugin-registry

 # Instala Inskcape.
 apt-get install -y inkscape

 # Instala QGIS.
 apt install -y qgis
}

# Instala OpenDroneMap.
function installODM() {
 apt install -y python3
 apt install -y python3-pip
 apt install -y docker
 apt install -y docker-compose

 cd

 set +e
 git clone https://github.com/OpenDroneMap/WebODM --config core.autocrlf=input --depth 1
 set -e
 cd WebODM || exit 1
 git pull
 nohup ./webodm.sh start &
}

# Configura el crontab.
function configureCrontab() {
 if [ "$(crontab -l | grep webodm | wc -l)" -eq 0 ]; then
  crontab -l | { cat; echo "@reboot cd /root/WebODM ; nohup ./webodm.sh start & "; } | crontab -
 fi
}

# MAIN.

# Activa la trampa que captura el error de ejecución.
trapErrorOn

# Chequea que se ejecute con root.
checkEnv

# Personaliza el usuario administrador.
customizeAdmin

# Instala JOSM.
installJosm

# Instala otras herramientas.
installTools

# Instala OpenDroneMap.
installODM

# Configura el crontab al inicio.
configureCrontab
