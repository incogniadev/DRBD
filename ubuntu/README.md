# Instalación automatizada de Ubuntu 24.04.2 con Preseed

Este proyecto contiene los archivos necesarios para realizar una instalación completamente automatizada de Ubuntu 24.04.2 LTS (Noble Numbat) utilizando archivos de configuración preseed.

## Autor

**Rodrigo Álvarez** (@incognia)  
Especialista en DevOps e Infraestructura  
Contacto: incognia@gmail.com

## Descripción

La instalación automatizada está configurada para desplegar un servidor Ubuntu 24.04.2 con configuración específica para el entorno de Faraday, incluyendo red estática, usuario administrativo preconfigurado y paquetes esenciales para administración de sistemas.

## Archivos incluidos

- `ubuntu-24.04.2-live-server-amd64.iso` - ISO de instalación original de Ubuntu 24.04.2
- `ubuntu-24.04.2-live-server-preseed.iso` - ISO personalizada booteable con preseed integrado (generada)
- `ubuntu-preseed.cfg` - Archivo de configuración preseed personalizado para Ubuntu
- `config-network.sh` - Script interactivo para reconfigurar IP y hostname post-instalación
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
- **Método:** LVM automático guiado con esquema "atomic" (estándar de Ubuntu)
- **Detección automática:** Utiliza el primer disco disponible automáticamente
- **Esquema:** Particionado guiado estándar de Ubuntu con LVM
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

## Diferencias con el preseed de Debian

### Cambios específicos para Ubuntu:
1. **Mirror de paquetes:** Se usa `archive.ubuntu.com` en lugar de `deb.debian.org`
2. **Configuración de arranque:** Adaptada para Ubuntu Live Server (usa `/casper/vmlinuz` y `/casper/initrd`)
3. **Parámetros de kernel:** Incluye `boot=casper automatic-ubiquity noprobe noescape` específicos de Ubuntu
4. **Estructura de la ISO:** Compatible con la estructura de Ubuntu Live Server

## Crear la ISO personalizada

### Proceso automático (recomendado)

El script `create-preseed-iso.sh` automatiza completamente el proceso:

```bash
# Hacer el script ejecutable (solo la primera vez)
chmod +x create-preseed-iso.sh

# Ejecutar el script
./create-preseed-iso.sh
```

### Descargar la ISO base

Si necesitas descargar la ISO original de Ubuntu 24.04.2:

```bash
# Usando rsync desde mirror rápido
rsync -avz --progress rsync://gsl-syd.mm.fcix.net/ubuntu-releases/.pool/ubuntu-24.04.2-live-server-amd64.iso .

# O usando wget desde el sitio oficial
wget https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso
```

## Uso de la ISO personalizada

### Arranque automático
1. **Instalación completamente automatizada:** No requiere intervención manual
2. **Arranque automático:** Se selecciona automáticamente "Automated Install (Preseed)" tras 5 segundos
3. **Soporte híbrido BIOS/UEFI:** Funciona en ambos modos de arranque
4. **Compatible:** USB, CD/DVD, Proxmox, VirtualBox, VMware

### Para Proxmox

#### Sistemas con UEFI:
```bash
# Configuración de la VM:
# - BIOS: OVMF (UEFI)
# - Machine: q35
# - EFI Storage: Configurar almacenamiento para EFI
```

#### Sistemas BIOS Legacy:
```bash
# Configuración de la VM:
# - BIOS: SeaBIOS
# - Machine: i440fx o q35
```

## Configuración post-instalación

### Script de configuración de red
Después del primer arranque, ejecutar:

```bash
sudo ./config-network.sh
```

**Funcionalidades:**
- 🌐 Notación CIDR moderna
- 🧠 Cálculo automático de máscara de subred
- 🎯 Inferencia automática de gateway
- 🔗 Configuración opcional de interfaz secundaria
- 💾 Respaldos automáticos antes de cambios
- 🔄 Aplicación inmediata de configuración

## Acceso al sistema

Después de la instalación:

### SSH con llave (recomendado)
```bash
ssh incognia@10.0.0.69
```

### SSH con contraseña
```bash
ssh incognia@10.0.0.69
# Usar la contraseña configurada en el preseed
```

## Personalización

### Cambiar la contraseña
```bash
mkpasswd -m sha-512
# Reemplazar el hash en la línea correspondiente del archivo ubuntu-preseed.cfg
```

### Modificar configuración de red
Editar las líneas correspondientes en `ubuntu-preseed.cfg`:

```bash
d-i netcfg/get_ipaddress string 10.0.0.69
d-i netcfg/get_netmask string 255.0.0.0  
d-i netcfg/get_gateway string 10.0.0.1
d-i netcfg/get_nameservers string 8.8.8.8 8.8.4.4
```

### Agregar paquetes adicionales
Modificar la línea de paquetes en `ubuntu-preseed.cfg`:

```bash
d-i pkgsel/include string openssh-server sudo build-essential curl wget git nano htop tree mc btop neofetch aptitude [nuevos-paquetes]
```

## Resolución de problemas

### La instalación no es completamente automática
- Verificar que seleccionas "Automated Install (Preseed)" en el menú
- Comprobar que el preseed está en la ISO: `sudo mount -o loop ubuntu-24.04.2-live-server-preseed.iso /mnt && ls /mnt/preseed.cfg`

### Problemas con Ubuntu Live Server
- Ubuntu Live Server tiene diferencias con el instalador tradicional de Debian
- Los parámetros de kernel incluyen `boot=casper` específico de Ubuntu
- La estructura de archivos usa `/casper/` en lugar de `/install.amd/`

### ISO no arranca en Proxmox
- Para UEFI: Configurar VM con OVMF y almacenamiento EFI
- Para BIOS: Configurar VM con SeaBIOS
- Verificar que la ISO tiene soporte híbrido: `file ubuntu-24.04.2-live-server-preseed.iso`

## Notas técnicas

### Diferencias con Debian:
1. **Ubuntu Live Server** usa un enfoque diferente al instalador tradicional de Debian
2. **Casper** es el sistema de arranque de Ubuntu Live
3. **Automatic-ubiquity** maneja la instalación automatizada en Ubuntu
4. **Preseed** sigue funcionando pero con parámetros específicos de Ubuntu

### Compatibilidad:
- ✅ Ubuntu 24.04.2 LTS (Noble Numbat)
- ✅ Proxmox VE (BIOS y UEFI)
- ✅ VirtualBox, VMware
- ✅ Hardware físico con BIOS/UEFI

## Licencia

Este proyecto está disponible bajo los términos que el autor considere apropiados para uso interno en Faraday.

---

**Última actualización:** 2025-08-01  
**Versión de Ubuntu:** 24.04.2 LTS (Noble Numbat)  
**Arquitectura:** AMD64
