# Creación de VMs desde shell de Proxmox

Esta guía describe cómo crear las máquinas virtuales necesarias para el laboratorio DRBD directamente desde la línea de comandos de Proxmox, con instalación automatizada mediante preseed.

## Requisitos previos

- **Acceso privilegiado**: SSH como `root` o usuario con permisos para gestionar VMs
- **ISO personalizada recomendada**: `debian/debian-12.11.0-amd64-preseed.iso` (instalación automatizada)
- **ISO alternativa**: Template o ISO estándar de Debian 12.11+ para instalación manual
- **Red bridge `vmbr2` configurada**: Bridge de red dedicado para el laboratorio
- **Espacio suficiente en almacenamiento**: Mínimo 200GB disponibles

### 🌐 Configuración de red (vmbr2)

**¿Por qué vmbr2 y no vmbr0?**
- `vmbr0` suele estar configurado para la red de administración de Proxmox
- `vmbr2` se usa como red dedicada para el laboratorio DRBD, aislando el tráfico del clúster
- Permite configurar una subred específica (`192.168.10.0/24`) sin conflictos

**Configuración requerida de vmbr2:**
```bash
# Ejemplo de configuración en /etc/network/interfaces
auto vmbr2
iface vmbr2 inet static
    address 192.168.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

### ⚠️ Importante: Instalación escalonada recomendada

**Aunque las VMs se pueden crear simultáneamente con scripts, se recomienda encarecidamente ejecutar las instalaciones de forma escalonada** para evitar colisiones de paquetes durante la instalación automatizada de Debian, ya que todas usan temporalmente la misma IP (10.0.0.69) durante el proceso de instalación.

## Especificaciones de las VMs

### Nodos DRBD (Node1 y Node2)
- **CPU**: 2 vCPUs
- **RAM**: 4GB 
- **Disco principal**: 24GB (sistema operativo)
- **Disco secundario**: 16GB (DRBD storage)
- **Red**: 2x vmbr2 (administración + clúster)
- **OS**: Debian 12.11+

### Host Docker (Node3)
- **CPU**: 2 vCPUs
- **RAM**: 4GB
- **Disco**: 32GB (sistema + contenedores)
- **Red**: 2x vmbr2 (administración + clúster)
- **OS**: Debian 12.11+

## Creación de VMs desde shell de Proxmox

### 1. Conectarse a Proxmox host

```bash
ssh root@<proxmox-host-ip>
```

### 2. Crear VM Node1 (DRBD Primario)

```bash
# Crear VM con ID 231
qm create 231 --name "node1-drbd" --memory 4096 --cores 2 --sockets 1 --cpu host --ostype l26 --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 local-lvm:24,format=raw --scsi1 local-lvm:16,format=raw --efidisk0 local-lvm:1,format=raw --net0 virtio,bridge=vmbr2 --net1 virtio,bridge=vmbr2 --agent 1 --bios ovmf --onboot 1

# Configurar orden de boot
qm set 231 --boot order=scsi0

# Adjuntar ISO de instalación (ajustar path según tu setup)
qm set 231 --cdrom local:iso/debian-12.11.0-amd64-preseed.iso
```

### 3. Crear VM Node2 (DRBD Secundario)

```bash
# Crear VM con ID 232
qm create 232 --name "node2-drbd" --memory 4096 --cores 2 --sockets 1 --cpu host --ostype l26 --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 local-lvm:24,format=raw --scsi1 local-lvm:16,format=raw --efidisk0 local-lvm:1,format=raw --net0 virtio,bridge=vmbr2 --net1 virtio,bridge=vmbr2 --agent 1 --bios ovmf --onboot 1

# Configurar orden de boot
qm set 232 --boot order=scsi0

# Adjuntar ISO de instalación
qm set 232 --cdrom local:iso/debian-12.11.0-amd64-preseed.iso
```

### 4. Crear VM Node3 (Docker Host)

```bash
# Crear VM con ID 233
qm create 233 --name "node3-docker" --memory 4096 --cores 2 --sockets 1 --cpu host --ostype l26 --machine q35 --scsihw virtio-scsi-pci --bootdisk scsi0 --scsi0 local-lvm:32,format=raw --efidisk0 local-lvm:1,format=raw --net0 virtio,bridge=vmbr2 --net1 virtio,bridge=vmbr2 --agent 1 --bios ovmf --onboot 1

# Configurar orden de boot
qm set 233 --boot order=scsi0

