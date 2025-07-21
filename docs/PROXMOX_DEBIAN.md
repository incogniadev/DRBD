# Implementación en Proxmox con Debian

Esta guía cubre la implementación específica del laboratorio DRBD en un entorno Proxmox utilizando máquinas virtuales con Debian.

## Configuración de máquinas virtuales en Proxmox

### Imagen ISO requerida
- **Sistema operativo**: Debian 12.11 net install
- **Fuente de descarga**: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
- **Archivo ISO**: `debian-12.11.0-amd64-netinst.iso`

### Especificaciones recomendadas para VMs

#### Nodos DRBD (Node1 y Node2)
- **CPU**: 2 vCPUs mínimo
- **RAM**: 2GB mínimo (4GB recomendado)
- **Disco principal**: 20GB para el sistema operativo
- **Disco secundario**: 10GB adicional para DRBD (será `/dev/sdb`)
- **Red**: Conectar a la misma red virtual (ej: vmbr0)
- **OS**: Debian 12.11 net install

#### Host Docker (Node3)
- **CPU**: 2 vCPUs mínimo  
- **RAM**: 4GB mínimo
- **Disco**: 30GB para sistema y contenedores
- **Red**: Misma red que los nodos DRBD

### Configuración de red en Proxmox

```bash
# Configuración de red dual para cada VM:
# Docker Host (Node3): 
#   - eth0: 10.0.0.233/8    (red de administración)
#   - eth1: 192.168.10.233/24 (red del clúster)
# 
# DRBD Node1:
#   - eth0: 10.0.0.231/8    (red de administración) 
#   - eth1: 192.168.10.231/24 (red del clúster)
#
# DRBD Node2:
#   - eth0: 10.0.0.232/8    (red de administración)
#   - eth1: 192.168.10.232/24 (red del clúster)
#
# Floating IP: 192.168.10.230/24 (IP virtual para alta disponibilidad)
```

## Instalación específica para Debian en Proxmox

### 1. Preparación inicial del sistema

```bash
# Actualizar el sistema
apt update && apt upgrade -y

# Instalar utilidades básicas
apt install -y wget curl vim nano net-tools htop

# Configurar hostname (ejecutar en cada nodo)
# En Node1:
hostnamectl set-hostname node1
echo "127.0.1.1 node1" >> /etc/hosts

# En Node2:
hostnamectl set-hostname node2  
echo "127.0.1.1 node2" >> /etc/hosts

# En Node3:
hostnamectl set-hostname node3-docker
echo "127.0.1.1 node3-docker" >> /etc/hosts

# En todos los nodos, agregar resolución de nombres
cat >> /etc/hosts << EOF
192.168.10.231    node1
192.168.10.232    node2  
192.168.10.233    node3-docker
192.168.10.230    cluster-vip
EOF
```

### 2. Configuración específica de red para Node3 Docker

```bash
# Configuración de red dual para el host Docker (Node3)
# Crear archivo de configuración Netplan
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.0.0.233/8
      gateway4: 10.0.0.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: default
          via: 10.0.0.1
    eth1:
      addresses:
        - 192.168.10.233/24
EOF

# Aplicar configuración
netplan apply

# Verificar conectividad
ping -c 3 192.168.10.230  # IP flotante
ping -c 3 10.0.0.1       # Gateway

# Verificar interfaces
ip addr show
ip route show
```

### 3. Instalación de DRBD en Debian

```bash
# DRBD puede requerir el módulo del kernel
# Verificar si el módulo está disponible
modprobe drbd

# Si no está disponible, instalar headers del kernel
apt install -y linux-headers-$(uname -r)

# Instalar DRBD desde repositorios oficiales
apt install -y drbd-utils drbd-dkms

# Verificar instalación
lsmod | grep drbd
drbdadm --version
```

### 4. Configuración de Pacemaker en Debian

```bash
# Instalar pacemaker y herramientas
apt install -y pacemaker corosync pcs crmsh

# Habilitar servicios
systemctl enable pacemaker
systemctl enable corosync
systemctl enable pcsd

# Configurar usuario hacluster
passwd hacluster
# Usar la misma contraseña en ambos nodos

# Iniciar servicio pcsd
systemctl start pcsd
```

