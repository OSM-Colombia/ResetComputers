#!/bin/bash
set -e

# 🚨 Validar ejecución como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root. Usa: sudo $0"
  exit 1
fi

# 📁 Rutas base en el home del usuario
HOME_DIR="$HOME"
DEBIAN_CUSTOM="$HOME_DIR/debian-custom"
ISO_DIR="$DEBIAN_CUSTOM/iso"
EXTRACT_DIR="$DEBIAN_CUSTOM/extract"
CUSTOM_DIR="$DEBIAN_CUSTOM/custom"
PROJECT_DIR="$DEBIAN_CUSTOM/project"
BUILD_DIR="$DEBIAN_CUSTOM/build"
SCRIPTS_DIR="$DEBIAN_CUSTOM/scripts"
OUTPUT_ISO="$BUILD_DIR/debian-13-resetcomputers.iso"
PRESEED_FILE="$CUSTOM_DIR/preseed.cfg"

# 🏗️ Crear estructura de directorios si no existe
echo "🏗️ Creando estructura de directorios..."
mkdir -p "$ISO_DIR" "$EXTRACT_DIR" "$CUSTOM_DIR" "$PROJECT_DIR" "$BUILD_DIR" "$SCRIPTS_DIR"

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
cat > "$PRESEED_FILE" <<EOF
### Localización
d-i debian-installer/locale string es_CO.UTF-8
d-i localechooser/language string es
d-i localechooser/country string CO

### Teclado
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string latam
d-i keyboard-configuration/modelcode string pc105
d-i keyboard-configuration/xkb-keymap select latam

### Red (sin conexión)
d-i netcfg/enable boolean false
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/choose_interface select auto

### Reloj
d-i clock-setup/utc boolean true
d-i time/zone string America/Bogota

### Particionado automático (todo en /)
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/init_automatically_partition select biggest_free
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

### Repositorios (sin mirror)
d-i apt-setup/use_mirror boolean false
d-i mirror/country string manual
d-i mirror/http/hostname string
d-i mirror/http/directory string
d-i mirror/suite string stable

### Paquetes
tasksel tasksel/first multiselect standard, kde-desktop, ssh-server
d-i pkgsel/include string openssh-server

### Finalización
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string \
    cp -r /cdrom/project /target/opt/ResetComputers && \
    chmod +x /target/opt/ResetComputers/install-env.sh && \
    chroot /target /opt/ResetComputers/install-env.sh
EOF

# 📥 Copiar preseed.cfg a la raíz de la ISO
cp -v "$PRESEED_FILE" "$EXTRACT_DIR/"

# 🧠 Modificar grub.cfg (modo UEFI)
GRUB_CFG="$EXTRACT_DIR/boot/grub/grub.cfg"
if [[ -f "$GRUB_CFG" ]] && ! grep -q "Automated Install with ResetComputers" "$GRUB_CFG"; then
  echo "🧠 Agregando entrada personalizada a grub.cfg..."
  sed -i '/menuentry .*Install/ a\
menuentry "Automated Install with ResetComputers (KDE + SSH)" {\n\
    set background_color=black\n\
    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg quiet\n\
    initrd /install.amd/initrd.gz\n\
}' "$GRUB_CFG"
fi

# 🧠 Modificar txt.cfg (modo BIOS/legacy)
TXT_CFG="$EXTRACT_DIR/isolinux/txt.cfg"
if [[ -f "$TXT_CFG" ]] && ! grep -q "label auto" "$TXT_CFG"; then
  echo "🧠 Agregando entrada personalizada a txt.cfg..."
  sed -i '/label install/ a\
label auto\n\
  menu label ^Automated Install with ResetComputers (KDE + SSH)\n\
  kernel /install.amd/vmlinuz\n\
  append auto=true priority=critical preseed/file=/cdrom/preseed.cfg initrd=/install.amd/initrd.gz quiet' "$TXT_CFG"
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

