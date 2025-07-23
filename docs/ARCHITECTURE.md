# Arquitectura de alta disponibilidad DRBD

## Descripción general

Este documento describe una solución de almacenamiento de alta disponibilidad utilizando DRBD (Distributed Replicated Block Device) con gestión de clúster Pacemaker y servicios NFS para cargas de trabajo en contenedores.

## Arquitectura del sistema

```mermaid
graph TB
    subgraph "Capa de almacenamiento"
        subgraph N1 ["Nodo 1 (node1) - Primario"]
            A1N["Admin: 10.0.0.231/8<br/>Cluster: 192.168.10.231/24"]
            A1["/dev/sdb1<br/>Dispositivo físico"]
            A2["/dev/drbd0<br/>DRBD primario"]
            A3["/mnt/docker-vol<br/>Sistema de archivos montado"]
            A3a["📦 TODO Docker Storage:<br/>• Imágenes (/images/)<br/>• Contenedores (/containers/)<br/>• Volúmenes (/volumes/)<br/>• Logs y Cache"]
            A4["Servidor NFS<br/>(Activo)"]
            A5["192.168.10.230<br/>IP flotante"]
        end
        
        subgraph N2 ["Nodo 2 (node2) - Secundario"]
            B1N["Admin: 10.0.0.232/8<br/>Cluster: 192.168.10.232/24"]
            B1["/dev/sdb1<br/>Dispositivo físico"]
            B2["/dev/drbd0<br/>DRBD secundario"]
            B3["/mnt/docker-vol<br/>Desmontado"]
            B3a["📦 TODO Docker Storage:<br/>(Réplica sincronizada)<br/>• Imágenes (/images/)<br/>• Contenedores (/containers/)<br/>• Volúmenes (/volumes/)"]
            B4["Servidor NFS<br/>(En espera)"]
            B5["Agente Pacemaker<br/>(En espera)"]
        end
    end
    
    subgraph "Gestión del clúster"
        C1["Clúster Pacemaker<br/>Red: 192.168.10.0/24"]
        C2["Monitor de recursos"]
        C3["Controlador de failover"]
        C4["Gestor de IP"]
    end
    
    subgraph "Capa de aplicación"
        D1N["Admin: 10.0.0.233/8<br/>Cluster: 192.168.10.233/24"]
        D1["⚡ Host Docker (STATELESS)<br/>(node3-docker)<br/>🚫 SIN almacenamiento local"]
        D2["Cliente NFS<br/>📦 TODO storage en NFS"]
        D3["Contenedor 1"]
        D4["Contenedor 2"]
        D5["Contenedor N"]
    end
    
    %% Storage flow
    A1 --> A2
    A2 --> A3
    A3 --> A3a
    A3a --> A4
    A4 --> A5
    
    B1 --> B2
    B2 --> B3
    B3 --> B3a
    B3a --> B4
    
    %% Replicación DRBD
    A2 -.->|"Replicación de datos"| B2
    
    %% Gestión Pacemaker
    C1 --> C2
    C2 --> C3
    C3 --> C4
    
    %% Monitoreo del clúster
    C2 -.->|"Monitorear"| A2
    C2 -.->|"Monitorear"| B2
    C2 -.->|"Monitorear"| A4
    C2 -.->|"Monitorear"| B4
    
    %% Control de failover
    C3 -.->|"Promover/Degradar"| A2
    C3 -.->|"Promover/Degradar"| B2
    C3 -.->|"Iniciar/Detener"| A4
    C3 -.->|"Iniciar/Detener"| B4
    C4 -.->|"Gestionar"| A5
    
    %% Acceso de aplicación - Docker Engine hacia NFS (red de clúster)
    D1 --> D2
    D2 -->|"Montaje NFS<br/>192.168.10.0/24"| A5
    
    %% Aplicaciones Docker hacia usuarios (red de administración)
    D1N -.->|"Apps Docker<br/>10.0.0.0/8"| D3
    D1N -.->|"Apps Docker<br/>10.0.0.0/8"| D4
    D1N -.->|"Apps Docker<br/>10.0.0.0/8"| D5
    
    %% Reporte de standby
    B5 -.->|"Reporte de estado"| C1
    
    %% Styling
    classDef primary fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef secondary fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef cluster fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef application fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class A1,A2,A3,A3a,A4,A5 primary
    class B1,B2,B3,B3a,B4,B5 secondary
    class C1,C2,C3,C4 cluster
    class D1,D2,D3,D4,D5 application
```

