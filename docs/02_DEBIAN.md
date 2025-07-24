# Configuración de Debian post-instalación

Esta guía cubre la configuración post-instalación de Debian en las máquinas virtuales del laboratorio DRBD después de completar la creación de VMs según [01_PROXMOX.md](01_PROXMOX.md).

## 🚀 Método recomendado: Instalación automatizada

### 1. Post-instalación con ISO personalizada

Si usaste la **ISO personalizada con preseed** ([debian/README.md](../debian/README.md)), la mayor parte de la configuración ya está completa:

**✅ Configuración automática incluida:**
- Usuario `incognia` configurado con permisos sudo
- SSH habilitado con llave pública
- Paquetes esenciales preinstalados
- QEMU Guest Agent configurado
- Configuración temporal de red (10.0.0.69/8)

### 2. Reconfiguración de red (OBLIGATORIO)

Después de la instalación automatizada, **cada VM requiere configuración individual** de red:

```bash
# 1. Conectarse vía SSH a la IP temporal
ssh incognia@10.0.0.69

# 2. Ejecutar script de reconfiguración (ubicado en el home del usuario)
sudo ./config-network.sh

# 3. Seguir el asistente interactivo para configurar:
#    - Nueva IP estática con CIDR
#    - Gateway de red
#    - Hostname específico
#    - Dominio (opcional)
#    - Interfaz secundaria para clúster (recomendado)
```

#### 🎯 Configuración objetivo por nodo:

| Nodo | Hostname | IP Primaria (ens18) | IP Clúster (ens19) | Función |
|------|----------|--------------------|--------------------|---------|
| **Node1** | `node1` | `10.0.0.231/8` | `192.168.10.231/24` | DRBD Primario |
| **Node2** | `node2` | `10.0.0.232/8` | `192.168.10.232/24` | DRBD Secundario |
| **Node3** | `node3-docker` | `10.0.0.233/8` | `192.168.10.233/24` | Docker Host |

### 3. Verificación post-configuración

```bash
# Verificar conectividad entre nodos (ejecutar en cada nodo)
ping -c 3 192.168.10.231  # Node1
ping -c 3 192.168.10.232  # Node2  
ping -c 3 192.168.10.233  # Node3

# Verificar hostname
hostname
hostname -f

# Verificar interfaces de red
ip addr show
```

---

## 🛠️ Método manual: Instalación tradicional

### Prerrequisitos

- VMs creadas según [01_PROXMOX.md](01_PROXMOX.md)
- Debian 12.11+ instalado manualmente
- Acceso SSH o consola a las VMs

### 1. Configuración inicial del sistema

**Ejecutar como `root` en todas las VMs:**

```bash
# Actualizar el sistema
apt update && apt upgrade -y

# Instalar sudo y utilidades básicas
apt install -y sudo wget curl vim nano net-tools htop tree mc btop

# Agregar usuario incognia al grupo sudo (si ya existe)
usermod -aG sudo incognia

# Instalar QEMU Guest Agent para integración con Proxmox
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Verificar configuración de usuario
su - incognia
sudo whoami  # Debe devolver: root
```

### 2. Configuración de red dual

Configurar las dos interfaces de red en cada nodo usando `/etc/network/interfaces`:

#### Node1 (DRBD Primario)
```bash
sudo tee /etc/network/interfaces > /dev/null << EOF
# Configuración de red para Node1
source /etc/network/interfaces.d/*

# Loopback interface
auto lo
iface lo inet loopback

# Interfaz primaria (administración)
auto ens18
iface ens18 inet static
    address 10.0.0.231
    netmask 255.0.0.0
    gateway 10.0.0.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Interfaz secundaria (clúster DRBD)
auto ens19
iface ens19 inet static
    address 192.168.10.231
    netmask 255.255.255.0
EOF

# Aplicar configuración
sudo systemctl restart networking
```

