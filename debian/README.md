# Instalación automatizada de Debian 12 con Preseed

Este proyecto contiene los archivos necesarios para realizar una instalación completamente automatizada de Debian 12 (Bookworm) utilizando archivos de configuración preseed.

## Autor

**Rodrigo Álvarez** (@incognia)  
Especialista en DevOps e Infraestructura  
Contacto: incognia@gmail.com

## Descripción

La instalación automatizada está configurada para desplegar un servidor Debian 12 con configuración específica para el entorno de Faraday, incluyendo red estática, usuario administrativo preconfigurado y paquetes esenciales para administración de sistemas.

## Archivos incluidos

- `debian-12.11.0-amd64-netinst.iso` - ISO de instalación original de Debian 12.11
- `debian-12.11.0-amd64-preseed.iso` - ISO personalizada booteable con preseed integrado
- `debian-preseed.cfg` - Archivo de configuración preseed personalizado
- `config-network.sh` - Script interactivo para reconfigurar IP y hostname post-instalación
- `preseed-example.cfg` - Archivo de ejemplo oficial de Debian
- `create-preseed-iso.sh` - Script automatizado para generar ISO personalizada con soporte UEFI/BIOS híbrido

## Configuración del sistema

### Especificaciones de red
- **IP estática:** 10.0.0.69/8
- **Gateway:** 10.0.0.1
- **DNS:** 8.8.8.8, 8.8.4.4
- **Hostname:** preseed
- **Dominio:** faraday.org.mx
- **FQDN:** preseed.faraday.org.mx

### Configuración regional
- **Idioma del sistema:** Español mexicano (es_MX.UTF-8)
- **Teclado:** Latinoamericano
- **Zona horaria:** America/Mexico_City

### Usuario administrativo
- **Nombre completo:** Rodrigo Ernesto Álvarez Aguilera
- **Usuario:** incognia
- **Grupos:** audio, cdrom, video, sudo
- **Autenticación:** Contraseña cifrada + llave SSH Ed25519

### Particionado
- **Método:** LVM automático guiado con esquema "atomic" (estándar de Debian)
- **Detección automática:** Utiliza el primer disco disponible automáticamente
- **Esquema:** Particionado guiado estándar de Debian con LVM
- **Configuración automática:** El instalador decide el tamaño óptimo de particiones según el disco
- **Soporte multi-disco:** Maneja automáticamente VMs con múltiples discos
- **Limpieza automática:** Elimina configuraciones LVM y RAID previas

### Paquetes instalados
- openssh-server
- sudo
- build-essential
- curl
- wget
- git
- nano (editor predeterminado)
- htop
- tree
- mc (Midnight Commander)
- btop (monitor de sistema avanzado)
- neofetch (información del sistema)
- aptitude (gestor de paquetes avanzado)

## Métodos de instalación

### 1. Desde servidor web

```bash
# Subir el archivo preseed a un servidor web accesible
# Durante el boot, presionar Tab en el menú de instalación y agregar:
preseed/url=http://tu-servidor.com/debian-preseed.cfg
```

### 2. Desde USB/CD

```bash
# Copiar el archivo preseed al medio de instalación
# Durante el boot, presionar Tab y agregar:
preseed/file=/cdrom/debian-preseed.cfg
```

### 3. Via PXE (recomendado para laboratorio)

```bash
# Configurar en el servidor TFTP/PXE
# Agregar al archivo de configuración del kernel:
preseed/url=tftp://servidor-pxe/debian-preseed.cfg
```

### 4. ISO personalizada (recomendado)

La opción más sencilla es usar la ISO personalizada ya generada que incluye el preseed integrado:

```bash
# Usar directamente la ISO personalizada
debian-12.11.0-amd64-preseed.iso
```

**Ventajas de la ISO personalizada:**
- **Instalación completamente automatizada:** No requiere intervención manual
- **Arranque automático:** Se selecciona automáticamente "Automated Install (Preseed)" tras 5 segundos
- **Soporte híbrido BIOS/UEFI:** Funciona en ambos modos de arranque
- **Sin conexión a internet requerida:** El preseed está integrado en la ISO
- **Compatible:** USB, CD/DVD, Proxmox, VirtualBox, VMware

