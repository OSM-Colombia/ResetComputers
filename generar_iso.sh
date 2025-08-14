#!/bin/bash
set -e

# 🚨 Validar ejecución como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root. Usa: sudo $0"
  exit 1
fi

# 📁 Rutas base relativas al script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
ISO_ORIGINAL="$ROOT/iso/debian-13.0.0-amd64-DVD-1.iso"
EXTRACT_DIR="$ROOT/extract"
CUSTOM_DIR="$ROOT/custom"
PROJECT_DIR="$ROOT/project/ResetComputers"
BUILD_DIR="$ROOT/build"
OUTPUT_ISO="$BUILD_DIR/debian-13-resetcomputers.iso"
PRESEED_FILE="$CUSTOM_DIR/preseed.cfg"

# 🔧 Variables dinámicas
HOSTNAME="ac3-$(date +%d)"

# 🧪 Validaciones previas
[[ -f "$ISO_ORIGINAL" ]] || { echo "❌ ISO original no encontrada: $ISO_ORIGINAL"; exit 1; }
[[ -d "$PROJECT_DIR" ]] || { echo "❌ Proyecto ResetComputers no encontrado: $PROJECT_DIR"; exit 1; }
[[ -f "$PROJECT_DIR/install-env.sh" ]] || { echo "❌ Script install-env.sh no encontrado en ResetComputers"; exit 1; }
[[ -x "$PROJECT_DIR/install-env.sh" ]] || chmod +x "$PROJECT_DIR/install-env.sh"

# 🧹 Limpieza previa
echo "🧹 Limpiando directorio de extracción..."
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# 📦 Extraer ISO original
echo "📦 Extrayendo ISO original..."
xorriso -osirrox on -indev "$ISO_ORIGINAL" -extract / "$EXTRACT_DIR"

# 🛠 Copiar proyecto ResetComputers
echo "🛠 Copiando proyecto ResetComputers..."
cp -rv "$PROJECT_DIR" "$EXTRACT_DIR/" || echo "⚠ ResetComputers no encontrado, se omite"

# 🧾 Generar preseed.cfg completo
echo "🧾 Generando preseed.cfg con configuración automatizada..."
mkdir -p "$CUSTOM_DIR"
cat > "$PRESEED_FILE" <<EOF
### Localización
d-i debian-installer/locale string es_CO.UTF-8
d-i localechooser/language-name string Spanish
d-i localechooser/language string es
d-i localechooser/country-name string Colombia
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
d-i netcfg/get_hostname string $HOSTNAME
d-i netcfg/get_domain string local

### Reloj
d-i clock-setup/utc boolean true
d-i time/zone string America/Bogota

### Particionado automático (todo en /)
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/expert_recipe string \
      atomic :: \
        10000 10000 100000000 ext4 \
        $primary{ } $bootable{ } method{ format } format{ } use_filesystem{ } filesystem{ ext4 } \
        mountpoint{ / } .

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
popularity-contest popularity-contest/participate boolean false

### Finalización
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string \
    cp -r /cdrom/ResetComputers /target/opt/ && \
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

