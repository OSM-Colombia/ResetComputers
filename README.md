# ResetComputers
Script para resetear el usuario mapeador de los computadores

## Preparación manual

Mientras instalar Debian, debes crear un usuario llamado ```administrador``` y las contraseñas deben ser las de la bóveda.

Una vez terminada la instalación de Debian, reinicias e inicias sesión con el usuario administrador. Abres una terminal como Konsole y descargas o clonas este repositorio en el home:

```bash
git clone https://github.com/OSM-Colombia/ResetComputers.git
cd ResetComputers
su -
```

## Instalación

Crea los usuarios, instala las aplicaciones y deja el ambiente para que un mapeador pueda usar la máquina para comenzar en OSM.

```bash
# Como root
install-env.sh
```

## Uso

Cuando se termina la sesión de trabajo (el taller, workshop) y se quiere dejar el computador como estaba antes, se ejecuta esto como root:

```bash
cd ResetComputers
sudo ./resetUser-mapeador.sh
```

## Preparación de imagen de Debian

Para usar este proyecto como último paso de una instalación de Debian, se puede preparar una imagen personalizada así:

```bash
mkdir ~/debian-custom/
cd ~/debian-custom/
mkdir build  custom  extract  iso  project  scripts
```

Copiar la ISO de Debian al directorio ```iso```.
En el directorio ```build``` quedará la imagen resultante.
En ```custom``` están los archivos para personalizar la imagen del ISO. Principalmente el archivo ```preseed.cfg``` que se genera con el script.
```extract``` es el directorio de trabajo, donde se extrae el ISO y se preparan los archivos.
Bajo ```project``` se encuentran los archivos de este proyecto.
Finalmente, ```scripts``` es el directorio que genera los archivos y la imagen. Aquí está el archivo ```generar_iso.sh``` que genera todo.