## Componentes de la arquitectura

### Nodo 1: Nodo DRBD primario
- **Dispositivo físico**: `/dev/sdb1` - Dispositivo de bloque raw
- **Dispositivo DRBD**: `/dev/drbd0` - Dispositivo de bloque replicado
- **Punto de montaje**: `/mnt/docker-vol` - Montaje del sistema de archivos
- **Servidor NFS**: Servicio NFS activo
- **IP flotante**: `192.168.10.230` - IP virtual para alta disponibilidad

### Nodo 2: Nodo DRBD secundario
- **Dispositivo físico**: `/dev/sdb1` - Dispositivo de bloque raw (en espera)
- **Dispositivo DRBD**: `/dev/drbd0` - Dispositivo de bloque replicado (secundario)
- **Punto de montaje**: `/mnt/docker-vol` - Montaje del sistema de archivos (en espera)
- **Servidor NFS**: Servicio NFS en espera
- **Pacemaker**: Modo en espera, listo para failover

### Gestor de clúster Pacemaker
- **Monitoreo DRBD**: Monitorea continuamente el estado de los recursos DRBD
- **Promoción de nodos**: Promueve el nodo secundario a primario durante el failover
- **Gestión de IP**: Administra la asignación de IP flotante
- **Gestión NFS**: Controla el servicio NFS activo

### Nodo 3: Host Docker
- **Cliente NFS**: Se conecta al servicio NFS vía IP flotante en red de clúster
- **Aplicaciones Docker**: Ejecutan en red de administración para acceso de usuarios
- **Almacenamiento de contenedores**: Imágenes y contenedores almacenados en NFS (red de clúster)
- **Configuración de red**:
  - **IP primaria**: `10.0.0.233/8` - Red de administración (aplicaciones Docker, SSH, gestión)
  - **IP secundaria**: `192.168.10.233/24` - Red del clúster (montajes NFS hacia `192.168.10.230`)
  - **Acceso NFS**: Montajes desde `192.168.10.233` hacia IP flotante `192.168.10.230`

## Principios clave de diseño

### Arquitectura de almacenamiento Docker

**⚠️ REGLA FUNDAMENTAL: TODOS los componentes de Docker DEBEN almacenarse en NFS, NO en el almacenamiento local del servidor Docker.**

#### 💾 Almacenamiento Docker en NFS (OBLIGATORIO)
TODOS los siguientes componentes DEBEN configurarse para usar el almacenamiento NFS montado:

- **Imágenes Docker**: Almacenadas en `/mnt/nfs/docker/images/` (NFS)
- **Contenedores**: Todos los contenedores y sus capas en `/mnt/nfs/docker/containers/` (NFS)
- **Volúmenes Docker**: Todos los volúmenes en `/mnt/nfs/docker/volumes/` (NFS)
- **Datos de aplicaciones**: Datos persistentes de aplicaciones en NFS
- **Caché de construcción**: Build cache en `/mnt/nfs/docker/buildkit/` (NFS)
- **Registros de contenedores**: Logs en `/mnt/nfs/docker/containers/*/` (NFS)
- **Configuración del daemon**: Docker daemon configurado con `data-root` apuntando a NFS

#### 🚫 Prohibido en almacenamiento local
- **NO** usar `/var/lib/docker/` (almacenamiento local)
- **NO** almacenar imágenes en disco local del servidor
- **NO** crear volúmenes en storage local
- **NO** usar bind mounts a directorios locales para datos persistentes