#### Node2 (DRBD Secundario)
```bash
sudo tee /etc/network/interfaces > /dev/null << EOF
# Configuración de red para Node2
source /etc/network/interfaces.d/*

# Loopback interface
auto lo
iface lo inet loopback

# Interfaz primaria (administración)
auto ens18
iface ens18 inet static
    address 10.0.0.232
    netmask 255.0.0.0
    gateway 10.0.0.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Interfaz secundaria (clúster DRBD)
auto ens19
iface ens19 inet static
    address 192.168.10.232
    netmask 255.255.255.0
EOF

# Aplicar configuración
sudo systemctl restart networking
```

#### Node3 (Docker Host)
```bash
sudo tee /etc/network/interfaces > /dev/null << EOF
# Configuración de red para Node3 (Docker Host)
source /etc/network/interfaces.d/*

# Loopback interface
auto lo
iface lo inet loopback

# Interfaz primaria (administración)
auto ens18
iface ens18 inet static
    address 10.0.0.233
    netmask 255.0.0.0
    gateway 10.0.0.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Interfaz secundaria (clúster)
auto ens19
iface ens19 inet static
    address 192.168.10.233
    netmask 255.255.255.0
EOF

# Aplicar configuración
sudo systemctl restart networking
```

### 3. Configuración de hostnames

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

### 4. Configuración de resolución DNS del clúster

**En todas las VMs, agregar entradas del clúster:**

```bash
sudo tee -a /etc/hosts > /dev/null << EOF
# Entradas del clúster DRBD
192.168.10.231    node1
192.168.10.232    node2  
192.168.10.233    node3-docker
192.168.10.230    cluster-vip
EOF
```

## 📦 Instalación de software específico por nodo

### Nodos DRBD (Node1 y Node2)

```bash
# Instalar paquetes DRBD y Pacemaker
sudo apt install -y \
    drbd-utils \
    drbd-dkms \
    pacemaker \
    corosync \
    pcs \
    crmsh \
    nfs-kernel-server \
    nfs-common \
    linux-headers-$(uname -r)

# Habilitar servicios
sudo systemctl enable drbd
sudo systemctl enable pacemaker  
sudo systemctl enable corosync
sudo systemctl enable pcsd

# Configurar usuario hacluster (usar la misma contraseña en ambos nodos)
sudo passwd hacluster

# Iniciar servicio pcsd
sudo systemctl start pcsd

# Verificar instalación DRBD
sudo modprobe drbd
lsmod | grep drbd
drbdadm --version
```

### Host Docker (Node3)

```bash
# Instalar Docker usando script oficial
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Habilitar y iniciar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verificar instalación
docker --version
sudo docker run hello-world

# Instalar cliente NFS para montar almacenamiento del clúster
sudo apt install -y nfs-common
```

## 🔧 Configuración de firewall

### En nodos DRBD (Node1 y Node2):

```bash
# Configurar UFW para servicios del clúster
sudo ufw allow 7789/tcp   # DRBD
sudo ufw allow 2224/tcp   # pcsd
sudo ufw allow 3121/tcp   # pacemaker
sudo ufw allow 5405/tcp   # corosync
sudo ufw allow 21064/tcp  # corosync
sudo ufw allow 9929/tcp   # corosync

# Servicios NFS
sudo ufw allow 2049/tcp   # NFS
sudo ufw allow 111/tcp    # portmapper
sudo ufw allow 20048/tcp  # mountd

# Permitir tráfico entre nodos del clúster
sudo ufw allow from 192.168.10.0/24
sudo ufw allow from 10.0.0.0/8

# Habilitar firewall
sudo ufw --force enable
```

### En Docker Host (Node3):

```bash
# Configuración mínima de firewall para Docker
sudo ufw allow 2049/tcp   # Cliente NFS
sudo ufw allow 111/tcp    # portmapper

# Permitir tráfico del clúster
sudo ufw allow from 192.168.10.0/24
sudo ufw allow from 10.0.0.0/8

# Habilitar firewall
sudo ufw --force enable
```

