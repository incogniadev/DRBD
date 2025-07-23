# Creación de VMs desde shell de Proxmox

Esta guía describe cómo crear las máquinas virtuales necesarias para el laboratorio DRBD directamente desde la línea de comandos de Proxmox.

## Requisitos previos

- Acceso SSH a Proxmox host
- **ISO personalizada recomendada**: `debian/debian-12.11.0-amd64-preseed.iso` (instalación automatizada)
- **ISO alternativa**: Template o ISO estándar de Debian 12.11+ para instalación manual
- Red bridge `vmbr2` configurada
- Espacio suficiente en almacenamiento

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

### 6. Iniciar las VMs

```bash
# Iniciar todas las VMs
qm start 231
qm start 232
qm start 233

# Verificar estado
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

### Configuración post-instalación automatizada

Después de la instalación automatizada:

```bash
# 1. Conectarse vía SSH (la instalación configura IP 10.0.0.69 por defecto)
ssh incognia@10.0.0.69

# 2. Reconfigurar red para cada nodo usando el script incluido
sudo ./config-network.sh

# 3. Configurar IPs finales:
# - Node1: 192.168.10.231/24
# - Node2: 192.168.10.232/24
# - Node3: 192.168.10.233/24
```

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

echo "Iniciando todas las VMs..."
qm start 231
qm start 232
qm start 233

echo "Estado de las VMs:"
qm list | grep -E "(231|232|233)"

echo "Configuración completada. Proceder con instalación de Debian en cada VM."
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
