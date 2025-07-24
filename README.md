# Almacenamiento de alta disponibilidad DRBD para Docker

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![DRBD Version](https://img.shields.io/badge/DRBD-9.x-green.svg)](https://linbit.com/drbd/)
[![Pacemaker](https://img.shields.io/badge/Pacemaker-2.x-orange.svg)](https://clusterlabs.org/)
[![Docker](https://img.shields.io/badge/Docker-20.x+-blue.svg)](https://docker.com/)

> **Laboratorio de alta disponibilidad** que implementa almacenamiento centralizado para Docker usando DRBD + Pacemaker + NFS con failover automático.

## ⚡ Características principales

- **Failover automático** en 30-60 segundos
- **Replicación síncrona** de datos con DRBD
- **Almacenamiento centralizado** vía NFS
- **Zero downtime** para aplicaciones Docker
- **Arquitectura de 3 nodos** escalable

## Documentación

### 📋 Proceso de Configuración Paso a Paso

1. **Crear VMs en Proxmox**
   - Consulte la guía: [🏗️ **Creación de VMs en Proxmox**](docs/01_PROXMOX.md).
   - Detalla el proceso de creación de VMs desde el shell de Proxmox con instalación automatizada.

2. **Configurar red y post-instalación**
   - Consulte la guía: [🌐 **Configuración de Debian**](docs/02_DEBIAN.md).
   - Configuración de red, hostnames y software específico por nodo.
   - **Método automatizado**: Reconfiguración con `config-network.sh` tras instalación con preseed
   - **Método manual**: Configuración completa paso a paso para instalación tradicional
   - **ISO personalizada**: [🚀 **Creación de ISO con preseed**](debian/README.md) para crear la ISO de instalación automatizada.

3. **Instalar los paquetes en los nodos DRBD y configurar el clúster de almacenamiento**
   - Consulte la guía: [⚙️ **Guía de instalación**](docs/INSTALLATION.md).
   - Incluye instrucciones detalladas para configurar DRBD y el clúster de almacenamiento.

4. **Instalar Docker en Debian y conectarlo al NFS configurado en el Clúster DRBD**
   - Consulte la guía: [🔧 **Configuración post-instalación**](docs/PROXMOX_DEBIAN.md).
   - Describe cómo integrar Docker con el almacenamiento NFS proporcionado por el clúster DRBD.

5. **Desplegar una WebApp simple en Docker y que se almacene en el NFS**
   - Consulte la guía: [🐳 Despliegue de WebApp con Docker y NFS](docs/DOCKER_WEBAPP_DEPLOYMENT.md).

6. **Probar dar de baja el nodo primario de DRBD y que la WebApp de Docker siga operativa con el failover**
   - Consulte la guía: [🔄 Pruebas de Failover DRBD](docs/DRBD_FAILOVER_TEST.md).

### 📚 Guías adicionales

| Documento | Descripción |
|-----------|-------------|
| [📐 **Arquitectura del sistema**](docs/ARCHITECTURE.md) | Diseño completo y componentes de la arquitectura DRBD |
| [🐳 **Despliegue de WebApp con Docker**](docs/DOCKER_WEBAPP_DEPLOYMENT.md) | Guía para desplegar aplicaciones web usando Docker y NFS |
| [🔄 **Pruebas de Failover DRBD**](docs/DRBD_FAILOVER_TEST.md) | Guía completa para probar el failover del clúster DRBD |
| [📝 **Changelog**](CHANGELOG.md) | Historial de cambios del proyecto |
| [🚀 **Instalación automatizada**](debian/README.md) | Creación de ISO personalizada con preseed y configuración dual de red |

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

#### ⚡ Node 3: Host de ejecución Docker (Stateless)
- **💾 Almacenamiento 100% centralizado en NFS** - Cero almacenamiento local
- **🚀 Optimizado para contenedores** - Más CPU y RAM, menos disco
- **🔄 Completamente desechable** - Puede ser recreado sin pérdida de datos
- **🌐 Configuración dual de red**: Interfaces separadas para administración (ens18) y clúster (ens19)
- **🚫 Sin persistencia local**: Solo SO en 16GB, TODO en NFS

## Requisitos del sistema

### 💻 Hardware mínimo recomendado

| Componente | Node 1 & 2 (DRBD) | Node 3 (Docker Stateless) |
|------------|-------------------|--------------------------|
| **CPU** | 2 vCPUs | 4 vCPUs |
| **RAM** | 4GB | 8GB |
| **Almacenamiento** | 24GB SO + 16GB DRBD | 16GB (solo SO) |
| **Red** | 2 interfaces (vmbr2) | 2 interfaces (vmbr2) |
| **Función** | Almacenamiento + NFS | Ejecución sin estado |

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

1. **Lee la arquitectura**: `cat docs/ARCHITECTURE.md`
2. **Sigue los pasos ordenados** en la sección "Proceso de Configuración Paso a Paso" anterior
3. **Verifica la instalación**:
   ```bash
   pcs status                    # Estado del clúster
   drbdadm status docker-vol     # Estado DRBD
   showmount -e 192.168.10.230   # Servicios NFS
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

**📅 Última actualización**: 2025-07-24 - Optimización de especificaciones para host Docker stateless con mayor rendimiento

*Esta arquitectura proporciona una base robusta para cargas de trabajo containerizadas que requieren almacenamiento persistente y altamente disponible.*