## ⚡ Optimizaciones para entorno virtualizado

### 1. Verificación de discos

```bash
# En nodos DRBD (Node1 y Node2)
sudo lsblk

# Salida esperada:
# sda     8:0    0   24G  0 disk 
# ├─sda1  8:1    0   23G  0 part /
# └─sda2  8:2    0    1G  0 part [SWAP]
# sdb     8:16   0   16G  0 disk      <- Para DRBD

# En Node3 Docker (stateless):
# sda     8:0    0   16G  0 disk 
# ├─sda1  8:1    0   15G  0 part /
# └─sda2  8:2    0    1G  0 part [SWAP]
```

### 2. Optimizaciones de I/O (todas las VMs)

```bash
# Optimizar planificador de I/O para discos virtuales
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler

# Solo en nodos DRBD
if [ -b /dev/sdb ]; then
    echo 'mq-deadline' | sudo tee /sys/block/sdb/queue/scheduler
fi

# Hacer persistente
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="mq-deadline"' | \
sudo tee /etc/udev/rules.d/60-scheduler.rules
```

### 3. Optimizaciones de red para DRBD (Node1 y Node2)

```bash
# Parámetros del kernel para mejor rendimiento de DRBD
sudo tee -a /etc/sysctl.conf > /dev/null << EOF
# Optimizaciones para DRBD
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144  
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
EOF

# Aplicar cambios
sudo sysctl -p
```

## 🔍 Verificación final

### Verificar conectividad de red

```bash
# Desde cualquier nodo, verificar conectividad con todos los demás
ping -c 3 node1
ping -c 3 node2
ping -c 3 node3-docker

# Verificar resolución DNS
nslookup node1
nslookup node2
nslookup node3-docker
```

### Verificar servicios instalados

```bash
# En nodos DRBD (Node1 y Node2)
systemctl status pcsd
systemctl status drbd
drbdadm --version

# En Node3 Docker
systemctl status docker
docker --version
```

## 📋 Scripts de automatización

### Script para nodos DRBD

```bash
#!/bin/bash
# install-drbd-node.sh - Ejecutar en Node1 y Node2

set -e

echo "=== Instalación automatizada para nodo DRBD ==="

# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar paquetes
sudo apt install -y \
    drbd-utils drbd-dkms \
    pacemaker corosync pcs crmsh \
    nfs-kernel-server nfs-common \
    linux-headers-$(uname -r)

# Habilitar servicios
sudo systemctl enable drbd pacemaker corosync pcsd

echo "✅ Instalación completada. Configurar contraseña de hacluster:"
sudo passwd hacluster

echo "✅ Nodo DRBD configurado. Proceder con configuración del clúster."
```

### Script para Docker Host

```bash
#!/bin/bash
# install-docker-node.sh - Ejecutar en Node3

set -e

echo "=== Instalación automatizada para Docker Host ==="

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Configurar Docker
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Instalar cliente NFS
sudo apt install -y nfs-common

echo "✅ Docker Host configurado."
echo "⚠️  Reinicia la sesión para aplicar permisos de grupo docker."
```

## 📍 Próximos pasos

Una vez completada la configuración de Debian:

1. **Verificar que todos los nodos están operativos**
2. **Continuar con [INSTALLATION.md](INSTALLATION.md)** para configurar el clúster DRBD
3. **Configurar Pacemaker y recursos del clúster**
4. **Instalar y configurar servicios NFS**
5. **Conectar Docker al almacenamiento NFS**

---

**📅 Creado**: 2025-01-24  
**✏️ Autor**: Rodrigo Álvarez (@incogniadev)  
**🔗 Relacionado**: [01_PROXMOX.md](01_PROXMOX.md) | [INSTALLATION.md](INSTALLATION.md) | [ARCHITECTURE.md](ARCHITECTURE.md)
