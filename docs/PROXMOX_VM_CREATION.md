# Creación de VMs desde shell de Proxmox

Esta guía describe cómo crear las máquinas virtuales necesarias para el laboratorio DRBD directamente desde la línea de comandos de Proxmox.

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

### 📝 Nota sobre configuración post-instalación

**Importante**: Aunque la instalación de Debian es completamente desatendida (no solicita ningún parámetro), **la configuración de IP final y hostname debe realizarse manualmente** en cada VM después de que complete la instalación. Cada nodo arranca inicialmente con IP temporal `10.0.0.69` y hostname genérico.

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

### 5. Configurar red adicional para clúster (opcional)

Si necesitas una segunda interfaz de red para separar tráfico de administración del clúster:

```bash
# Nota: Las interfaces ya están configuradas en el comando de creación
# Si necesitas modificar las interfaces después de la creación:
qm set 231 --net1 virtio,bridge=vmbr2
qm set 232 --net1 virtio,bridge=vmbr2
qm set 233 --net1 virtio,bridge=vmbr2
```

### 6. Iniciar las VMs (Método escalonado recomendado)

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

### Configuración post-instalación (Manual requerida)

⚠️ **Importante**: Aunque la instalación de Debian es desatendida, **cada VM requiere configuración manual individual** para establecer su IP final y hostname.

Durante la instalación automatizada, el script `config-network.sh` se copia al directorio home del usuario `incognia` y debe ejecutarse manualmente en cada VM.

#### Proceso para cada VM:

```bash
# 1. Conectarse vía SSH a cada VM (todas inician con IP temporal)
ssh incognia@10.0.0.69

# 2. Ejecutar el script de reconfiguración (ya incluido durante la instalación)
sudo ./config-network.sh
```

#### 📝 Qué hace el script config-network.sh:
- 🔍 **Muestra configuración actual** (IP, hostname, FQDN)
- ⚙️ **Solicita interactivamente**:
  - Nueva IP con notación CIDR (ej: `192.168.10.231/24`)
  - Gateway (calcula sugerencia automáticamente)
  - Nuevo hostname (ej: `node1`)
  - Dominio (predeterminado: `faraday.org.mx`)
- 🔄 **Aplica cambios**:
  - Actualiza `/etc/hostname`, `/etc/hosts`, `/etc/network/interfaces`
  - Maneja conflictos con NetworkManager/systemd-networkd
  - Reinicia servicios de red automáticamente
  - Verifica conectividad
- 💾 **Crea respaldos** de configuraciones anteriores
- ⚙️ **Ofrece reinicio** del sistema para asegurar cambios

#### 🎯 IPs finales objetivo:
- **Node1**: `192.168.10.231/24` (hostname: `node1`)
- **Node2**: `192.168.10.232/24` (hostname: `node2`) 
- **Node3**: `192.168.10.233/24` (hostname: `node3-docker`)

🔄 **Repetir este proceso para cada una de las 3 VMs** antes de proceder con la configuración de DRBD.

📁 **Nota**: El script es inteligente y maneja múltiples métodos de aplicación de red, respaldos automáticos y validaciones de entrada.

**ℹ️ Para más detalles**: Ver [debian/README.md](../debian/README.md) para documentación completa.

---

## 🛠️ Instalación manual (Método tradicional)

### 1. Acceder a las VMs e instalar Debian manualmente

```bash
# Acceder a consola de VM para instalación manual
qm monitor 231
# Seguir proceso de instalación de Debian tradicional

# O usar VNC si está disponible
qm vncproxy 231
```

### 2. Configuración de red después de la instalación

En cada VM, configurar la red según el esquema de IPs:

#### Node1 (192.168.10.231)
```bash
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.10.231/24
      gateway4: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply
```

#### Node2 (192.168.10.232)
```bash
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.10.232/24
      gateway4: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply
```

#### Node3 (192.168.10.233)
```bash
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 192.168.10.233/24
      gateway4: 192.168.10.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply
```

### 3. Configurar hostnames y resolución

En cada VM:

```bash
# Node1
hostnamectl set-hostname node1
echo "127.0.1.1 node1" >> /etc/hosts

# Node2  
hostnamectl set-hostname node2
echo "127.0.1.1 node2" >> /etc/hosts

# Node3
hostnamectl set-hostname node3-docker
echo "127.0.1.1 node3-docker" >> /etc/hosts

# En todas las VMs, agregar resolución de nombres del clúster
cat >> /etc/hosts << EOF
192.168.10.231    node1
192.168.10.232    node2  
192.168.10.233    node3-docker
192.168.10.230    cluster-vip
EOF
```

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
echo "--- Solo para instalación simultánea (NO recomendado con preseed) ---"
echo "Para iniciar todas las VMs ahora (usar solo con instalación manual):"
echo "qm start 231 && qm start 232 && qm start 233"
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

# Ver configuración de una VM
qm config 101

# Detener una VM
qm stop 101

# Reiniciar una VM
qm reboot 101

# Eliminar una VM
qm destroy 101

# Crear snapshot
qm snapshot 101 pre-drbd-config

# Restaurar snapshot
qm rollback 101 pre-drbd-config

# Clonar VM
qm clone 101 201 --name node1-backup
```

### Monitoreo

```bash
# Ver uso de recursos
qm monitor 101

# Ver logs de una VM
qm log 101

# Acceso VNC
qm vncproxy 101
```

## Consideraciones importantes

1. **Snapshots**: Crear snapshots antes de configurar DRBD y Pacemaker
2. **Recursos**: Ajustar CPU y RAM según recursos disponibles en Proxmox
3. **Storage**: Verificar que el storage backend tenga espacio suficiente
4. **Red**: Asegurarse de que vmbr2 esté configurado correctamente
5. **ISO**: Verificar que la ISO de Debian esté disponible en el path especificado

## Próximos pasos

1. Instalar Debian en cada VM
2. Configurar SSH y acceso remoto
3. Seguir la [guía de instalación DRBD](INSTALLATION.md)
4. Implementar la configuración específica de [Proxmox con Debian](PROXMOX_DEBIAN.md)

---

**Autor**: Rodrigo Álvarez (@incogniadev)  
**Fecha**: 2025-07-21