### 5. Configuración de firewall

```bash
# Si ufw está habilitado, configurar reglas para el clúster
ufw allow 7789/tcp  # DRBD
ufw allow 2224/tcp  # pcsd
ufw allow 3121/tcp  # pacemaker
ufw allow 5405/tcp  # corosync
ufw allow 21064/tcp # corosync
ufw allow 9929/tcp  # corosync

# Para NFS
ufw allow 2049/tcp  # NFS
ufw allow 111/tcp   # portmapper
ufw allow 20048/tcp # mountd
```

## Optimizaciones para entorno virtualizado

### 1. Configuración de discos virtuales

```bash
# Verificar que el segundo disco esté disponible
lsblk

# Debería mostrar algo como:
# sda     8:0    0   20G  0 disk 
# ├─sda1  8:1    0   19G  0 part /
# └─sda2  8:2    0    1G  0 part [SWAP]
# sdb     8:16   0   10G  0 disk      <- Este es para DRBD
```

### 2. Optimizaciones para VM

```bash
# Instalar agente QEMU para mejor integración
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Optimización de I/O para discos virtuales
echo 'mq-deadline' > /sys/block/sda/queue/scheduler
echo 'mq-deadline' > /sys/block/sdb/queue/scheduler
```

### 3. Configuración de memoria compartida para DRBD

```bash
# Ajustar parámetros del kernel para mejor rendimiento
cat >> /etc/sysctl.conf << EOF
# Optimizaciones para DRBD
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144  
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sysctl -p
```

## Scripts de automatización

### Script de instalación para nodos DRBD

```bash
#!/bin/bash
# install-drbd-node.sh

# Actualizar sistema
apt update && apt upgrade -y

# Instalar paquetes necesarios
apt install -y drbd-utils drbd-dkms pacemaker corosync pcs nfs-kernel-server nfs-common qemu-guest-agent

# Habilitar servicios
systemctl enable drbd
systemctl enable pacemaker  
systemctl enable corosync
systemctl enable pcsd
systemctl enable qemu-guest-agent

# Configurar usuario hacluster
echo "hacluster:clusterpwd" | chpasswd

# Aplicar optimizaciones
cat >> /etc/sysctl.conf << EOF
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
EOF

sysctl -p

echo "Instalación completada. Reiniciar el sistema."
```

### Script para verificar estado del clúster

```bash
#!/bin/bash
# check-cluster-status.sh

echo "=== Estado DRBD ==="
drbdadm status

echo -e "\n=== Estado Pacemaker ==="
pcs status

echo -e "\n=== Exportaciones NFS ==="
showmount -e localhost 2>/dev/null || echo "NFS no disponible"

echo -e "\n=== Recursos de red ==="
ip addr show | grep -A2 -E "(eth|enp)"
```

## Solución de problemas específicos

### 1. Problemas comunes con DRBD

```bash
# Si DRBD no inicia
systemctl status drbd
journalctl -u drbd

# Verificar configuración
drbdadm dump all

# Problema con módulo del kernel
modprobe drbd
echo drbd >> /etc/modules
```

### 2. Problemas con Pacemaker

```bash
# Si pcs no funciona
systemctl status pcsd
systemctl restart pcsd

# Verificar comunicación entre nodos
pcs status nodes
```

### 3. Problemas con NFS

```bash
# Verificar servicios NFS
systemctl status nfs-kernel-server
systemctl status rpcbind

# Verificar exportaciones
exportfs -v
```

## Consideraciones importantes

1. **Snapshots**: Realiza snapshots de las VMs en Proxmox antes de configurar el clúster
2. **Backup**: El clúster DRBD no reemplaza los backups regulares
3. **Monitoreo**: Considera herramientas como nagios o zabbix para supervisión
4. **Actualizaciones**: Ten cuidado con actualizaciones del kernel que requieren recompilar DRBD
5. **Red**: Mantén latencia baja (<1ms idealmente) entre nodos DRBD

---

**Autor**: Rodrigo Álvarez (@incogniadev)  
**Fecha**: 2025-07-21
