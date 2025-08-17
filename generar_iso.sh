#!/bin/bash
set -e

# 🚨 Validar ejecución como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root. Usa: sudo $0"
  exit 1
fi

# 📁 Rutas base en directorio compartido
DEBIAN_CUSTOM="/opt/debian-custom"
ISO_DIR="$DEBIAN_CUSTOM/iso"
EXTRACT_DIR="$DEBIAN_CUSTOM/extract"
CUSTOM_DIR="$DEBIAN_CUSTOM/custom"
PROJECT_DIR="$DEBIAN_CUSTOM/project"
BUILD_DIR="$DEBIAN_CUSTOM/build"
SCRIPTS_DIR="$DEBIAN_CUSTOM/scripts"
# Generar nombre único con timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_ISO="$BUILD_DIR/debian-13-resetcomputers_${TIMESTAMP}.iso"
PRESEED_FILE="$CUSTOM_DIR/preseed.cfg"

# 🏗️ Crear estructura de directorios si no existe
echo "🏗️ Creando estructura de directorios..."
mkdir -p "$ISO_DIR" "$EXTRACT_DIR" "$CUSTOM_DIR" "$PROJECT_DIR" "$BUILD_DIR" "$SCRIPTS_DIR"

# 🔐 Configurar permisos para que otros usuarios puedan leer
echo "🔐 Configurando permisos de directorios..."
chmod 755 "$DEBIAN_CUSTOM"
chmod 755 "$ISO_DIR" "$EXTRACT_DIR" "$CUSTOM_DIR" "$PROJECT_DIR" "$BUILD_DIR" "$SCRIPTS_DIR"

