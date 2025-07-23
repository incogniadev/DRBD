# Scripts de automatización para laboratorio DRBD

Este directorio contiene scripts para automatizar la creación y configuración del laboratorio DRBD en Proxmox.

## Scripts disponibles

### `create-drbd-vms.sh`

Script principal para crear las tres máquinas virtuales del laboratorio DRBD en Proxmox.

#### Funcionalidades:
- 🚀 **Creación automatizada** de las 3 VMs con configuración optimizada
- 🛡️ **Verificación de VMs existentes** para evitar duplicados
- ⚙️ **Configuración personalizable** de storage e ISO
- 📊 **Logging detallado** con colores para facilitar seguimiento
- ⚠️ **Advertencias importantes** sobre instalación escalonada
- 📋 **Instrucciones post-creación** claras y detalladas

#### Especificaciones de VMs creadas:

| VM ID | Nombre | CPU | RAM | Disco 1 | Disco 2 | Función |
|-------|--------|-----|-----|---------|---------|---------|
| 231 | node1-drbd | 2 vCPUs | 4GB | 24GB | 16GB | DRBD Primario |
| 232 | node2-drbd | 2 vCPUs | 4GB | 24GB | 16GB | DRBD Secundario |
| 233 | node3-docker | 2 vCPUs | 4GB | 32GB | - | Host Docker |

#### Uso básico (recomendado):

```bash
# Ejecutar en host Proxmox sin parámetros
# Usa automáticamente la ISO de preseed para instalación completamente desatendida
./scripts/create-drbd-vms.sh
```

#### Uso avanzado:

```bash
# Con storage personalizado
./scripts/create-drbd-vms.sh --storage local-zfs

# Con ISO personalizada
./scripts/create-drbd-vms.sh --iso local:iso/debian-custom.iso

# Combinado
./scripts/create-drbd-vms.sh --storage local-zfs --iso local:iso/debian-custom.iso

# Ver ayuda
./scripts/create-drbd-vms.sh --help
```

#### Características técnicas:
- **Machine Type**: Q35 (moderno)
- **Boot**: UEFI con SecureBoot
- **Storage**: SCSI con virtio-scsi-pci
- **Red**: 2x interfaces en vmbr2
- **Agente**: QEMU guest agent habilitado
- **Auto-start**: Configurado para iniciar automáticamente

## Prerrequisitos

### En el host Proxmox:
1. **Acceso root** o usuario con permisos de gestión de VMs
2. **Bridge vmbr2** configurado y funcional
3. **Storage suficiente** en el backend configurado (default: local-lvm)
4. **ISO de Debian 12.11+** disponible en storage
   - Recomendada: `debian/debian-12.11.0-amd64-preseed.iso` (instalación automatizada)
   - Alternativa: ISO estándar de Debian para instalación manual

### Configuración de red requerida:
- **vmbr2**: Bridge para el tráfico del laboratorio
- **Conectividad**: Acceso a internet para descarga de paquetes durante instalación

## Flujo de trabajo recomendado

### 1. Crear las VMs:
```bash
./scripts/create-drbd-vms.sh
```

### 2. Instalación escalonada (⚠️ IMPORTANTE):
```bash
# Paso 1: Iniciar Node1
qm start 231
# Esperar ~10 minutos hasta que complete la instalación

# Paso 2: Iniciar Node2  
qm start 232
# Esperar ~10 minutos hasta que complete la instalación

# Paso 3: Iniciar Node3
qm start 233
```

### 3. Configuración post-instalación:
Para cada VM (conectarse vía SSH y reconfigurar red):

```bash
# Conectarse a cada VM (IP temporal durante instalación)
ssh incognia@10.0.0.69

# Ejecutar script de reconfiguración de red
sudo ./config-network.sh

# Configurar IPs finales:
# - Node1: 192.168.10.231/24 (hostname: node1)
# - Node2: 192.168.10.232/24 (hostname: node2)  
# - Node3: 192.168.10.233/24 (hostname: node3-docker)
```

## Monitoreo y troubleshooting

### Comandos útiles durante la creación:
```bash
# Ver estado de las VMs
qm list | grep -E "(231|232|233)"

# Monitorear instalación via VNC
qm vncproxy 231  # Node1
qm vncproxy 232  # Node2
qm vncproxy 233  # Node3

# Ver logs de una VM
qm log 231

# Verificar configuración de una VM
qm config 231
```

### Solución de problemas comunes:

1. **Storage no encontrado**: Verificar que el storage especificado existe y tiene espacio
2. **ISO no encontrada**: Verificar path de la ISO en el storage de Proxmox
3. **Bridge no existe**: Configurar vmbr2 en la configuración de red de Proxmox
4. **VM ya existe**: El script detecta y omite VMs existentes automáticamente

## Referencias

- 📖 **Documentación completa**: [docs/PROXMOX_VM_CREATION.md](../docs/PROXMOX_VM_CREATION.md)
- 🔧 **Configuración post-instalación**: [docs/PROXMOX_DEBIAN.md](../docs/PROXMOX_DEBIAN.md)
- 🏗️ **Instalación DRBD**: [docs/INSTALLATION.md](../docs/INSTALLATION.md)
- 🐧 **Instalación automatizada Debian**: [debian/README.md](../debian/README.md)

---

**Autor**: Rodrigo Álvarez (@incogniadev)  
**Fecha**: 2025-07-23