**Para regenerar la ISO personalizada:**

```bash
# Usar el script automatizado con soporte completo UEFI/BIOS
./create-preseed-iso.sh
```

### ¿Cómo funciona en la práctica?

**Proceso de instalación automática:**

1. **Arranque:** La VM inicia con la ISO `debian-12.11.0-amd64-preseed.iso`
2. **Menú automático:** Tras 5 segundos se selecciona "Automated Install (Preseed)" automáticamente
3. **Carga del preseed:** El instalador carga la configuración desde `/cdrom/preseed.cfg`
4. **Instalación desatendida:** 
   - Configura idioma y teclado latinoamericano automáticamente
   - Detecta el primer disco disponible (ej: `/dev/vda` o `/dev/sda`) 
   - Particiona con LVM sin preguntar
   - Configura red estática (IP: 10.0.0.69/8)
   - Crea usuario 'incognia' con sudo y SSH
   - Instala paquetes adicionales (mc, btop, neofetch, etc.)
5. **Finalización:** La VM se reinicia automáticamente con Debian 12 configurado

**Tiempo estimado:** Entre 10-15 minutos dependiendo del hardware

## Creación de ISO personalizada

### Proceso automático (recomendado)

El script `create-preseed-iso.sh` automatiza completamente el proceso de creación de la ISO personalizada:

```bash
# Hacer el script ejecutable (solo la primera vez)
chmod +x create-preseed-iso.sh

# Ejecutar el script
./create-preseed-iso.sh
```

El script realizará automáticamente:
1. Verificar que existan los archivos necesarios
2. Crear directorios de trabajo temporales
3. Montar la ISO original de Debian
4. Copiar todo el contenido a un directorio temporal
5. Agregar el archivo preseed personalizado
6. Modificar la configuración de arranque para incluir la opción automatizada
7. Actualizar checksums MD5
8. Crear la nueva ISO usando `genisoimage`
9. Limpiar archivos temporales

### Proceso manual

Si prefieres crear la ISO manualmente o entender el proceso:

```bash
# 1. Crear directorios de trabajo
mkdir -p iso_custom iso_mount

# 2. Montar la ISO original
sudo mount -o loop debian-12.11.0-amd64-netinst.iso iso_mount/

# 3. Copiar contenido
cp -r iso_mount/* iso_custom/
cp -r iso_mount/.disk iso_custom/ 2>/dev/null || true

# 4. Desmontar ISO original
sudo umount iso_mount/

# 5. Cambiar permisos
chmod -R +w iso_custom/

# 6. Agregar preseed
cp debian-preseed.cfg iso_custom/preseed.cfg

# 7. Modificar configuración de arranque
cat >> iso_custom/isolinux/txt.cfg << 'EOF'
label autoinstall
	menu label ^Automated Install (Preseed)
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/initrd.gz preseed/file=/cdrom/preseed.cfg locale=es_MX console-setup/ask_detect=false keyboard-configuration/xkb-keymap=latam --- quiet
EOF

# 8. Actualizar checksums
cd iso_custom
find . -type f -not -name md5sum.txt -exec md5sum {} \; > md5sum.txt
cd ..

# 9. Crear ISO personalizada
genisoimage -r -J \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -o debian-12.11.0-amd64-preseed.iso \
    iso_custom/

# 10. Limpiar directorios temporales
rm -rf iso_custom iso_mount
```

### Herramientas necesarias

Para crear la ISO personalizada necesitas:

**Herramientas principales:**
- **genisoimage** o **mkisofs**: Para crear archivos ISO
- **isohybrid**: Para crear imágenes híbridas BIOS/UEFI (incluido con syslinux-utils)
- **mount/umount**: Para montar ISOs (requiere sudo)

