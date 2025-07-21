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
| [⚙️ **Guía de instalación**](docs/INSTALLATION.md) | Instrucciones generales de instalación y configuración |
| [🏗️ **Implementación en Proxmox**](docs/PROXMOX_DEBIAN.md) | Guía específica para entornos Proxmox con Debian |
| [📝 **Changelog**](CHANGELOG.md) | Historial de cambios del proyecto |

## Componentes del sistema

### Descripción general de nodos

| Nodo | Función | IP Principal | IP del Clúster | Rol |
|------|---------|--------------|----------------|-----|
| **Node 1** | DRBD Primario | `10.0.0.231/8` | `192.168.10.231/24` | Almacenamiento activo, NFS activo |
| **Node 2** | DRBD Secundario | `10.0.0.232/8` | `192.168.10.232/24` | Replica en standby, NFS standby |
| **Node 3** | Host Docker | `10.0.0.233/8` | `192.168.10.233/24` | Ejecución de contenedores |
| **VIP** | IP Flotante | - | `192.168.10.230/24` | Punto de acceso para alta disponibilidad |

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

| Componente | Node 1 & 2 (DRBD) | Node 3 (Docker) |
|------------|-------------------|------------------|
| **CPU** | 2 vCPUs | 2 vCPUs |
| **RAM** | 2GB (4GB recomendado) | 4GB mínimo |
| **Almacenamiento** | 20GB SO + 10GB DRBD | 30GB |
| **Red** | 2 interfaces (gestión + clúster) | 2 interfaces |

### 🛠️ Software requerido

| Componente | Versión | Notas |
|------------|---------|-------|
| **Linux OS** | Debian 11+, Ubuntu 20.04+, RHEL/CentOS 8+ | - |
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

### 2. Selecciona tu guía de instalación

#### Instalación general (cualquier Linux)
```bash
# Sigue la guía general de instalación
cat docs/INSTALLATION.md
```

#### Instalación específica para Proxmox + Debian
```bash
# Para entornos virtualizados con Proxmox
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
