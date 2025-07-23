# Diagrama de arquitectura DRBD

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

## Descripción

Este diagrama muestra la arquitectura DRBD (Distributed Replicated Block Device) con dos nodos:

- **Nodo Activo (izquierda)**: Maneja activamente las aplicaciones y el almacenamiento
- **Nodo Standby (derecha)**: Mantiene una réplica sincronizada pero no está activo

### Componentes principales:

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

### Flujo de datos:

- **Líneas sólidas**: Rutas de datos activas
- **Líneas punteadas**: Rutas de datos inactivas (nodo standby)
- **TCP/IP o RDMA**: Protocolo de comunicación entre nodos DRBD

La replicación se realiza a nivel de bloque, sincronizando automáticamente los datos entre ambos nodos para garantizar alta disponibilidad.
