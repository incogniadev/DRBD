#!/bin/bash

# Script mejorado para crear ISO personalizada booteable con preseed integrado
# Autor: Rodrigo Álvarez (@incognia)  
# Fecha: 2025-07-21
# Versión: 2.0 - Con soporte completo EFI/UEFI

set -e  # Salir si hay algún error

# Variables configurables
ORIGINAL_ISO="debian-12.11.0-amd64-netinst.iso"
PRESEED_FILE="debian-preseed.cfg"
NETWORK_SCRIPT="config-network.sh"
OUTPUT_ISO="debian-12.11.0-amd64-preseed.iso"
WORK_DIR="iso_custom"
MOUNT_DIR="iso_mount"

echo "=== Creador de ISO Booteable con Preseed (v2.0) ==="
echo "Original ISO: $ORIGINAL_ISO"
echo "Preseed file: $PRESEED_FILE" 
echo "Output ISO: $OUTPUT_ISO"
echo

# Verificar herramientas necesarias
echo "Verificando herramientas necesarias..."
if ! command -v genisoimage >/dev/null 2>&1; then
    echo "Error: genisoimage no está instalado"
    echo "Instalar con: sudo dnf install genisoimage (Fedora/RHEL/CentOS)"
    echo "o: sudo apt install genisoimage (Debian/Ubuntu)"
    exit 1
fi

# Verificar si isohybrid está disponible
ISOHYBRID_AVAILABLE=false
if command -v isohybrid >/dev/null 2>&1; then
    ISOHYBRID_AVAILABLE=true
    echo "✓ isohybrid disponible para crear imagen híbrida"
else
    echo "⚠ isohybrid no disponible, instalando syslinux-utils..."
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y syslinux-utils 2>/dev/null || true
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y syslinux-utils 2>/dev/null || true
    fi
    if command -v isohybrid >/dev/null 2>&1; then
        ISOHYBRID_AVAILABLE=true
        echo "✓ isohybrid instalado correctamente"
    else
        echo "⚠ No se pudo instalar isohybrid, la ISO podría no arrancar desde USB"
    fi
fi

# Verificar que existen los archivos necesarios
if [ ! -f "$ORIGINAL_ISO" ]; then
    echo "Error: No se encuentra la ISO original: $ORIGINAL_ISO"
    exit 1
fi

if [ ! -f "$PRESEED_FILE" ]; then
    echo "Error: No se encuentra el archivo preseed: $PRESEED_FILE"
    exit 1
fi

if [ ! -f "$NETWORK_SCRIPT" ]; then
    echo "Error: No se encuentra el script de red: $NETWORK_SCRIPT"
    exit 1
fi

# Limpiar directorios anteriores
echo "Limpiando directorios de trabajo..."
sudo umount "$MOUNT_DIR" 2>/dev/null || true
rm -rf "$WORK_DIR" "$MOUNT_DIR"

# Crear directorios
echo "Creando directorios de trabajo..."
mkdir -p "$WORK_DIR" "$MOUNT_DIR"

# Montar la ISO original
echo "Montando ISO original..."
sudo mount -o loop "$ORIGINAL_ISO" "$MOUNT_DIR/"