# 📁 Copiar script actual a scripts y archivos del proyecto a project
echo "📁 Copiando archivos del proyecto..."
cp -v "$0" "$SCRIPTS_DIR/"
cp -rv "$(dirname "$0")"/* "$PROJECT_DIR/" 2>/dev/null || echo "⚠ No se pudieron copiar todos los archivos del proyecto"

# 🔍 Buscar ISO de Debian en el directorio iso
ISO_ORIGINAL=""
for iso_file in "$ISO_DIR"/*.iso; do
  if [[ -f "$iso_file" ]]; then
    ISO_ORIGINAL="$iso_file"
    break
  fi
done

# 🔧 Variables dinámicas

# 🧪 Validaciones previas
if [[ -z "$ISO_ORIGINAL" ]]; then
  echo "❌ No se encontró ninguna ISO de Debian en: $ISO_DIR"
  echo "📥 Por favor, coloca una ISO de Debian en el directorio: $ISO_DIR"
  exit 1
fi
echo "✅ ISO encontrada: $(basename "$ISO_ORIGINAL")"

[[ -d "$PROJECT_DIR" ]] || { echo "❌ Directorio del proyecto no encontrado: $PROJECT_DIR"; exit 1; }
[[ -f "$PROJECT_DIR/install-env.sh" ]] || { echo "❌ Script install-env.sh no encontrado en: $PROJECT_DIR"; exit 1; }
[[ -x "$PROJECT_DIR/install-env.sh" ]] || chmod +x "$PROJECT_DIR/install-env.sh"

# 🧹 Limpieza previa
echo "🧹 Limpiando directorio de extracción..."
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# 📦 Extraer ISO original
echo "📦 Extrayendo ISO original..."
xorriso -osirrox on -indev "$ISO_ORIGINAL" -extract / "$EXTRACT_DIR"

# 🛠 Copiar proyecto al directorio de extracción
echo "🛠 Copiando proyecto al directorio de extracción..."
cp -rv "$PROJECT_DIR" "$EXTRACT_DIR/" || echo "⚠ Proyecto no encontrado, se omite"

# 🧾 Generar preseed.cfg completo
echo "🧾 Generando preseed.cfg con configuración automatizada..."
mkdir -p "$CUSTOM_DIR"

# 🔐 Generar contraseña encriptada para root y usuario
PASSWORD="OpenStreetMap2004"
ENCRYPTED_PASSWORD=$(openssl passwd -6 -salt salt "$PASSWORD")
echo "🔐 Contraseña generada: $PASSWORD (encriptada: $ENCRYPTED_PASSWORD)"

cat > "$PRESEED_FILE" <<EOF
### Configuración crítica para instalación automática
d-i debian-installer/priority string critical

### Localización
d-i debian-installer/locale string es_CO.UTF-8
d-i localechooser/language string es
d-i localechooser/country string CO
d-i localechooser/supported-locales multiselect es_CO.UTF-8

### Teclado
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string latam
d-i keyboard-configuration/modelcode string pc105
d-i keyboard-configuration/xkb-keymap select latam
d-i keyboard-configuration/optionscode string

### Usuario y contraseña
d-i passwd/root-password-crypted password $ENCRYPTED_PASSWORD
d-i passwd/user-fullname string Usuario
d-i passwd/username string usuario
d-i passwd/user-password-crypted password $ENCRYPTED_PASSWORD
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false
d-i passwd/user-uid string 1000
d-i passwd/user-gid string 1000
d-i user-setup/encrypt-home boolean false

### Red (sin conexión)
d-i netcfg/enable boolean false
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string debian
d-i netcfg/get_domain string local
d-i netcfg/wireless_wep string
d-i netcfg/wireless_essid string
d-i netcfg/wireless_wpa string

### Reloj
d-i clock-setup/utc boolean true
d-i time/zone string America/Bogota
d-i clock-setup/ntp boolean false
d-i clock-setup/ntp-server string

### Particionado automático (todo el disco para máquinas grandes)
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/init_automatically_partition select biggest_free
d-i partman-auto/select_disk select largest_free
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

### Debug: Logging del proceso de particionado
d-i preseed/early_command string echo "PARTITION DEBUG: Iniciando proceso de particionado..." >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PARTITION DEBUG: Método: regular, Receta: atomic" >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PARTITION DEBUG: Selección de disco: largest_free" >> /tmp/preseed_debug.log

### Repositorios (sin mirror)
d-i apt-setup/use_mirror boolean false
d-i mirror/country string manual
d-i mirror/http/hostname string
d-i mirror/http/directory string
d-i mirror/suite string stable
d-i apt-setup/security_host string security.debian.org
d-i apt-setup/security_path string /debian-security

### Paquetes
d-i pkgsel/include string openssh-server
d-i pkgsel/install-recommends boolean true
d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select full-upgrade

### Tareas
d-i tasksel/first multiselect standard, kde-desktop, ssh-server

### Finalización
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string \
    echo "LATE DEBUG: Proceso de particionado completado - $(date)" > /target/tmp/partition_complete.log && \
    echo "LATE DEBUG: Disco seleccionado:" >> /target/tmp/partition_complete.log && \
    lsblk >> /target/tmp/partition_complete.log 2>&1 && \
    echo "LATE DEBUG: Particiones creadas:" >> /target/tmp/partition_complete.log && \
    cat /target/proc/partitions >> /target/tmp/partition_complete.log 2>&1 && \
    cp -r /cdrom/project /target/opt/ResetComputers && \
    chmod +x /target/opt/ResetComputers/install-env.sh && \
    chroot /target /opt/ResetComputers/install-env.sh

### Opciones adicionales para evitar preguntas
d-i debian-installer/allow_unauthenticated boolean true
d-i user-setup/allow-password-weak boolean true
d-i passwd/user-uid string 1000
d-i passwd/user-gid string 1000

### Debug: Verificar que preseed se está aplicando
d-i preseed/early_command string echo "PRESEED DEBUG: Archivo preseed.cfg cargado correctamente - $(date)" > /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Usuario: usuario, Contraseña: $PASSWORD" >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Timestamp ISO: $TIMESTAMP" >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Buscando archivo preseed.cfg..." >> /tmp/preseed_debug.log
d-i preseed/early_command string find / -name "preseed.cfg" 2>/dev/null >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Contenido de /cdrom:" >> /tmp/preseed_debug.log
d-i preseed/early_command string ls -la /cdrom/ 2>/dev/null >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Contenido de /run/media:" >> /tmp/preseed_debug.log
d-i preseed/early_command string ls -la /run/media/ 2>/dev/null >> /tmp/preseed_debug.log
d-i preseed/early_command string echo "PRESEED DEBUG: Variables de entorno:" >> /tmp/preseed_debug.log
d-i preseed/early_command string env | grep -i preseed >> /tmp/preseed_debug.log

### Debug: Información detallada de discos
d-i preseed/early_command string echo "DISK DEBUG: Información de discos disponibles:" >> /tmp/preseed_debug.log
d-i preseed/early_command string fdisk -l >> /tmp/preseed_debug.log 2>&1
d-i preseed/early_command string echo "DISK DEBUG: Dispositivos de bloque:" >> /tmp/preseed_debug.log
d-i preseed/early_command string lsblk >> /tmp/preseed_debug.log 2>&1
d-i preseed/early_command string echo "DISK DEBUG: Tamaños de discos:" >> /tmp/preseed_debug.log
d-i preseed/early_command string lsblk -o NAME,SIZE,TYPE,MOUNTPOINT >> /tmp/preseed_debug.log 2>&1
d-i preseed/early_command string echo "DISK DEBUG: Información de particiones:" >> /tmp/preseed_debug.log
d-i preseed/early_command string cat /proc/partitions >> /tmp/preseed_debug.log 2>&1
EOF

# 📥 Copiar preseed.cfg a múltiples ubicaciones para compatibilidad con Ventoy
echo "📥 Copiando preseed.cfg a múltiples ubicaciones..."
cp -v "$PRESEED_FILE" "$EXTRACT_DIR/"
cp -v "$PRESEED_FILE" "$EXTRACT_DIR/preseed.cfg.bak"
cp -v "$PRESEED_FILE" "$EXTRACT_DIR/preseed.txt"

# 🔧 Solución para Ventoy: Crear script de inicialización que copie el preseed
echo "🔧 Creando script de inicialización para Ventoy..."
cat > "$EXTRACT_DIR/init-preseed.sh" << 'INIT_EOF'
#!/bin/bash
# Script de inicialización para Ventoy
echo "INIT: Script de inicialización para Ventoy ejecutándose..."
echo "INIT: Buscando archivo preseed.cfg..."

# Buscar en múltiples ubicaciones
PRESEED_FOUND=""
for location in "/cdrom" "/run/media" "/media" "/mnt" "/tmp"; do
    if [ -f "$location/preseed.cfg" ]; then
        echo "INIT: Preseed encontrado en $location"
        PRESEED_FOUND="$location/preseed.cfg"
        break
    fi
done

if [ -z "$PRESEED_FOUND" ]; then
    echo "INIT: Preseed no encontrado, creando desde variables de entorno..."
    # Crear preseed desde variables de entorno si es necesario
    echo "d-i debian-installer/priority string critical" > /tmp/preseed.cfg
    echo "d-i debian-installer/locale string es_CO.UTF-8" >> /tmp/preseed.cfg
    echo "d-i localechooser/language string es" >> /tmp/preseed.cfg
    echo "d-i localechooser/country string CO" >> /tmp/preseed.cfg
    echo "d-i console-setup/ask_detect boolean false" >> /tmp/preseed.cfg
    echo "d-i keyboard-configuration/layoutcode string latam" >> /tmp/preseed.cfg
    echo "d-i passwd/root-password-crypted password \$6\$salt\$hashedpassword" >> /tmp/preseed.cfg
    echo "d-i passwd/username string usuario" >> /tmp/preseed.cfg
    echo "d-i netcfg/enable boolean false" >> /tmp/preseed.cfg
    echo "d-i partman-auto/method string regular" >> /tmp/preseed.cfg
    echo "d-i partman-auto/choose_recipe select atomic" >> /tmp/preseed.cfg
    echo "d-i tasksel/first multiselect standard, kde-desktop, ssh-server" >> /tmp/preseed.cfg
    echo "d-i finish-install/reboot_in_progress note" >> /tmp/preseed.cfg
    echo "INIT: Preseed creado en /tmp/preseed.cfg"
fi

echo "INIT: Script de inicialización completado"
INIT_EOF

chmod +x "$EXTRACT_DIR/init-preseed.sh"

# Verificar que preseed.cfg se copió correctamente
if [[ -f "$EXTRACT_DIR/preseed.cfg" ]]; then
  echo "✅ preseed.cfg copiado correctamente a la raíz de la ISO"
  echo "📄 Contenido del preseed.cfg:"
  head -10 "$EXTRACT_DIR/preseed.cfg"
  echo "..."
  echo "📄 Últimas líneas del preseed.cfg:"
  tail -5 "$EXTRACT_DIR/preseed.cfg"
  echo ""
  echo "📁 Archivos preseed copiados:"
  ls -la "$EXTRACT_DIR"/preseed*
else
  echo "❌ Error: No se pudo copiar preseed.cfg"
  exit 1
fi

# 🧠 Modificar archivos de arranque para instalación automática
echo "🧠 Modificando archivos de arranque..."

# Modificar grub.cfg (modo UEFI)
GRUB_CFG="$EXTRACT_DIR/boot/grub/grub.cfg"
if [[ -f "$GRUB_CFG" ]]; then
  echo "🧠 Modificando grub.cfg para modo UEFI..."
  # Crear backup
  cp "$GRUB_CFG" "${GRUB_CFG}.backup"
  
  # Agregar nueva entrada al final del archivo
  cat >> "$GRUB_CFG" << 'GRUB_EOF'

menuentry "Automated Install with ResetComputers (KDE + SSH)" {
    set background_color=black
    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg initrd=/install.amd/initrd.gz quiet
    initrd /install.amd/initrd.gz
}
GRUB_EOF
  echo "✅ grub.cfg modificado correctamente"
else
  echo "⚠ grub.cfg no encontrado, omitiendo modificación UEFI"
fi

# Modificar txt.cfg (modo BIOS/legacy)
TXT_CFG="$EXTRACT_DIR/isolinux/txt.cfg"
if [[ -f "$TXT_CFG" ]]; then
  echo "🧠 Modificando txt.cfg para modo BIOS..."
  # Crear backup
  cp "$TXT_CFG" "${TXT_CFG}.backup"
  
  # Agregar nueva entrada al final del archivo
  cat >> "$TXT_CFG" << 'TXT_EOF'

label auto
  menu label ^Automated Install with ResetComputers (KDE + SSH)
  kernel /install.amd/vmlinuz
  append auto=true priority=critical preseed/file=/cdrom/preseed.cfg initrd=/install.amd/initrd.gz quiet
TXT_EOF
  echo "✅ txt.cfg modificado correctamente"
else
  echo "⚠ txt.cfg no encontrado, omitiendo modificación BIOS"
fi

# Verificar que las modificaciones se aplicaron
echo "🔍 Verificando modificaciones..."
if grep -q "Automated Install with ResetComputers" "$GRUB_CFG" 2>/dev/null; then
  echo "✅ Entrada UEFI agregada correctamente"
else
  echo "❌ Error: No se pudo agregar entrada UEFI"
fi

if grep -q "label auto" "$TXT_CFG" 2>/dev/null; then
  echo "✅ Entrada BIOS agregada correctamente"
else
  echo "❌ Error: No se pudo agregar entrada BIOS"
fi

# 🔐 Asegurar permisos en el directorio de extracción
echo "🔐 Ajustando permisos en el directorio de extracción..."
chmod -R u+w "$EXTRACT_DIR"

# 🔄 Generar md5sum.txt
echo "🔄 Generando md5sum.txt..."
cd "$EXTRACT_DIR"
find . -type f ! -name 'boot.cat' -exec md5sum {} + > ./md5sum.txt
cd -

# 📦 Preparar directorio de salida
echo "📦 Preparando directorio de salida..."
mkdir -p "$BUILD_DIR"
[[ -w "$BUILD_DIR" ]] || { echo "❌ No se puede escribir en $BUILD_DIR"; exit 1; }

# 🧹 Eliminar ISO anterior si existe
[ -f "$OUTPUT_ISO" ] && rm -f "$OUTPUT_ISO"

# 🧱 Generar nueva ISO personalizada
echo "🧱 Generando nueva ISO personalizada con genisoimage..."
genisoimage \
  -r -J -l \
  -V "Debian13Reset" \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -o "$OUTPUT_ISO" "$EXTRACT_DIR"

# 🔄 Convertir ISO a híbrida (BIOS + UEFI)
echo "🔄 Aplicando isohybrid para compatibilidad de arranque..."
if command -v isohybrid >/dev/null 2>&1; then
  isohybrid "$OUTPUT_ISO" || echo "⚠ Algunos BIOS antiguos podrían no arrancar esta ISO"
else
  echo "⚠ isohybrid no está disponible. La ISO puede no arrancar en modo BIOS."
fi

echo "✅ ISO personalizada generada en: $OUTPUT_ISO"
echo "🕐 Timestamp de generación: $TIMESTAMP"

# 🔐 Asegurar que la ISO sea legible por otros usuarios
chmod 644 "$OUTPUT_ISO"
echo "🔐 Permisos de la ISO configurados para lectura pública"

# 🔍 Verificación final de la ISO generada
echo "🔍 Verificación final de la ISO..."
if command -v xorriso >/dev/null 2>&1; then
  echo "📋 Contenido de la ISO generada:"
  xorriso -indev "$OUTPUT_ISO" -list 2>/dev/null | grep -E "(preseed\.cfg|grub\.cfg|txt\.cfg)" || echo "⚠ No se encontraron archivos críticos en la ISO"
else
  echo "⚠ xorriso no disponible para verificación"
fi

echo ""
echo "🔐 INFORMACIÓN IMPORTANTE:"
echo "   Usuario: usuario"
echo "   Contraseña: $PASSWORD"
echo "   Root password: $PASSWORD"
echo "   Timestamp ISO: $TIMESTAMP"
echo ""
echo "🔍 PARA VERIFICAR QUE PRESEED FUNCIONA:"
echo "   1. Durante la instalación, presiona Ctrl+Alt+F1"
echo "   2. Ejecuta: cat /tmp/preseed_debug.log"
echo "   3. Deberías ver los mensajes de debug del preseed"
echo ""
echo "💾 PARA VERIFICAR SELECCIÓN DE DISCO:"
echo "   1. Durante la instalación, presiona Ctrl+Alt+F1"
echo "   2. Ejecuta: cat /tmp/preseed_debug.log | grep 'DISK DEBUG'"
echo "   3. Ejecuta: cat /tmp/preseed_debug.log | grep 'PARTITION DEBUG'"
echo "   4. Después de la instalación, revisa: /tmp/partition_complete.log"
echo ""
echo "⚠️  NOTA IMPORTANTE PARA VENTOY:"
echo "   - El archivo preseed se copió en múltiples ubicaciones"
echo "   - Se creó un script de inicialización (init-preseed.sh) para Ventoy"
echo "   - Si no funciona, verifica el log de debug para ver dónde se monta la ISO"
echo "   - Ventoy puede montar en /run/media/ en lugar de /cdrom/"
echo "   - SOLUCIÓN ALTERNATIVA: Usar ISO real en lugar de Ventoy para mejor compatibilidad"
echo ""

echo "📁 Estructura de directorios creada en: $DEBIAN_CUSTOM"
echo "   ├── iso/      - Coloca aquí las ISOs de Debian originales"
echo "   ├── extract/  - Archivos extraídos de la ISO original"
echo "   ├── custom/   - Archivos de configuración personalizados"
echo "   ├── project/  - Archivos del proyecto ResetComputers"
echo "   ├── build/    - ISO personalizada generada"
echo "   └── scripts/  - Scripts de automatización"
echo ""
echo "🔄 Para generar otra ISO, simplemente ejecuta: $SCRIPTS_DIR/$(basename "$0")"

echo "Para escribir la ISO en una USB, usa el siguiente comando:"
echo "sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress && sync"


