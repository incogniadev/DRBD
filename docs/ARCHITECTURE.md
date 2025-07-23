# Arquitectura de alta disponibilidad DRBD

## Descripción general

Este documento describe una solución de almacenamiento de alta disponibilidad utilizando DRBD (Distributed Replicated Block Device) con gestión de clúster Pacemaker y servicios NFS para cargas de trabajo en contenedores.

## Arquitectura del sistema

```mermaid
graph TB
    subgraph "Capa de almacenamiento"
        subgraph N1 ["Nodo 1 (Primario)"]
            A1["/dev/sdb1<br/>Dispositivo físico"]
            A2["/dev/drbd0<br/>DRBD primario"]
            A3["/mnt/docker-vol<br/>Sistema de archivos montado"]
            A3a["Imágenes Docker<br/>y datos de contenedores"]
            A4["Servidor NFS<br/>(Activo)"]
            A5["192.168.10.230<br/>IP flotante"]
        end
        
        subgraph N2 ["Nodo 2 (Secundario)"]
            B1["/dev/sdb1<br/>Dispositivo físico"]
            B2["/dev/drbd0<br/>DRBD secundario"]
            B3["/mnt/docker-vol<br/>Desmontado"]
            B3a["Imágenes Docker<br/>y datos de contenedores<br/>(Réplica)"]
            B4["Servidor NFS<br/>(En espera)"]
            B5["Agente Pacemaker<br/>(En espera)"]
        end
    end
    
    subgraph "Gestión del clúster"
        C1["Clúster Pacemaker"]
        C2["Monitor de recursos"]
        C3["Controlador de failover"]
        C4["Gestor de IP"]
    end
    
    subgraph "Capa de aplicación"
        D1["Host Docker<br/>Nodo 3"]
        D2["Cliente NFS"]
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
    
    %% Acceso de aplicación
    D1 --> D2
    D2 -->|"Montaje NFS"| A5
    D2 --> D3
    D2 --> D4
    D2 --> D5
    
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
- **Cliente NFS**: Se conecta al servicio NFS vía IP flotante
- **Almacenamiento de contenedores**: Imágenes y contenedores almacenados en NFS
- **Configuración de red**:
  - **IP primaria**: `10.0.0.233/8` - Red de administración
  - **IP secundaria**: `192.168.10.233/24` - Red del clúster
  - **Acceso NFS**: Se conecta a la IP flotante `192.168.10.230/24`

## Principios clave de diseño

### Arquitectura de almacenamiento Docker
**TODAS las imágenes y contenedores Docker DEBEN almacenarse en el almacenamiento montado por NFS proporcionado por el clúster DRBD.**

#### Componentes de almacenamiento
- **Imágenes Docker**: Almacenadas en `/mnt/docker-vol/docker/images/` en NFS
- **Datos de contenedores**: Todos los volúmenes de contenedores y datos persistentes en NFS
- **Daemon Docker**: Configurado para usar directorios montados en NFS para:
  - Almacenamiento de imágenes
  - Datos de tiempo de ejecución de contenedores
  - Montajes de volúmenes
  - Caché de construcción

#### Rol del host Docker
- **Solo ejecución**: El servidor Docker (Nodo 3) sirve únicamente como motor de ejecución
- **Sin almacenamiento local**: No hay imágenes o datos persistentes almacenados localmente
- **Dependencia de NFS**: Dependencia completa de NFS para todas las operaciones Docker
- **Operación sin estado**: Puede ser reemplazado o reconstruido sin pérdida de datos

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

### Beneficios del almacenamiento centralizado NFS
1. **Alta disponibilidad**: Las imágenes y contenedores sobreviven a fallas del host Docker
2. **Consistencia**: Las mismas imágenes disponibles en múltiples hosts Docker
3. **Simplicidad de respaldos**: Ubicación única de almacenamiento para todos los datos Docker
4. **Escalabilidad**: Fácil agregar más hosts de ejecución Docker
5. **Recuperación ante desastres**: Restauración completa del entorno Docker desde la réplica DRBD

## Configuración de red

### Esquema de direcciones IP

**⚠️ Nota importante:** Durante la instalación automatizada, todas las VMs usan temporalmente la IP `10.0.0.69/8` y deben ser reconfiguradas individualmente después de la instalación.

#### Red de producción (configuración final):
- **Nodo 1 (DRBD primario)**:
  - IP principal: `192.168.10.231/24`
  - Hostname: `node1`
- **Nodo 2 (DRBD secundario)**:
  - IP principal: `192.168.10.232/24`
  - Hostname: `node2`
- **Nodo 3 (Host Docker)**:
  - IP principal: `192.168.10.233/24`
  - Hostname: `node3-docker`
- **IP flotante**: `192.168.10.230/24` (IP virtual para HA)
- **Gateway**: `192.168.10.1`
- **DNS**: `8.8.8.8, 8.8.4.4`

#### Red temporal (durante instalación):
- **IP temporal**: `10.0.0.69/8` (todas las VMs durante instalación preseed)
- **Gateway temporal**: `10.0.0.1`
- **Hostname temporal**: `preseed`

### Requisitos de red
- **Baja latencia**: <1ms idealmente entre nodos DRBD
- **Red dedicada**: Red separada para comunicación del clúster
- **Ancho de banda**: Suficiente para transferencias de imágenes Docker y datos de contenedores

## Diagrama técnico de arquitectura DRBD

El siguiente diagrama muestra el flujo de datos técnico a nivel de sistema entre los componentes DRBD:

```mermaid
graph TD
    %% Nodo izquierdo (activo)
    subgraph Computer1["Computer (Active)"]
        App1["Any Application"]
        FS1["File System"]
        BC1["Buffer Cache"]
        VBD1["DRBD Virtual Block Device"]
        DRBD1["DRBD"]
        DS1["Disk Sched"]
        DD1["Disk Driver"]
        ND1["NIC Driver"]
        Storage1["Storage"]
        NIC1["NIC"]
    end
    
    %% Nodo derecho (standby)
    subgraph Computer2["Computer (Standby)"]
        App2["Any Application"]
        FS2["File System"]
        BC2["Buffer Cache"]
        VBD2["DRBD Virtual Block Device"]
        DRBD2["DRBD"]
        DS2["Disk Sched"]
        DD2["Disk Driver"]
        ND2["NIC Driver"]
        Storage2["Storage"]
        NIC2["NIC"]
    end
    
    %% Conexiones del nodo activo
    App1 --> FS1
    FS1 --> BC1
    BC1 --> VBD1
    VBD1 --> DRBD1
    DRBD1 --> DS1
    DS1 --> DD1
    DD1 --> Storage1
    DRBD1 --> ND1
    ND1 --> NIC1
    
    %% Conexiones del nodo standby (líneas punteadas)
    App2 -.-> FS2
    FS2 -.-> BC2
    BC2 -.-> VBD2
    VBD2 -.-> DRBD2
    DRBD2 -.-> DS2
    DS2 -.-> DD2
    DD2 -.-> Storage2
    DRBD2 -.-> ND2
    ND2 -.-> NIC2
    
    %% Conexión de red entre nodos DRBD
    NIC1 <--> NIC2
    
    %% Estilos
    classDef activeNode fill:#f9f9f9,stroke:#333,stroke-width:2px
    classDef standbyNode fill:#f9f9f9,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5
    classDef drbdComponent fill:#ffa500,stroke:#333,stroke-width:2px
    classDef storage fill:#e1e1e1,stroke:#333,stroke-width:2px
    classDef network fill:#e1e1e1,stroke:#333,stroke-width:2px
    
    %% Aplicar estilos
    class DRBD1,DRBD2 drbdComponent
    class Storage1,Storage2 storage
    class NIC1,NIC2 network
    class App1,FS1,BC1,VBD1,DS1,DD1,ND1 activeNode
    class App2,FS2,BC2,VBD2,DS2,DD2,ND2 standbyNode
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