# Adjuntar ISO de instalación
qm set 233 --cdrom local:iso/debian-12.11.0-amd64-preseed.iso
```

### 5. Iniciar las VMs (Método escalonado recomendado)

⚠️ **Importante**: Para evitar colisiones de paquetes durante la instalación automatizada, inicia las VMs de forma escalonada:

```bash
# Método 1: Instalación escalonada (RECOMENDADO)
# Iniciar Node1 primero
qm start 231
echo "Esperando instalación de Node1... (aproximadamente 10 minutos)"
# Monitorear progreso: qm vncproxy 231

# Una vez que Node1 complete su instalación y se reinicie, iniciar Node2
# qm start 232  # Ejecutar cuando Node1 esté listo

# Finalmente, cuando Node2 complete, iniciar Node3
# qm start 233  # Ejecutar cuando Node2 esté listo

# Verificar estado de todas las VMs
qm list | grep -E "(231|232|233)"
```

```bash
# Método 2: Inicio simultáneo (solo si usas instalación manual)
# Solo usar este método si NO estás usando la ISO con preseed
qm start 231 && qm start 232 && qm start 233
qm list
```

## 🚀 Instalación automatizada con ISO personalizada (Recomendado)

### Uso de debian-12.11.0-amd64-preseed.iso

Si estás usando la ISO personalizada, la instalación será completamente automatizada:

```bash
# 1. Las VMs arrancarán automáticamente desde la ISO
# 2. Tras 5 segundos se seleccionará "Automated Install (Preseed)"
# 3. La instalación procederá sin intervención manual
# 4. Al finalizar, el sistema se reiniciará automáticamente

# Para monitorear el progreso (opcional):
qm vncproxy 231  # Ver la instalación en Node1
qm vncproxy 232  # Ver la instalación en Node2
qm vncproxy 233  # Ver la instalación en Node3
```

### Configuración post-instalación

⚠️ **Importante**: Aunque la instalación de Debian es desatendida, **cada VM requiere configuración manual individual** para establecer su IP final y hostname.

Durante la instalación automatizada, el script `config-network.sh` se copia al directorio home del usuario `incognia` y debe ejecutarse después de que la instalación se complete. Esta configuración posterior se aborda en detalle en la guía [02_DEBIAN.md](02_DEBIAN.md).

### 📝 Nota sobre configuración de red

Después del primer login con el usuario `incognia`, ejecutar:

```bash
sudo ./config-network.sh
```

Este script se encuentra disponible en el directorio home del usuario `incognia` tras completarse la instalación automatizada.

#### 🎯 IPs finales objetivo:
- **Node1**: `192.168.10.231/24` (hostname: `node1`)
- **Node2**: `192.168.10.232/24` (hostname: `node2`) 
- **Node3**: `192.168.10.233/24` (hostname: `node3-docker`)

## Script de automatización

### Crear todas las VMs con un script

```bash
#!/bin/bash
# create-drbd-vms.sh

# Variables
ISO_PATH="local:iso/debian-12.11.0-amd64-preseed.iso"
STORAGE="local-lvm"

echo "Creando VM Node1 (DRBD Primario)..."
qm create 231 \
  --name "node1-drbd" \
  --memory 4096 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --ostype l26 \
  --machine q35 \
  --scsihw virtio-scsi-pci \
  --bootdisk scsi0 \
  --scsi0 ${STORAGE}:24,format=raw \
  --scsi1 ${STORAGE}:16,format=raw \
  --efidisk0 ${STORAGE}:1,format=raw \
  --net0 virtio,bridge=vmbr2 \
  --net1 virtio,bridge=vmbr2 \
  --agent 1 \
  --bios ovmf \
  --onboot 1 \
  --cdrom ${ISO_PATH} \
  --boot order=scsi0

echo "Creando VM Node2 (DRBD Secundario)..."
qm create 232 \
  --name "node2-drbd" \
  --memory 4096 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --ostype l26 \
  --machine q35 \
  --scsihw virtio-scsi-pci \
  --bootdisk scsi0 \
  --scsi0 ${STORAGE}:24,format=raw \
  --scsi1 ${STORAGE}:16,format=raw \
  --efidisk0 ${STORAGE}:1,format=raw \
  --net0 virtio,bridge=vmbr2 \
  --net1 virtio,bridge=vmbr2 \
  --agent 1 \
  --bios ovmf \
  --onboot 1 \
  --cdrom ${ISO_PATH} \
  --boot order=scsi0