#### Configuración del Docker Daemon
```json
{
  "data-root": "/mnt/nfs/docker",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### Rol del host Docker (Nodo 3)
- **⚡ Solo ejecución**: El servidor sirve únicamente como motor de ejecución Docker
- **🚫 Sin almacenamiento local**: CERO imágenes, contenedores o datos persistentes en disco local
- **🔗 100% dependiente de NFS**: Toda operación Docker depende del almacenamiento NFS
- **🔄 Completamente sin estado**: El servidor puede ser destruido y recreado sin pérdida de datos
- **💾 Punto de montaje único**: Todo Docker almacenado en `/mnt/nfs/` (montaje NFS)

## Proceso de failover

1. **Detección de falla**: Pacemaker detecta la falla del nodo primario
2. **Promoción de recursos**: El dispositivo DRBD secundario se promueve a primario
3. **Montaje del sistema de archivos**: Monta el sistema de archivos en el nuevo nodo primario
4. **Inicio de servicios**: Inicia el servidor NFS en el nuevo nodo primario
5. **Migración de IP**: Mueve la IP flotante al nuevo nodo primario
6. **Reconexión del cliente**: El host Docker se reconecta al nuevo servidor NFS

## Beneficios

### Características de alta disponibilidad
- ✅ **Failover automático** - Tiempo de inactividad mínimo durante fallas de nodos
- ✅ **Consistencia de datos** - La replicación síncrona garantiza la integridad
- ✅ **Failover transparente** - Las aplicaciones continúan durante el failover
- ✅ **Almacenamiento centralizado** - Punto único de gestión de almacenamiento
- ✅ **Escalabilidad** - Fácil adición de hosts de ejecución Docker

### Beneficios del almacenamiento 100% NFS para Docker
1. **🔥 Falla total del servidor**: Si el servidor Docker se destruye completamente, CERO pérdida de datos
2. **🔄 Reemplazo instantáneo**: Nuevo servidor Docker listo en minutos montando el mismo NFS
3. **💾 Consistencia absoluta**: Mismas imágenes y contenedores disponibles desde cualquier host
4. **🛡️ Respaldos centralizados**: Un solo punto de respaldo para todo el entorno Docker
5. **⚙️ Escalabilidad sin límites**: Múltiples hosts Docker pueden usar el mismo almacenamiento
6. **🔁 Recuperación instantánea**: Failover de DRBD = TODO el entorno Docker disponible inmediatamente
7. **🧠 Administración simplificada**: Un solo sistema de archivos para gestionar todo Docker
8. **📊 Monitoreo centralizado**: Todos los logs y métricas en una ubicación

### ⚠️ Implicaciones críticas del almacenamiento NFS obligatorio

#### Ventajas operativas:
- **Host Docker es desechable**: El servidor puede ser recreado sin afectar aplicaciones
- **Mantenimiento sin downtime**: Migración de cargas a otro host mientras se mantiene el servidor
- **Actualizaciones seguras**: Actualizar SO/Docker sin riesgo de pérdida de datos
- **Testing sin riesgo**: Probar configuraciones en hosts temporales

#### Consideraciones de rendimiento:
- **Latencia de red**: Todas las operaciones Docker dependen de la latencia hacia NFS
- **Ancho de banda crítico**: Operaciones de imágenes grandes requieren ancho de banda adecuado
- **Optimización NFS**: Configuración de NFS debe optimizarse para cargas Docker
- **Red de clúster dedicada**: TRÁFICO NFS debe ir por red de clúster (`192.168.10.0/24`)

## Configuración de red

### Esquema de direcciones IP

**⚠️ Nota importante:** Durante la instalación automatizada, todas las VMs usan temporalmente la IP `10.0.0.69/8` y deben ser reconfiguradas individualmente después de la instalación usando el script `config-network.sh`.

#### Arquitectura de red dual

El laboratorio DRBD implementa una arquitectura de red de interfaz dual para separar el tráfico de administración del tráfico del clúster, proporcionando mejor aislamiento y rendimiento:

- **Interfaz primaria (`ens18`)**: Red de administración/acceso general
- **Interfaz secundaria (`ens19`)**: Red dedicada del clúster DRBD/Pacemaker

#### Red de producción (configuración final):

| Nodo | Interfaz Primaria (Administración) | Interfaz Secundaria (Clúster) | Hostname |
|------|-----------------------------------|-------------------------------|----------|
| **Nodo 1 (DRBD primario)** | `10.0.0.231/8` | `192.168.10.231/24` | `node1` |
| **Nodo 2 (DRBD secundario)** | `10.0.0.232/8` | `192.168.10.232/24` | `node2` |
| **Nodo 3 (Host Docker)** | `10.0.0.233/8` | `192.168.10.233/24` | `node3-docker` |

- **IP flotante**: `192.168.10.230/24` (IP virtual para HA en red de clúster)
- **Gateway de administración**: `10.0.0.1`
- **Gateway de clúster**: `192.168.10.1`
- **DNS**: `8.8.8.8, 8.8.4.4`

#### Red temporal (durante instalación):
- **IP temporal**: `10.0.0.69/8` (todas las VMs durante instalación preseed)
- **Gateway temporal**: `10.0.0.1`
- **Hostname temporal**: `preseed`

### Configuración automática de red post-instalación

El script `config-network.sh` configura automáticamente la arquitectura de red dual en cada nodo.

#### Configuración de `/etc/network/interfaces` generada:

```bash
# Interfaz de administración (ens18)
auto ens18
iface ens18 inet static
    address 10.0.0.231
    netmask 255.0.0.0
    gateway 10.0.0.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Interfaz de clúster (ens19) - sin gateway
