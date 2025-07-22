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
- 2025-07-22: Actualizada configuración de VMs para usar machine type Q35 en lugar del predeterminado i440fx
- 2025-07-22: Cambiada imagen ISO de instalación de debian-12.11.0-amd64-netinst.iso a debian-12.11.0-amd64-preseed.iso
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
- 2025-07-21: Actualizadas especificaciones de disco en VMs: Nodos DRBD a 24GB/16GB y Node Docker a 32GB
- 2025-07-21: Actualizados IDs de máquinas virtuales para coincidir con último octeto de IP (231, 232, 233)
- 2025-07-21: Configurada doble interfaz de red usando bridge vmbr2 para administración y clúster
- 2025-07-21: Añadido soporte completo para UEFI con disco EFI y QEMU Agent en todas las VMs
- 2025-07-21: Actualizada documentación para usar Debian 12.11 en lugar de versiones anteriores
- 2025-07-21: Actualizada imagen ISO de instalación a debian-12.11.0-amd64-netinst.iso en toda la documentación
- 2025-07-21: Corregido formato de comandos qm create en PROXMOX_VM_CREATION.md para evitar errores de ejecución
- 2025-07-21: Reescrito comandos qm create en formato de una sola línea para mayor compatibilidad y evitar errores de continuación de línea
- 2025-07-21: Refactorizado completamente PROXMOX_DEBIAN.md enfocándolo en configuración post-instalación
- 2025-07-21: Eliminada información redundante y desactualizada de PROXMOX_DEBIAN.md
- 2025-07-21: Actualizadas especificaciones y scripts de automatización en PROXMOX_DEBIAN.md
- 2025-07-21: Añadida configuración específica de red dual y optimizaciones para entorno virtualizado
- 2025-07-21: Corregida configuración inicial en PROXMOX_DEBIAN.md: instalación de sudo y configuración de usuario incognia
- 2025-07-21: Añadida sección de configuración de usuario administrador post-instalación
- 2025-07-21: Corregido formato de comandos qm create en PROXMOX_VM_CREATION.md para evitar errores de ejecución
- 2025-07-21: Actualizadas especificaciones de disco en VMs: Nodos DRBD a 24GB/16GB y Node Docker a 32GB
- 2025-07-21: Actualizados IDs de máquinas virtuales para coincidir con último octeto de IP (231, 232, 233)
- 2025-07-21: Configurada doble interfaz de red usando bridge vmbr2 para administración y clúster
- 2025-07-21: Añadido soporte completo para UEFI con disco EFI y QEMU Agent en todas las VMs

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
