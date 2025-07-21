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
- **Nodo 1 (DRBD primario)**:
  - Administración: `10.0.0.231/8`
  - Clúster: `192.168.10.231/24`
- **Nodo 2 (DRBD secundario)**:
  - Administración: `10.0.0.232/8`
  - Clúster: `192.168.10.232/24`
- **Nodo 3 (Host Docker)**:
  - Administración: `10.0.0.233/8`
  - Clúster: `192.168.10.233/24`
- **IP flotante**: `192.168.10.230/24` (IP virtual para HA)

### Requisitos de red
- **Baja latencia**: <1ms idealmente entre nodos DRBD
- **Red dedicada**: Red separada para comunicación del clúster
- **Ancho de banda**: Suficiente para transferencias de imágenes Docker y datos de contenedores

## Consideraciones de seguridad

- Configurar iptables/firewalld para tráfico del clúster
- Usar autenticación con llaves SSH para acceso a nodos
- Implementar monitoreo de red para detección de intrusos
- Configuración regular de respaldos del almacenamiento DRBD
- Asegurar exportaciones NFS con controles de acceso apropiados

---

*Esta arquitectura proporciona una base robusta para cargas de trabajo en contenedores que requieren almacenamiento persistente y altamente disponible.*