**Herramientas del sistema (generalmente ya instaladas):**
- **find, md5sum**: Para generar checksums
- **cp, chmod**: Herramientas básicas de archivos
- **bash**: Shell para ejecutar scripts

```bash
# En Fedora/CentOS/RHEL
sudo dnf install genisoimage

# En Debian/Ubuntu
sudo apt install genisoimage

# En openSUSE
sudo zypper install genisoimage
```

### Verificación de la ISO

Para verificar que la ISO personalizada fue creada correctamente:

```bash
# Verificar que el archivo existe y tiene el tamaño correcto
ls -lh debian-12.11.0-amd64-preseed.iso

# Verificar integridad (opcional)
md5sum debian-12.11.0-amd64-preseed.iso

# Montar para verificar contenido (opcional)
sudo mkdir -p /mnt/test-iso
sudo mount -o loop debian-12.11.0-amd64-preseed.iso /mnt/test-iso
ls /mnt/test-iso/preseed.cfg  # Debe existir
sudo umount /mnt/test-iso
```

## Configuración post-instalación automática

El sistema ejecutará automáticamente los siguientes comandos durante la instalación:

1. Habilitar servicio SSH
2. Configurar nano como editor predeterminado
3. Crear directorio `.ssh` para el usuario incognia
4. Instalar la llave pública SSH autorizada
5. Configurar permisos correctos para SSH
6. **Instalar script de reconfiguración de red** en `/home/incognia/config-network.sh`

### Script de configuración de red post-instalación

Despues del primer arranque, el sistema incluye un script interactivo para cambiar la configuración de red y hostname:

```bash
# Ejecutar con permisos de administrador
sudo ./config-network.sh
```

**Funcionalidades del script:**

- 🌐 **Notación CIDR:** Solicita IP en formato moderno (ej: 192.168.1.100/24)
- 🧠 **Cálculo automático:** Calcula máscara de subred desde el prefijo CIDR con formato correcto
- 🎯 **Inferencia de gateway:** Propone automáticamente el gateway de la red
- 📊 **Validación automática:** Verifica formato CIDR, IP y nombre de host
- 💾 **Respaldos automáticos:** Crea copias de seguridad antes de aplicar cambios
- 🔄 **Aplicación inmediata:** Configura /etc/network/interfaces, /etc/hosts y hostname
- 🛡️ **Manejo robusto de errores:** Gestiona fallos del servicio de red con métodos alternativos
- 🔧 **Configuración IP manual:** Aplica configuración directamente si los servicios fallan
- ⚙️ **Verificación de conectividad:** Prueba la conectividad después de aplicar cambios
- 🔄 **Reinicio opcional:** Pregunta si deseas reiniciar inmediatamente
- 🐛 **Corrección de formato:** Soluciona problemas de formato en máscaras de subred (/8, /16, /24)

**Ejemplo de uso:**

```bash
incognia@preseed:~$ sudo ./config-network.sh
⚠ ADVERTENCIA: Este script requiere permisos de administrador.
Ejecuta: sudo ./config-network.sh

============================================
  Configuración de Red - Debian Preseed    
============================================

Configuración actual:
IP actual: 10.0.0.69
Hostname actual: preseed
FQDN actual: preseed.faraday.org.mx

Nueva IP estática con prefijo CIDR (formato: 192.168.1.100/24): 192.168.1.50/24
Gateway (presiona Enter para usar 192.168.1.1): 
Nuevo hostname (ej: servidor01): debian-srv01
Dominio (presiona Enter para usar faraday.org.mx): 

Resumen de cambios:
Nueva IP: 192.168.1.50
Gateway: 192.168.1.1
Máscara: 255.255.255.0
Nuevo hostname: debian-srv01
Dominio: faraday.org.mx
FQDN: debian-srv01.faraday.org.mx

¿Aplicar estos cambios? (s/N): s
```

El script creará automáticamente un directorio de respaldo con timestamp y aplicará todas las configuraciones de forma segura.

## Acceso al sistema

Después de la instalación, puedes acceder al sistema de las siguientes maneras:

