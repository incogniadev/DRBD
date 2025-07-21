# Guía de instalación de alta disponibilidad DRBD

## Requisitos previos

### Requisitos de hardware
- **Nodos DRBD**: Mínimo 2 nodos con almacenamiento local
- **Red dedicada**: Conexión de red de baja latencia entre nodos DRBD
- **Host Docker**: Servidor con Docker Engine instalado

### Requisitos de software
- **Sistema operativo**: Linux (Debian 11+, Ubuntu 20.04+, RHEL/CentOS 8+, SLES 15+)
- **DRBD**: Versión 9.x o superior
- **Pacemaker**: Versión 2.x o superior
- **Corosync**: Para comunicación del clúster
- **NFS Utils**: Para servicios NFS
- **Docker**: Versión 20.x o superior

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