auto ens19
iface ens19 inet static
    address 192.168.10.231
    netmask 255.255.255.0
```

### Requisitos de red
- **Baja latencia**: <1ms idealmente entre nodos DRBD en red de clúster
- **Red dual segregada**: 
  - **Red de administración (`10.0.0.0/8`)**: SSH, gestión, **aplicaciones Docker** y acceso de usuarios
  - **Red de clúster (`192.168.10.0/24`)**: TRÁFICO DRBD, Pacemaker, **montajes NFS** e IP flotante
- **Ancho de banda**: Suficiente para:
  - Transferencias de imágenes Docker y datos de contenedores (red de clúster)
  - Tráfico de aplicaciones hacia usuarios (red de administración)
- **Aislamiento**: Separación física o lógica entre redes de administración y clúster

#### Flujo de tráfico por red:
- **Aplicaciones Docker** → Usuarios: Red de administración (`10.0.0.0/8`)
- **Docker Engine** → NFS (almacenamiento): Red de clúster (`192.168.10.0/24`)
- **DRBD replicación**: Red de clúster (`192.168.10.0/24`)
- **Pacemaker heartbeat**: Red de clúster (`192.168.10.0/24`)

## Diagrama técnico de arquitectura DRBD

El siguiente diagrama muestra el flujo de datos técnico a nivel de sistema entre los componentes DRBD:

```mermaid
graph TD
    %% Nodo izquierdo (activo)
    subgraph Computer1["Node1 (Active) - 10.0.0.231 | 192.168.10.231"]
        App1["Any Application"]
        FS1["File System"]
        BC1["Buffer Cache"]
        VBD1["DRBD Virtual Block Device"]
        DRBD1["DRBD"]
        DS1["Disk Sched"]
        DD1["Disk Driver"]
        ND1A["NIC Driver (Admin)<br/>ens18"]
        ND1C["NIC Driver (Cluster)<br/>ens19"]
        Storage1["Storage"]
        NIC1A["NIC Admin<br/>10.0.0.231"]
        NIC1C["NIC Cluster<br/>192.168.10.231"]
    end
    
    %% Nodo derecho (standby)
    subgraph Computer2["Node2 (Standby) - 10.0.0.232 | 192.168.10.232"]
        App2["Any Application"]
        FS2["File System"]
        BC2["Buffer Cache"]
        VBD2["DRBD Virtual Block Device"]
        DRBD2["DRBD"]
        DS2["Disk Sched"]
        DD2["Disk Driver"]
        ND2A["NIC Driver (Admin)<br/>ens18"]
        ND2C["NIC Driver (Cluster)<br/>ens19"]
        Storage2["Storage"]
        NIC2A["NIC Admin<br/>10.0.0.232"]
        NIC2C["NIC Cluster<br/>192.168.10.232"]
    end
    
    %% Conexiones del nodo activo
    App1 --> FS1
    FS1 --> BC1
    BC1 --> VBD1
    VBD1 --> DRBD1
    DRBD1 --> DS1
    DS1 --> DD1
    DD1 --> Storage1
    DRBD1 --> ND1A
    DRBD1 --> ND1C
    ND1A --> NIC1A
    ND1C --> NIC1C
    
    %% Conexiones del nodo standby (líneas punteadas)
    App2 -.-> FS2
    FS2 -.-> BC2
    BC2 -.-> VBD2
    VBD2 -.-> DRBD2
    DRBD2 -.-> DS2
    DS2 -.-> DD2
    DD2 -.-> Storage2
    DRBD2 -.-> ND2A
    DRBD2 -.-> ND2C
    ND2A -.-> NIC2A
    ND2C -.-> NIC2C
    
    %% Conexión de red entre nodos DRBD (solo por interfaz de clúster)
    NIC1C <--> NIC2C
    NIC1A <-.-> NIC2A
    
    %% Estilos
    classDef activeNode fill:#f9f9f9,stroke:#333,stroke-width:2px
    classDef standbyNode fill:#f9f9f9,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5
    classDef drbdComponent fill:#ffa500,stroke:#333,stroke-width:2px
    classDef storage fill:#e1e1e1,stroke:#333,stroke-width:2px
    classDef network fill:#e1e1e1,stroke:#333,stroke-width:2px
    
    %% Aplicar estilos
    class DRBD1,DRBD2 drbdComponent
    class Storage1,Storage2 storage
    class NIC1A,NIC1C,NIC2A,NIC2C network
    class App1,FS1,BC1,VBD1,DS1,DD1,ND1A,ND1C activeNode
    class App2,FS2,BC2,VBD2,DS2,DD2,ND2A,ND2C standbyNode