### SSH con llave (recomendado)
```bash
ssh incognia@10.0.0.69
```

### SSH con contraseña
```bash
ssh incognia@10.0.0.69
# Usar la contraseña configurada durante la generación del preseed
```

### Consola local
- Usuario: `incognia`
- Contraseña: [La configurada en el preseed]

## Personalización

### Cambiar la contraseña

Para generar una nueva contraseña cifrada:

```bash
mkpasswd -m sha-512
# Reemplazar el hash en la línea 57 del archivo preseed
```

### Modificar configuración de red

Editar las líneas 22-26 en `debian-preseed.cfg`:

```bash
d-i netcfg/get_ipaddress string 10.0.0.69
d-i netcfg/get_netmask string 255.0.0.0  
d-i netcfg/get_gateway string 10.0.0.1
d-i netcfg/get_nameservers string 8.8.8.8 8.8.4.4
```

### Agregar paquetes adicionales

Modificar la línea 96 en `debian-preseed.cfg`:

```bash
d-i pkgsel/include string openssh-server sudo build-essential curl wget git nano htop tree mc btop neofetch aptitude [nuevos-paquetes]
```

## Seguridad

⚠️ **Importantes consideraciones de seguridad:**

1. **Cambiar la contraseña:** El archivo preseed contiene una contraseña de ejemplo que debe ser cambiada
2. **Llave SSH:** La llave pública incluida es específica para el usuario incognia
3. **Red:** La configuración de red está optimizada para el entorno de Faraday
4. **Permisos:** El usuario incognia tiene acceso sudo completo


## Resolución de problemas

### La instalación no encuentra el preseed
- Verificar que el archivo sea accesible desde la red
- Comprobar la sintaxis del parámetro de kernel
- Revisar los logs en `/var/log/installer/syslog`

### Problemas de red estática
- Verificar conectividad física
- Confirmar que la configuración de red sea correcta para tu entorno
- Comprobar que el gateway esté accesible

### SSH no funciona después de la instalación
- Verificar que el servicio esté activo: `systemctl status ssh`
- Comprobar la configuración del firewall
- Revisar los logs: `journalctl -u ssh`

### Script config-network.sh muestra errores de red

**Error: "Job for networking.service failed"**
```bash
# Este error es normal cuando se cambia la IP activa
# El script maneja automáticamente esta situación con:
# - Métodos alternativos de configuración
# - Aplicación manual de configuración IP
# - Respaldos automáticos de la configuración anterior
```

**El script aplicó cambios pero no hay conectividad:**
```bash
# Verificar la configuración aplicada
sudo cat /etc/network/interfaces
sudo cat /etc/hosts

# Reiniciar manualmente la red
sudo systemctl restart networking
# O reiniciar el sistema completo
sudo reboot
```

**Error: "Máscara de red mal formateada (255..0.0.0)"**
```bash
# Este problema se solucionó en la versión actual del script
# Si experimentas este error con versiones anteriores:

# 1. Verificar la configuración generada
sudo cat /etc/network/interfaces | grep netmask

# 2. Si ves formato incorrecto (ej: "255..0.0.0"), ejecutar:
sudo ./config-network.sh
# El script corregido generará el formato correcto automáticamente

# 3. Verificar que la máscara esté bien formateada:
# /8  -> 255.0.0.0
# /16 -> 255.255.0.0  
# /24 -> 255.255.255.0
```

**Revertir cambios de configuración de red:**
```bash
# Los respaldos se guardan automáticamente en:
# /home/incognia/network-backup-YYYYMMDD-HHMMSS/

# Restaurar configuración previa
sudo cp /home/incognia/network-backup-*/interfaces /etc/network/
sudo cp /home/incognia/network-backup-*/hostname /etc/hostname
sudo cp /home/incognia/network-backup-*/hosts /etc/hosts
sudo reboot
```

### Problemas al crear la ISO personalizada