echo "Creando VM Node3 (Docker Host)..."
qm create 233 \
  --name "node3-docker" \
  --memory 4096 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --ostype l26 \
  --machine q35 \
  --scsihw virtio-scsi-pci \
  --bootdisk scsi0 \
  --scsi0 ${STORAGE}:32,format=raw \
  --efidisk0 ${STORAGE}:1,format=raw \
  --net0 virtio,bridge=vmbr2 \
  --net1 virtio,bridge=vmbr2 \
  --agent 1 \
  --bios ovmf \
  --onboot 1 \
  --cdrom ${ISO_PATH} \
  --boot order=scsi0

echo "⚠️  IMPORTANTE: Para evitar colisiones durante la instalación automatizada,"
echo "se recomienda iniciar las VMs de forma escalonada:"
echo ""
echo "1. Iniciar Node1 primero:"
echo "   qm start 231"
echo "   # Esperar ~10 minutos para que complete la instalación"
echo ""
echo "2. Cuando Node1 esté listo, iniciar Node2:"
echo "   qm start 232"
echo "   # Esperar ~10 minutos para que complete la instalación"
echo ""
echo "3. Finalmente, iniciar Node3:"
echo "   qm start 233"
echo ""
echo "Monitorear progreso con: qm vncproxy <vm-id>"
echo ""
echo "Estado actual de las VMs:"
qm list | grep -E "(231|232|233)"
echo ""
echo "✅ Configuración de VMs completada. Proceder con instalación escalonada."
```

## Comandos útiles de Proxmox

### Gestión de VMs

```bash
# Listar todas las VMs
qm list

# Ver configuración de una VM específica (ejemplos con nuestras VMs)
qm config 231  # Node1 DRBD
qm config 232  # Node2 DRBD
qm config 233  # Node3 Docker

# Detener una VM
qm stop 231    # Detener Node1
qm stop 232    # Detener Node2
qm stop 233    # Detener Node3

# Reiniciar una VM
qm reboot 231  # Reiniciar Node1
qm reboot 232  # Reiniciar Node2
qm reboot 233  # Reiniciar Node3

# Eliminar una VM (¡CUIDADO!)
qm destroy 231 # Eliminar Node1
qm destroy 232 # Eliminar Node2
qm destroy 233 # Eliminar Node3

# Crear snapshot antes de configurar DRBD
qm snapshot 231 pre-drbd-config
qm snapshot 232 pre-drbd-config
qm snapshot 233 pre-docker-config

# Restaurar snapshot si algo sale mal
qm rollback 231 pre-drbd-config
qm rollback 232 pre-drbd-config
qm rollback 233 pre-docker-config

# Clonar VM para respaldo
qm clone 231 234 --name node1-backup
qm clone 232 235 --name node2-backup
qm clone 233 236 --name node3-backup
```

### Monitoreo

```bash
# Ver uso de recursos de las VMs del laboratorio
qm monitor 231  # Monitorear Node1
qm monitor 232  # Monitorear Node2
qm monitor 233  # Monitorear Node3

# Ver logs de las VMs
qm log 231     # Logs de Node1
qm log 232     # Logs de Node2
qm log 233     # Logs de Node3

# Acceso VNC para instalación/troubleshooting
qm vncproxy 231  # VNC a Node1
qm vncproxy 232  # VNC a Node2
qm vncproxy 233  # VNC a Node3

# Verificar estado de todas las VMs del laboratorio
qm list | grep -E "(231|232|233)"

# Iniciar todas las VMs del laboratorio (método escalonado recomendado)
qm start 231 && sleep 600 && qm start 232 && sleep 600 && qm start 233

# Detener todas las VMs del laboratorio en orden
qm stop 233 && qm stop 232 && qm stop 231
```

## Consideraciones importantes

1. **Snapshots**: Crear snapshots antes de configurar DRBD y Pacemaker
2. **Recursos**: Ajustar CPU y RAM según recursos disponibles en Proxmox
3. **Storage**: Verificar que el storage backend tenga espacio suficiente
4. **Red**: Asegurarse de que vmbr2 esté configurado correctamente
5. **ISO**: Verificar que la ISO de Debian esté disponible en el path especificado

## Próximos pasos

1. Completar la instalación automatizada de Debian en cada VM
2. Ejecutar configuración de red post-instalación siguiendo [02_DEBIAN.md](02_DEBIAN.md)
3. Seguir la [guía de instalación DRBD](INSTALLATION.md)

---

**Autor**: Rodrigo Álvarez (@incogniadev)  
**Fecha**: 2025-07-23
