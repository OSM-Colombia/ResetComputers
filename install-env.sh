#!/bin/bash

# Prepara el ambiente para que todo se pueda configurar.
#
# Autor: Andres Gomez - AngocA

# Instala librerias.
apt-get install curl

# Instala OpenWebStart
curl -s https://api.github.com/repos/karakun/OpenWebStart/releases/latest \
| grep "browser_download_url.*deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -
dpkg -i OpenWebStart_linux_*.deb

# Descarga josm.jnlp

# Cambiar imagen de usuario.