**Error: "No se encuentra genisoimage"**
```bash
# Instalar las herramientas necesarias
# Fedora/RHEL/CentOS
sudo dnf install genisoimage

# Debian/Ubuntu  
sudo apt install genisoimage
```

**Error: "Permission denied" al montar**
```bash
# Verificar que tienes permisos sudo
# El script necesita sudo para montar/desmontar ISOs
sudo -v
```

**Error: "No space left on device"**
```bash
# La creación de ISO requiere espacio temporal (~1.5GB)
# Verificar espacio disponible
df -h .
# Limpiar espacio si es necesario
```

**ISO creada pero no arranca**
```bash
# Verificar integridad de la ISO
md5sum debian-12.11.0-amd64-preseed.iso

# Recrear con el script
./create-preseed-iso.sh

# Verificar que el hardware soporte el tipo de medio (USB vs CD)
```

**Opción "Automated Install" no aparece en el menú**
```bash
# Verificar que txt.cfg fue modificado correctamente
sudo mount -o loop debian-12.11.0-amd64-preseed.iso /mnt/test
cat /mnt/test/isolinux/txt.cfg | grep -A3 autoinstall
sudo umount /mnt/test
```

**ISO no es reconocida como booteable por Proxmox/VirtualBox**
```bash
# Usar la ISO personalizada booteable
debian-12.11.0-amd64-preseed.iso

# O recrear con el script
./create-preseed-iso.sh

# Verificar que la ISO tenga soporte MBR/DOS
file debian-12.11.0-amd64-preseed.iso
# Debe mostrar: "DOS/MBR boot sector"

# Para Proxmox:
# - Configurar VM con BIOS SeaBIOS para arranque legacy
# - O configurar con UEFI para arranque moderno
# - Asegurar que el disco virtual sea configurado como IDE o SATA
```

## Soporte UEFI para Proxmox

**Última actualización:** Julio 2025

Se ha implementado soporte completo para arranque UEFI en Proxmox, resolviendo problemas de compatibilidad con entornos de virtualización modernos que requieren arranque EFI.

### Cambios implementados

El script `create-preseed-iso.sh` (versión 2.0) incluye las siguientes mejoras:

1. **Soporte híbrido BIOS/UEFI:** La ISO generada es compatible con ambos modos de arranque
2. **Configuración automática de GRUB:** Se agrega automáticamente la entrada de instalación automatizada al menú GRUB para sistemas EFI
3. **Detección inteligente:** El script detecta automáticamente si el sistema soporta EFI y configura la ISO adecuadamente
4. **Verificación mejorada:** Incluye validación de herramientas necesarias como `isohybrid` para crear imágenes híbridas

### Instrucciones específicas para Proxmox

#### Para sistemas con UEFI (recomendado)

1. **Crear la VM en Proxmox:**
   ```bash
   # En la configuración de la VM:
   # - BIOS: OVMF (UEFI)
   # - Machine: q35
   # - EFI Storage: Configurar almacenamiento para EFI
   ```

2. **Usar la ISO mejorada:**
   ```bash
   # Generar ISO con soporte EFI
   ./create-preseed-iso.sh
   ```

3. **Arrancar la VM:**
   - La ISO detectará automáticamente el modo UEFI
   - El menú GRUB mostrará la opción "Automated Install (Preseed)"
   - La instalación procederá automáticamente

#### Para sistemas BIOS Legacy

1. **Crear la VM en Proxmox:**
   ```bash
   # En la configuración de la VM:
   # - BIOS: SeaBIOS
   # - Machine: i440fx o q35
   ```

2. **La misma ISO funciona:**
   - La ISO híbrida es compatible con ambos modos
   - El menú de arranque ISOLINUX mostrará las opciones de instalación

### Verificación del soporte UEFI

Para verificar que la ISO tiene soporte completo:

```bash
# Verificar tipo de imagen
file debian-12.11.0-amd64-preseed.iso

# Debe mostrar tanto "DOS/MBR boot sector" como información EFI
# Verificar estructura EFI
sudo mount -o loop debian-12.11.0-amd64-preseed.iso /mnt/test
ls -la /mnt/test/boot/grub/  # Debe contener efi.img
sudo umount /mnt/test
```

