# Configuración post-instalación para Debian en Proxmox

Esta guía cubre la configuración específica de software después de instalar Debian en las máquinas virtuales del laboratorio DRBD.

## Prerrequisitos

- VMs creadas según [PROXMOX_VM_CREATION.md](PROXMOX_VM_CREATION.md)
- Debian 12.11+ instalado en todas las VMs
- Acceso SSH o consola a las máquinas virtuales
- Red configurada con acceso a internet para descarga de paquetes

## Configuración inicial del sistema

### 1. Configuración inicial como root (en todas las VMs)

**Nota**: Estos comandos deben ejecutarse como `root` inmediatamente después de la instalación de Debian.

```bash
# Actualizar el sistema
apt update && apt upgrade -y

# Instalar sudo y utilidades básicas
apt install -y sudo wget curl vim nano net-tools htop tree

# Agregar usuario incognia (creado durante instalación) al grupo sudo
usermod -aG sudo incognia

# Verificar que el usuario está en el grupo sudo
groups incognia

# Instalar agente QEMU para mejor integración con Proxmox
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Cambiar a usuario incognia para el resto de la configuración
su - incognia
```

### 2. Verificación de configuración de usuario

```bash
# Como usuario incognia, verificar que sudo funciona
sudo whoami
# Debería devolver: root

# Verificar conectividad a internet
ping -c 3 8.8.8.8
```

### 2. Configuración de red dual (todas las VMs)

**Nota**: Esta configuración asume que las VMs tienen dos interfaces de red como se especifica en la guía de creación.

#### Node1 (192.168.10.231)
```bash
sudo cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.0.0.231/8
      gateway4: 10.0.0.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: default
          via: 10.0.0.1
    eth1:
      addresses:
        - 192.168.10.231/24
EOF

sudo netplan apply
```

#### Node2 (192.168.10.232)
```bash
sudo cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 10.0.0.232/8
      gateway4: 10.0.0.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: default
          via: 10.0.0.1
    eth1:
      addresses:
        - 192.168.10.232/24
EOF

sudo netplan apply
```

#### Node3 (192.168.10.233)
```bash
sudo cat > /etc/netplan/01-netcfg.yaml << EOF
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

sudo netplan apply
```

### 3. Configurar hostnames y resolución DNS

#### En Node1:
```bash
sudo hostnamectl set-hostname node1
echo "127.0.1.1 node1" | sudo tee -a /etc/hosts
```

#### En Node2:
```bash
sudo hostnamectl set-hostname node2
echo "127.0.1.1 node2" | sudo tee -a /etc/hosts
```

#### En Node3:
```bash
sudo hostnamectl set-hostname node3-docker
echo "127.0.1.1 node3-docker" | sudo tee -a /etc/hosts
```

#### En todas las VMs, agregar resolución de nombres del clúster:
```bash
cat << EOF | sudo tee -a /etc/hosts
192.168.10.231    node1
192.168.10.232    node2  
192.168.10.233    node3-docker
192.168.10.230    cluster-vip
EOF
```

## Instalación de software específico

### 1. Instalación de DRBD en nodos 1 y 2

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

### 2. Configuración de Pacemaker en nodos 1 y 2

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

### 3. Instalación de Docker en Node3

```bash
# Instalar Docker usando el script oficial
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario actual al grupo docker
sudo usermod -aG docker $USER

# Habilitar y iniciar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verificar instalación
docker --version
sudo docker run hello-world
```

### 4. Configuración de firewall en nodos DRBD

```bash
# Si ufw está habilitado, configurar reglas para el clúster (solo en nodos 1 y 2)
sudo ufw allow 7789/tcp  # DRBD
sudo ufw allow 2224/tcp  # pcsd
sudo ufw allow 3121/tcp  # pacemaker
sudo ufw allow 5405/tcp  # corosync
sudo ufw allow 21064/tcp # corosync
sudo ufw allow 9929/tcp  # corosync

# Para NFS
sudo ufw allow 2049/tcp  # NFS
sudo ufw allow 111/tcp   # portmapper
sudo ufw allow 20048/tcp # mountd

# Permitir tráfico entre nodos del clúster
sudo ufw allow from 192.168.10.0/24
sudo ufw allow from 10.0.0.0/8
```