```

### Componentes técnicos:

1. **Any Application**: Aplicaciones que utilizan el almacenamiento
2. **File System**: Sistema de archivos
3. **Buffer Cache**: Caché de búfer del sistema
4. **DRBD Virtual Block Device**: Dispositivo de bloque virtual de DRBD
5. **DRBD**: Núcleo de replicación distribuida
6. **Disk Sched**: Planificador de disco
7. **Disk Driver**: Controlador de disco
8. **NIC Driver**: Controlador de interfaz de red
9. **Storage**: Almacenamiento físico
10. **NIC**: Interfaz de red

### Flujo de datos técnico:

- **Líneas sólidas**: Rutas de datos activas
- **Líneas punteadas**: Rutas de datos inactivas (nodo standby)
- **TCP/IP o RDMA**: Protocolo de comunicación entre nodos DRBD

La replicación se realiza a nivel de bloque, sincronizando automáticamente los datos entre ambos nodos para garantizar alta disponibilidad.

## Consideraciones de seguridad

- Configurar iptables/firewalld para tráfico del clúster
- Usar autenticación con llaves SSH para acceso a nodos
- Implementar monitoreo de red para detección de intrusos
- Configuración regular de respaldos del almacenamiento DRBD
- Asegurar exportaciones NFS con controles de acceso apropiados

---

*Esta arquitectura proporciona una base robusta para cargas de trabajo en contenedores que requieren almacenamiento persistente y altamente disponible.*
