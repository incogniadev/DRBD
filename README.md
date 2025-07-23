# Almacenamiento de alta disponibilidad DRBD para Docker

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![DRBD Version](https://img.shields.io/badge/DRBD-9.x-green.svg)](https://linbit.com/drbd/)
[![Pacemaker](https://img.shields.io/badge/Pacemaker-2.x-orange.svg)](https://clusterlabs.org/)
[![Docker](https://img.shields.io/badge/Docker-20.x+-blue.svg)](https://docker.com/)
[![NFS](https://img.shields.io/badge/NFS-v4-lightblue.svg)](https://en.wikipedia.org/wiki/Network_File_System)
[![Linux](https://img.shields.io/badge/OS-Linux-red.svg)](https://www.linux.org/)
[![High Availability](https://img.shields.io/badge/HA-Cluster-brightgreen.svg)](#)
[![Lab Environment](https://img.shields.io/badge/Environment-Laboratory-purple.svg)](#)
[![Architecture](https://img.shields.io/badge/Type-Architecture%20Design-blue.svg)](#)

## Descripción

Diseño de arquitectura y laboratorio de pruebas para implementar una solución de alta disponibilidad para almacenamiento de contenedores Docker utilizando DRBD (Distributed Replicated Block Device) con gestión de clúster Pacemaker y servicios NFS. Este repositorio contiene las instrucciones detalladas y configuraciones necesarias para crear un entorno de laboratorio que demuestre esta arquitectura de alta disponibilidad.

## Últimos cambios

**Última actualización:** 2025-07-23

- ✅ **Corrección integral de inconsistencias** - Unificación del esquema de red y especificaciones
- ✅ **Documentación de vmbr2** - Explicación completa de configuración de red dedicada
- ✅ **Especificaciones unificadas** - Hardware consolidado a 4GB RAM en todos los nodos
- ✅ **Herramientas completas** - Documentación exhaustiva de dependencias y requisitos
- ✅ **Referencias consistentes** - Eliminación de duplicaciones y enlaces verificados

## Características principales

- ✅ **Alta disponibilidad** - Failover automático con tiempo de inactividad mínimo
- ✅ **Consistencia de datos** - Replicación síncrona garantiza integridad
- ✅ **Failover transparente** - Las aplicaciones continúan ejecutándose durante el failover
- ✅ **Almacenamiento centralizado** - Punto único de gestión de almacenamiento para contenedores
- ✅ **Escalabilidad** - Fácil adición de nuevos hosts Docker como clientes NFS

## Documentación

### 📋 Guías disponibles

| Documento | Descripción |
|-----------|-------------|
| [📐 **Arquitectura del sistema**](docs/ARCHITECTURE.md) | Diseño completo y componentes de la arquitectura DRBD |
| [🚀 **Instalación automatizada**](debian/README.md) | Instalación desatendida con Debian 12 + preseed (Recomendado) |
| [🤖 **Scripts de automatización**](scripts/README.md) | Scripts para creación automatizada de VMs en Proxmox (Nuevo) |
| [🏗️ **Creación de VMs en Proxmox**](docs/PROXMOX_VM_CREATION.md) | Guía detallada para crear VMs desde shell de Proxmox |
| [⚙️ **Guía de instalación**](docs/INSTALLATION.md) | Instrucciones generales de instalación y configuración |
| [🔧 **Configuración post-instalación**](docs/PROXMOX_DEBIAN.md) | Configuración específica para entornos Proxmox con Debian |
| [📝 **Changelog**](CHANGELOG.md) | Historial de cambios del proyecto |

## Componentes del sistema

### Descripción general de nodos

| Nodo | Función | Rol Principal |
|------|---------|---------------|
| **Node 1** | DRBD Primario | Almacenamiento activo, NFS activo |
| **Node 2** | DRBD Secundario | Replica en standby, NFS standby |
| **Node 3** | Host Docker | Ejecución de contenedores |
| **VIP** | IP Flotante | Punto de acceso para alta disponibilidad |

> **📍 Configuración de red detallada**: Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#configuración-de-red) para el esquema completo de IPs y configuración de red.

### Características principales por nodo

#### 🔵 Node 1 & Node 2: Nodos de almacenamiento DRBD
- Replicación sincrónica de datos en tiempo real
- Gestión automática de failover con Pacemaker
- Servicio NFS para compartir almacenamiento
- Dispositivos: `/dev/sdb1` → `/dev/drbd0` → `/mnt/docker-vol`

#### 🟢 Node 3: Host de ejecución Docker
- **Almacenamiento 100% centralizado en NFS**
- Sin datos persistentes locales
- Acceso transparente vía IP flotante
- Configuración dual de red para administración y clúster

## Requisitos del sistema

### 💻 Hardware mínimo recomendado

|| Componente | Node 1 & 2 (DRBD) | Node 3 (Docker) |
||------------|-------------------|------------------|
|| **CPU** | 2 vCPUs | 2 vCPUs |
|| **RAM** | 4GB | 4GB |
|| **Almacenamiento** | 24GB SO + 16GB DRBD | 32GB |
|| **Red** | 2 interfaces (vmbr2) | 2 interfaces (vmbr2) |

### 🛠️ Software requerido

| Componente | Versión | Notas |
|------------|---------|-------|
| **Linux OS** | Debian 12.11+, Ubuntu 22.04+, RHEL/CentOS 9+ | - |
| **DRBD** | 9.x+ | Con módulos del kernel |
| **Pacemaker** | 2.x+ | Gestión de clúster |
| **Corosync** | Compatible con Pacemaker | Comunicación del clúster |
| **NFS** | v4+ | Cliente y servidor |
| **Docker** | 20.x+ | En Node 3 únicamente |

## 🚀 Inicio rápido

Para comenzar con la implementación del clúster DRBD de alta disponibilidad, sigue estos pasos:

### 1. Revisa la arquitectura
```bash
# Lee primero la documentación de arquitectura
cat docs/ARCHITECTURE.md
```

### 2. Instalación automatizada con Debian (Recomendado)

#### Para entornos Proxmox con instalación desatendida:

**🎆 Método 1: Automatización completa con script (Recomendado)**
```bash
# 1. En el host Proxmox, ejecutar script de automatización
./scripts/create-drbd-vms.sh
# Crea automáticamente las 3 VMs con ISO preseed

# 2. Instalación escalonada (importante para evitar colisiones IP)
qm start 231  # Node1 - esperar ~10 min
qm start 232  # Node2 - cuando Node1 esté listo
qm start 233  # Node3 - cuando Node2 esté listo

# 3. Configurar red en cada VM post-instalación
ssh incognia@10.0.0.69
sudo ./config-network.sh
# Repetir para cada VM con IPs finales: 231, 232, 233
```

**🛠️ Método 2: Creación manual de VMs**
```bash
# 1. Crear VMs manualmente usando la ISO personalizada
# Usar: debian/debian-12.11.0-amd64-preseed.iso
# Ver: docs/PROXMOX_VM_CREATION.md

# 2. La instalación se ejecuta automáticamente con:
# - Usuario: incognia (con sudo y SSH)
# - Red estática: 10.0.0.69/8 (reconfigurar post-instalación)
# - Paquetes preinstalados: SSH, herramientas de sistema

# 3. Reconfigurar red post-instalación
sudo ./config-network.sh

# 4. Seguir guía de configuración post-instalación
cat docs/PROXMOX_DEBIAN.md
```

#### Crear ISO personalizada (opcional):
```bash
# Si necesitas generar la ISO personalizada
cd debian/
./create-preseed-iso.sh
# Genera: debian-12.11.0-amd64-preseed.iso
```

### 3. Métodos de instalación alternativos

#### Instalación general (cualquier Linux)
```bash
# Sigue la guía general de instalación
cat docs/INSTALLATION.md
```

#### Instalación manual para Proxmox + Debian
```bash
# Para instalación manual tradicional
cat docs/PROXMOX_DEBIAN.md
```

### 3. Verificación post-instalación

```bash
# Verificar estado del clúster DRBD
drbdadm status docker-vol

# Verificar estado de Pacemaker
pcs status

# Verificar montajes NFS
showmount -e 192.168.10.230

# Verificar Docker
docker info
```

## ⚡ Proceso de failover automático

La arquitectura implementa un failover completamente automático:

1. 🔍 **Detección de falla** → Pacemaker detecta falla del nodo primario
2. 🔄 **Promoción de recursos** → DRBD secundario se promueve a primario  
3. 📁 **Montaje de filesystem** → Sistema de archivos montado en nuevo nodo
4. 🌐 **Migración de IP flotante** → IP virtual migra al nodo activo
5. 🔌 **Reconexión automática** → Docker se reconecta transparentemente

**Tiempo de failover típico: 30-60 segundos**

## 🔧 Comandos útiles

### Monitoreo del clúster
```bash
# Estado general del clúster
pcs status

# Estado específico de DRBD
drbdadm status docker-vol

# Verificar servicios NFS
showmount -e 192.168.10.230
```

### Mantenimiento
```bash
# Modo mantenimiento (standby)
pcs cluster standby node1

# Salir de modo mantenimiento
pcs cluster unstandby node1

# Backup de configuración
pcs config backup cluster-backup.tar.bz2
```

Para más detalles sobre monitoreo, mantenimiento y resolución de problemas, consulta la [📖 **guía de instalación**](docs/INSTALLATION.md).

## Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## Licencia

Este proyecto está licenciado bajo MIT License. Ver el archivo [LICENSE](LICENSE) para detalles.

## Autor

Diseño de arquitectura por Rodrigo Ernesto Álvarez Aguilera (@incogniadev) - Ingeniero DevOps en Promad Business Solutions

---

*Esta arquitectura proporciona una base robusta para cargas de trabajo containerizadas que requieren almacenamiento persistente y altamente disponible.*
