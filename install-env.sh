#!/bin/bash

# Prepara el ambiente para que todo se pueda configurar.
#
# Autor: Andres Gomez - AngocA

# Instala OpenWebStart
wget $(wget -q -O - https://api.github.com/repos/karakun/OpenWebStart/releases/latest \
  | jq -r '.assets[] | select(.name | contains ("deb")) | .browser_download_url')
dpkg -i OpenWebStart_linux_*.deb

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

 # Descarga josm.jnlp
wget https://josm.openstreetmap.de/download/josm.jnlp

