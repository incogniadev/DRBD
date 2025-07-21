# Registro de cambios

Todos los cambios notables de este proyecto se documentarán en este archivo.

## [No publicado]

### Añadido
- 2025-07-21: Creado directorio docs/ dedicado para la documentación organizada
- 2025-07-21: Añadido ARCHITECTURE.md detallado con el diseño del sistema
- 2025-07-21: Añadida guía general INSTALLATION.md para todas las distribuciones de Linux
- 2025-07-21: Creada guía específica PROXMOX_DEBIAN.md para la plataforma
- 2025-07-21: Traducción completa de toda la documentación al español mexicano
- 2025-07-21: Añadida guía completa PROXMOX_VM_CREATION.md para crear VMs desde shell de Proxmox
- 2025-07-21: Script de automatización para creación masiva de VMs del laboratorio DRBD
- 2025-07-21: Configuración específica para red vmbr2 en todas las VMs
- 2025-07-21: Comandos de gestión y monitoreo de VMs en Proxmox

### Cambiado
- 2025-07-21: Refactorizado README.md para enfocarse en el resumen del proyecto y el inicio rápido
- 2025-07-21: Mejorada la navegación en la documentación con enlaces estructurados de guías
- 2025-07-21: Mejorado README.md con tablas visuales y organización con emojis
- 2025-07-21: Actualizada la dirección IP flotante de 192.168.10.100 a 192.168.10.230 en todas las documentaciones y ejemplos de configuración
- 2025-07-21: Añadida configuración de red específica para el host Docker (Nodo 3) con configuración de IP dual:
  - IP primaria: 10.0.0.233/8 (red de administración)
  - IP secundaria: 192.168.10.233/24 (red del clúster)
- 2025-07-21: Añadido ejemplo de configuración de Netplan para la configuración de red de Node 3
- 2025-07-21: Actualizadas todas las referencias de montaje NFS para usar la nueva IP flotante 192.168.10.230
- 2025-07-21: Actualizado PROXMOX_DEBIAN_NOTES.md con nuevas configuraciones de IP y configuración de red específica de Node3 Docker

### Eliminado
- 2025-07-21: Eliminado archivo redundante OVERVIEW.md (contenido movido a docs/ARCHITECTURE.md)
- 2025-07-21: Movido PROXMOX_DEBIAN_NOTES.md a docs/PROXMOX_DEBIAN.md
- 2025-07-21: Eliminados diagramas de arquitectura duplicados en varios archivos
- 2025-07-21: Eliminadas instrucciones de instalación de README.md (movidas a guías dedicadas)

### Corregido
- 2025-07-21: Corregido marcador de fecha en la sección de autor de PROXMOX_DEBIAN_NOTES.md
- 2025-07-21: Resuelta información redundante dispersa en varios archivos
- 2025-07-21: Mejorada la consistencia del idioma en toda la documentación
- 2025-07-21: Traducidos todos los títulos, secciones y contenido a español mexicano
- 2025-07-21: Corregidos problemas de codificación de caracteres en archivos
- 2025-07-21: Actualizados diagramas Mermaid con etiquetas en español
- 2025-07-21: Mantenidos comandos técnicos y rutas en formato original

## [Lanzamiento inicial]

### Añadido
- Documentación de arquitectura de almacenamiento de alta disponibilidad DRBD inicial
- Notas de implementación con Proxmox y Debian
- Guías completas de instalación y configuración
- Diagramas Mermaid para la arquitectura del sistema
- Procedimientos de resolución de problemas y mantenimiento