### Resolución de problemas UEFI

**VM no arranca en modo UEFI:**
- Verificar que la configuración de la VM tenga OVMF (UEFI) seleccionado
- Asegurar que el almacenamiento EFI esté configurado en la VM
- Verificar que la ISO fue creada con el script `create-preseed-iso.sh`

**Menu GRUB no muestra opción automatizada:**
- La ISO fue creada correctamente si se ve la entrada "Automated Install (Preseed)"
- En algunos casos, puede ser necesario presionar ESC durante el arranque para acceder al menu GRUB

**Fallo al crear imagen híbrida:**
```bash
# Instalar herramientas necesarias
sudo dnf install syslinux-utils  # Fedora/RHEL/CentOS
sudo apt install syslinux-utils  # Debian/Ubuntu

# Recrear ISO
./create-preseed-iso.sh
```

**El preseed no se aplica y sigue preguntando configuraciones:**

Si la instalación sigue pidiendo configuraciones de red, contraseña root o particionado a pesar de usar el preseed:

1. **Verificar que usas la opción correcta:** Debes seleccionar "Automated Install (Preseed)" en el menú de arranque
2. **Verificar parámetros de arranque:** La línea de arranque debe incluir `auto=true priority=critical`
3. **Regenerar ISO con script corregido:**
   ```bash
   # Usar el script mejorado que incluye los parámetros necesarios
   ./create-preseed-iso.sh
   ```
4. **Verificar que el preseed está en la ISO:**
   ```bash
   sudo mount -o loop debian-12.11.0-amd64-preseed.iso /mnt/test
   ls -la /mnt/test/preseed.cfg  # Debe existir
   head -10 /mnt/test/preseed.cfg  # Debe mostrar las configuraciones
   sudo umount /mnt/test
   ```

## Características de la versión final (v2.0)

**Instalación completamente desatendida:**
- ✅ **Arranque automático:** Tras 5 segundos se selecciona automáticamente "Automated Install (Preseed)"
- ✅ **Sin intervención manual:** No requiere selección de opciones durante la instalación
- ✅ **Particionado automático:** LVM configurado automáticamente sin preguntas
- ✅ **Red estática:** IP 10.0.0.69/8 configurada automáticamente
- ✅ **Usuario preconfigurado:** Usuario 'incognia' con llave SSH y sudo
- ✅ **Paquetes adicionales:** mc, btop, neofetch, aptitude instalados automáticamente

**Soporte híbrido:**
- ✅ **BIOS Legacy:** Funciona con SeaBIOS en Proxmox
- ✅ **UEFI:** Funciona con OVMF en Proxmox
- ✅ **USB/CD:** Imagen híbrida compatible con ambos medios

**Cambios técnicos implementados:**
- Agregado `auto=true priority=critical` en parámetros de arranque BIOS y UEFI
- Configurado `d-i debconf/priority select critical` en el preseed
- Habilitado `d-i auto-install/enable boolean true`
- Deshabilitada cuenta root con `d-i passwd/root-login boolean false`
- Mejoradas configuraciones de red para evitar DHCP automático
- Configurado timeout de 5 segundos con opción predeterminada
- **Particionado LVM automático:** Detecta y usa automáticamente el primer disco disponible
- **Soporte multi-disco:** Maneja VMs con múltiples discos sin intervención manual
- **Comandos de particionado:** Selección automática del disco con `partman-auto/disk`

## Licencia

Este proyecto está disponible bajo los términos que el autor considere apropiados para uso interno en Faraday.

## Contribuciones

Para modificaciones o mejoras, contactar a:
- **Email:** incognia@gmail.com
- **GitHub:** @incognia
- **GitLab:** @incognia

---

**Última actualización:** 2025-07-22  
**Versión de Debian:** 12.11 (Bookworm)  
**Arquitectura:** AMD64