# Copiar contenido de la ISO
echo "Copiando contenido de la ISO..."
cp -r "$MOUNT_DIR"/* "$WORK_DIR"/
cp -r "$MOUNT_DIR"/.disk "$WORK_DIR"/ 2>/dev/null || true

# Desmontar la ISO original
echo "Desmontando ISO original..."
sudo umount "$MOUNT_DIR"

# Cambiar permisos para poder modificar
echo "Ajustando permisos..."
chmod -R +w "$WORK_DIR"/

# Copiar el archivo preseed y script de red
echo "Agregando archivo preseed..."
cp "$PRESEED_FILE" "$WORK_DIR/preseed.cfg"
echo "Agregando script de configuración de red..."
cp "$NETWORK_SCRIPT" "$WORK_DIR/config-network.sh"

# Modificar configuración de arranque para agregar opción automatizada
echo "Modificando configuración de arranque..."

# Crear nueva configuración con modo automatizado predeterminado
cat > "$WORK_DIR/isolinux/txt.cfg" << 'EOF'
default autoinstall
timeout 50

label autoinstall
	menu label ^Automated Install (Preseed) [DEFAULT]
	menu default
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/initrd.gz auto=true priority=critical preseed/file=/cdrom/preseed.cfg locale=es_MX console-setup/ask_detect=false keyboard-configuration/xkb-keymap=latam --- quiet

label install
	menu label ^Install
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/initrd.gz --- quiet 
EOF

# También agregar la opción al menú de GRUB para EFI
if [ -d "$WORK_DIR/boot/grub" ]; then
    echo "Modificando configuración de GRUB para EFI..."
    if [ -f "$WORK_DIR/boot/grub/grub.cfg" ]; then
        # Hacer una copia de seguridad de la configuración original
        cp "$WORK_DIR/boot/grub/grub.cfg" "$WORK_DIR/boot/grub/grub.cfg.bak"
        
        # Crear nueva configuración con timeout y entrada predeterminada
        cat > "$WORK_DIR/boot/grub/grub.cfg" << 'EOF'
if loadfont /boot/grub/font.pf2 ; then
  set gfxmode=auto
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
fi

set menu_color_normal=cyan/blue
set menu_color_highlight=white/blue
set timeout=5
set default=0

menuentry --hotkey=a 'Automated Install (Preseed)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 auto=true priority=critical preseed/file=/cdrom/preseed.cfg locale=es_MX console-setup/ask_detect=false keyboard-configuration/xkb-keymap=latam --- quiet 
    initrd   /install.amd/initrd.gz
}

EOF
        
        # Agregar el resto de entradas desde el archivo original
        grep -A 1000 "menuentry" "$WORK_DIR/boot/grub/grub.cfg.bak" | grep -v "Automated install" >> "$WORK_DIR/boot/grub/grub.cfg"
    fi
fi

# Actualizar checksums MD5
echo "Actualizando checksums..."
cd "$WORK_DIR"
find . -type f -not -name md5sum.txt -exec md5sum {} \; > md5sum.txt
cd ..

# Crear la nueva ISO con soporte mejorado
echo "Creando ISO personalizada con soporte híbrido..."

# Verificar si existe imagen EFI
EFI_SUPPORT=""
if [ -f "$WORK_DIR/boot/grub/efi.img" ]; then
    echo "✓ Detectado soporte EFI, creando ISO híbrida (BIOS + UEFI)"
    EFI_SUPPORT="-eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot"
else
    echo "⚠ No se detectó soporte EFI, creando ISO solo BIOS"
fi

# Crear ISO con parámetros mejorados
genisoimage -r -J -joliet-long \
    -l -cache-inodes \
    -iso-level 3 \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    $EFI_SUPPORT \
    -V "Debian 12.11.0 amd64 Preseed" \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR/"

# Hacer la ISO híbrida para arranque desde USB
if [ "$ISOHYBRID_AVAILABLE" = true ]; then
    echo "Creando imagen híbrida para USB..."
    if [ -f "$WORK_DIR/boot/grub/efi.img" ]; then
        isohybrid --uefi "$OUTPUT_ISO" 2>/dev/null || {
            echo "⚠ Fallo al crear imagen híbrida UEFI, intentando solo BIOS..."
            isohybrid "$OUTPUT_ISO" 2>/dev/null || echo "⚠ No se pudo crear imagen híbrida"
        }
    else
        isohybrid "$OUTPUT_ISO" 2>/dev/null || echo "⚠ No se pudo crear imagen híbrida"
    fi
    echo "✓ Imagen híbrida creada (booteable desde USB y CD)"
fi

# Limpiar directorios temporales
echo "Limpiando directorios temporales..."
rm -rf "$WORK_DIR" "$MOUNT_DIR"

echo
echo "✅ ISO personalizada booteable creada exitosamente: $OUTPUT_ISO"
echo "Tamaño: $(du -h "$OUTPUT_ISO" | cut -f1)"
echo

# Verificar la ISO creada
echo "Verificando ISO creada..."
ISO_TYPE=$(file "$OUTPUT_ISO")
echo "Tipo: $ISO_TYPE"

if echo "$ISO_TYPE" | grep -q "DOS/MBR boot sector"; then
    echo "✓ ISO con soporte de arranque MBR detectado"
else
    echo "⚠ Posible problema: No se detecta soporte MBR"
fi

echo
echo "Para usar la ISO:"
echo "1. Graba la ISO en un USB con herramientas como dd, Rufus, o Balena Etcher"
echo "   Ejemplo: sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
echo "2. O graba en CD/DVD"
echo "3. Configura Proxmox para usar la ISO"
echo "4. Arranca la VM y selecciona 'Automated Install (Preseed)'"
echo "5. La instalación se ejecutará automáticamente"
echo
echo "Configuración aplicada:"
echo "- IP: 10.0.0.69/8"
echo "- Gateway: 10.0.0.1" 
echo "- DNS: 8.8.8.8, 8.8.4.4"
echo "- Usuario: incognia"
echo "- Hostname: preseed.faraday.org.mx"
echo "- Idioma: Español mexicano"
echo "- Teclado: Latinoamericano"
echo "- Script de red: ./config-network.sh (incluido en el home del usuario)"
echo
echo "Notas para Proxmox:"
echo "- Asegúrate de que la VM esté configurada con UEFI si planeas usar arranque EFI"
echo "- Para arranque BIOS legacy, configura la VM en modo SeaBIOS"
echo "- La ISO debería ser reconocida correctamente en ambos modos"
