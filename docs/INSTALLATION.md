# Guía de instalación de alta disponibilidad DRBD

## Esquema de configuración del laboratorio

### Configuración de nodos y red

> **📍 Referencia completa**: Para detalles completos de arquitectura y configuración de red, consulta [docs/ARCHITECTURE.md](ARCHITECTURE.md).

**⚠️ Nota importante:** Durante la instalación automatizada con preseed, todas las VMs usan temporalmente la IP `10.0.0.69/8` y deben ser reconfiguradas individualmente después de la instalación.

|| Nodo | Función | IP Final | Hostname |
||------|---------|----------|----------|
|| **Node 1** | DRBD Primario | `192.168.10.231/24` | `node1` |
|| **Node 2** | DRBD Secundario | `192.168.10.232/24` | `node2` |
|| **Node 3** | Host Docker | `192.168.10.233/24` | `node3-docker` |
|| **VIP** | IP Flotante | `192.168.10.230/24` | `cluster-vip` |
|| **Temporal** | Durante instalación | `10.0.0.69/8` | `preseed` |

### Requisitos del sistema

#### Hardware mínimo recomendado
| Componente | Node 1 & 2 (DRBD) | Node 3 (Docker) |
|------------|-------------------|------------------|
| **CPU** | 2 vCPUs | 2 vCPUs |
| **RAM** | 2GB (4GB recomendado) | 4GB mínimo |
| **Almacenamiento** | 24GB SO + 16GB DRBD | 32GB |
| **Red** | 2 interfaces (gestión + clúster) | 2 interfaces |

#### Software requerido
| Componente | Versión | Notas |
|------------|---------|-------|
| **Linux OS** | Debian 12.11+, Ubuntu 22.04+, RHEL/CentOS 9+ | - |
| **DRBD** | 9.x+ | Con módulos del kernel |
| **Pacemaker** | 2.x+ | Gestión de clúster |
| **Corosync** | Compatible con Pacemaker | Comunicación del clúster |
| **NFS** | v4+ | Cliente y servidor |
| **Docker** | 20.x+ | En Node 3 únicamente |

### ⚠️ Importante: Instalación escalonada recomendada

Durante el proceso de instalación automatizada de Debian con una ISO de preseed, **se recomienda encarecidamente que las instalaciones se realicen de manera escalonada**, comenzando con Node 1, seguido de Node 2 y finalmente Node 3. Esto es importante debido a que las instalaciones simultáneas pueden provocar colisiones de IPs temporales.

**📚 Guías específicas de plataforma:**
- **Proxmox**: Ver [PROXMOX_VM_CREATION.md](PROXMOX_VM_CREATION.md) para creación de VMs y procedimiento escalonado
- **Debian**: Ver [debian/README.md](../debian/README.md) para instalación automatizada con preseed

## Pasos generales de instalación

### 1. Preparación de nodos DRBD

```bash
# Actualizar sistema
apt update && apt upgrade -y

# Instalar paquetes requeridos
apt install -y drbd-utils pacemaker corosync nfs-kernel-server nfs-common

# Configurar el recurso DRBD
cat > /etc/drbd.d/docker-vol.res << EOF
resource docker-vol {
    protocol C;
    device /dev/drbd0;
    disk /dev/sdb1;
    meta-disk internal;
    
    on node1 {
        address 192.168.10.231:7789;
    }
    
    on node2 {
        address 192.168.10.232:7789;
    }
}
EOF

# Inicializar DRBD
drbdadm create-md docker-vol
systemctl enable drbd
systemctl start drbd

# Solo en el nodo primario
drbdadm primary docker-vol --force
mkfs.ext4 /dev/drbd0
```

### 2. Configuración del clúster Pacemaker

```bash
# Instalar pcs
apt install -y pcs

# Configurar contraseña para hacluster
passwd hacluster

# Autenticar nodos
pcs host auth node1 node2
pcs cluster setup docker-cluster node1 node2
pcs cluster start --all
pcs cluster enable --all

# Crear recursos
pcs resource create drbd_resource ocf:linbit:drbd \
    drbd_resource=docker-vol \
    op monitor interval=60s
    
pcs resource create drbd_fs Filesystem \
    device="/dev/drbd0" \
    directory="/mnt/docker-vol" \
    fstype="ext4"
    
pcs resource create nfs_server nfsserver \
    nfs_shared_infodir="/mnt/docker-vol/nfsinfo" \
    nfs_ip="192.168.10.230"
    
pcs resource create virtual_ip IPaddr2 \
    ip="192.168.10.230" \
    cidr_netmask="24"

# Configurar dependencias
pcs constraint colocation add drbd_fs with drbd_resource INFINITY with-rsc-role=Master
pcs constraint order drbd_resource then drbd_fs
pcs constraint colocation add nfs_server with virtual_ip INFINITY
pcs constraint order virtual_ip then nfs_server
```

### 3. Configuración del host Docker

```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# Configurar montaje NFS
mkdir -p /mnt/nfs-docker
echo "192.168.10.230:/mnt/docker-vol /mnt/nfs-docker nfs defaults,_netdev 0 0" >> /etc/fstab
mount -a

# Configurar el daemon de Docker
cat > /etc/docker/daemon.json << EOF
{
    "data-root": "/mnt/nfs-docker/docker",
    "storage-driver": "overlay2"
}
EOF

# Reiniciar Docker
systemctl restart docker
```

## Monitoreo y Mantenimiento

### Comandos útiles

```bash
# Estado del clúster DRBD
drbdadm status docker-vol

# Estado del clúster Pacemaker
pcs status

# Verificar montajes NFS
showmount -e 192.168.10.230

# Estado de Docker
docker info
docker system df
```

### Procedimientos de mantenimiento

```bash
# Modo de mantenimiento del clúster
pcs cluster standby node1

# Sincronización manual DRBD
drbdadm invalidate docker-vol

# Respaldo de configuración
pcs config backup cluster-backup.tar.bz2
```

## Resolución de problemas

### Problemas comunes

1. **División de cerebro en DRBD**: Verificar conectividad de red y resolver manualmente
2. **Falla de montaje NFS**: Verificar permisos y exportaciones NFS
3. **Recursos de Pacemaker atascados**: Limpiar recursos con `pcs resource cleanup`

### Logs importantes

```bash
# Logs de DRBD
journalctl -u drbd

# Logs de Pacemaker
journalctl -u pacemaker

# Logs de Docker
journalctl -u docker
```

---

*Para instrucciones de instalación específicas de la plataforma, consulte las guías dedicadas en el directorio de documentación.*