## Optimizaciones para entorno virtualizado

### 1. Verificación de configuración de discos

```bash
# Verificar que los discos estén disponibles (en nodos 1 y 2)
sudo lsblk

# Debería mostrar algo como:
# sda     8:0    0   24G  0 disk 
# ├─sda1  8:1    0   23G  0 part /
# └─sda2  8:2    0    1G  0 part [SWAP]
# sdb     8:16   0   16G  0 disk      <- Este es para DRBD

# En Node3 debería mostrar:
# sda     8:0    0   32G  0 disk 
# ├─sda1  8:1    0   31G  0 part /
# └─sda2  8:2    0    1G  0 part [SWAP]
```

### 2. Optimizaciones de rendimiento para VMs

```bash
# Optimización de I/O para discos virtuales (en todas las VMs)
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler

# Solo en nodos DRBD (1 y 2)
if [ -b /dev/sdb ]; then
    echo 'mq-deadline' | sudo tee /sys/block/sdb/queue/scheduler
fi

# Hacer persistente la configuración
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="mq-deadline"' | sudo tee /etc/udev/rules.d/60-scheduler.rules
```

### 3. Optimizaciones de red para DRBD (solo nodos 1 y 2)

```bash
# Ajustar parámetros del kernel para mejor rendimiento
cat << EOF | sudo tee -a /etc/sysctl.conf
# Optimizaciones para DRBD
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144  
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Optimizaciones adicionales para clúster
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
EOF

# Aplicar cambios
sudo sysctl -p
```

## Scripts de automatización

### Script de instalación para nodos DRBD (nodos 1 y 2)

```bash
#!/bin/bash
# install-drbd-node.sh
# Ejecutar como root en nodos 1 y 2

set -e

echo "=== Instalación de paquetes DRBD ==="
# Actualizar sistema
apt update && apt upgrade -y

# Instalar paquetes necesarios
apt install -y \
    drbd-utils \
    drbd-dkms \
    pacemaker \
    corosync \
    pcs \
    crmsh \
    nfs-kernel-server \
    nfs-common \
    qemu-guest-agent \
    linux-headers-$(uname -r)

echo "=== Configuración de servicios ==="
# Habilitar servicios
systemctl enable drbd
systemctl enable pacemaker  
systemctl enable corosync
systemctl enable pcsd
systemctl enable qemu-guest-agent

# Iniciar QEMU guest agent
systemctl start qemu-guest-agent

echo "=== Configuración de usuario hacluster ==="
# Configurar usuario hacluster (cambiar la contraseña según necesidades)
echo "hacluster:clusterpwd" | chpasswd

echo "=== Aplicación de optimizaciones ==="
# Aplicar optimizaciones de red
cat >> /etc/sysctl.conf << EOF
# Optimizaciones para DRBD
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl -p

echo "=== Instalación completada ==="
echo "IMPORTANTE: Reiniciar el sistema antes de continuar con la configuración del clúster."
echo "Comando: sudo reboot"
```

### Script de instalación para Node3 (Docker)

```bash
#!/bin/bash
# install-docker-node.sh
# Ejecutar como root en node3

set -e

echo "=== Instalación de Docker ==="
# Actualizar sistema
apt update && apt upgrade -y

# Instalar utilidades básicas
apt install -y \
    wget \
    curl \
    vim \
    nano \
    net-tools \
    htop \
    tree \
    qemu-guest-agent

echo "=== Instalación de Docker ==="
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Configurar Docker
systemctl enable docker
systemctl start docker
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

echo "=== Configuración de usuario Docker ==="
# Agregar usuario al grupo docker (cambiar 'debian' por tu usuario)
USER_NAME=$(logname 2>/dev/null || echo "debian")
if id "$USER_NAME" &>/dev/null; then
    usermod -aG docker $USER_NAME
    echo "Usuario $USER_NAME agregado al grupo docker"
else
    echo "Usuario $USER_NAME no encontrado. Agregar manualmente con: usermod -aG docker [usuario]"
fi

echo "=== Instalación completada ==="
echo "Docker versión: $(docker --version)"
echo "IMPORTANTE: Cerrar sesión y volver a iniciar para aplicar permisos de Docker."
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
