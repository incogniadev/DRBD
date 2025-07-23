#!/bin/bash
# create-drbd-vms.sh
# Script para crear las VMs del laboratorio DRBD en Proxmox
# 
# Autor: Rodrigo Álvarez (@incogniadev)
# Fecha: 2025-07-23

set -e

# Variables de configuración
# ISO con preseed para instalación completamente automatizada (default)
ISO_PATH="local:iso/debian-12.11.0-amd64-preseed.iso"
STORAGE="local-lvm"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar si estamos ejecutando en Proxmox
if ! command -v qm &> /dev/null; then
    error "Este script debe ejecutarse en un host Proxmox con acceso al comando 'qm'"
    exit 1
fi

# Verificar si las VMs ya existen
check_existing_vms() {
    local vm_exists=false
    for vm_id in 231 232 233; do
        if qm status $vm_id &> /dev/null; then
            warn "VM $vm_id ya existe"
            vm_exists=true
        fi
    done
    
    if [ "$vm_exists" = true ]; then
        echo
        echo -e "${YELLOW}¿Deseas continuar? Las VMs existentes serán omitidas. (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Operación cancelada por el usuario"
            exit 0
        fi
    fi
}

# Crear VM individual
create_vm() {
    local vm_id=$1
    local vm_name=$2
    local memory=$3
    local scsi0_size=$4
    local scsi1_size=$5
    
    log "Creando VM $vm_id ($vm_name)..."
    
    if qm status $vm_id &> /dev/null; then
        warn "VM $vm_id ya existe, omitiendo..."
        return 0
    fi
    
    local cmd="qm create $vm_id \
        --name \"$vm_name\" \
        --memory $memory \
        --cores 2 \
        --sockets 1 \
        --cpu host \
        --ostype l26 \
        --machine q35 \
        --scsihw virtio-scsi-pci \
        --bootdisk scsi0 \
        --scsi0 ${STORAGE}:${scsi0_size},format=raw"
    
    # Añadir segundo disco solo para nodos DRBD
    if [ -n "$scsi1_size" ]; then
        cmd+=" --scsi1 ${STORAGE}:${scsi1_size},format=raw"
    fi
    
    cmd+=" --efidisk0 ${STORAGE}:1,format=raw \
        --net0 virtio,bridge=vmbr2 \
        --net1 virtio,bridge=vmbr2 \
        --agent 1 \
        --bios ovmf \
        --onboot 1 \
        --cdrom ${ISO_PATH} \
        --boot order=scsi0"
    
    if eval $cmd; then
        log "VM $vm_id creada exitosamente"
    else
        error "Error al crear VM $vm_id"
        return 1
    fi
}

# Mostrar advertencias importantes
show_warnings() {
    echo
    echo -e "${RED}⚠️  ADVERTENCIAS IMPORTANTES:${NC}"
    echo
    echo -e "${YELLOW}1. INSTALACIÓN ESCALONADA RECOMENDADA:${NC}"
    echo "   Para evitar colisiones durante la instalación automatizada,"
    echo "   se recomienda iniciar las VMs de forma escalonada:"
    echo
    echo -e "${BLUE}   • Paso 1: qm start 231${NC} (Node1 - esperar ~10 min)"
    echo -e "${BLUE}   • Paso 2: qm start 232${NC} (Node2 - cuando Node1 esté listo)"
    echo -e "${BLUE}   • Paso 3: qm start 233${NC} (Node3 - cuando Node2 esté listo)"
    echo
    echo -e "${YELLOW}2. CONFIGURACIÓN POST-INSTALACIÓN MANUAL:${NC}"
    echo "   Aunque la instalación es desatendida, CADA VM requiere"
    echo "   configuración manual de IP y hostname:"
    echo
    echo -e "${BLUE}   • Conectar: ssh incognia@10.0.0.69${NC}"
    echo -e "${BLUE}   • Ejecutar: sudo ./config-network.sh${NC}"
    echo
    echo -e "${YELLOW}3. MONITOREO DEL PROGRESO:${NC}"
    echo -e "${BLUE}   • VNC Node1: qm vncproxy 231${NC}"
    echo -e "${BLUE}   • VNC Node2: qm vncproxy 232${NC}"
    echo -e "${BLUE}   • VNC Node3: qm vncproxy 233${NC}"
    echo
}

# Mostrar opciones de inicio
show_start_options() {
    echo -e "${GREEN}📋 OPCIONES DE INICIO:${NC}"
    echo
    echo -e "${BLUE}🔄 Instalación escalonada (RECOMENDADO):${NC}"
    echo "   qm start 231  # Iniciar Node1 primero"
    echo "   # Esperar ~10 minutos hasta que complete la instalación"
    echo "   qm start 232  # Iniciar Node2 cuando Node1 esté listo"
    echo "   # Esperar ~10 minutos hasta que complete la instalación"
    echo "   qm start 233  # Iniciar Node3 cuando Node2 esté listo"
    echo
    echo -e "${YELLOW}⚡ Inicio simultáneo (solo para instalación manual):${NC}"
    echo "   qm start 231 && qm start 232 && qm start 233"
    echo "   # ⚠️  NO recomendado con ISO preseed"
    echo
}

# Main execution
main() {
    log "Iniciando creación de VMs para laboratorio DRBD"
    echo
    info "Configuración:"
    info "  - ISO: $ISO_PATH"
    info "  - Storage: $STORAGE"
    info "  - VMs a crear: 231 (node1-drbd), 232 (node2-drbd), 233 (node3-docker)"
    echo
    
    # Verificar VMs existentes
    check_existing_vms
    
    # Crear las VMs
    echo
    log "=== CREACIÓN DE VMs ==="
    
    # Node1 - DRBD Primario
    create_vm 231 "node1-drbd" 4096 24 16
    
    # Node2 - DRBD Secundario  
    create_vm 232 "node2-drbd" 4096 24 16
    
    # Node3 - Docker Host
    create_vm 233 "node3-docker" 4096 32
    
    echo
    log "=== RESUMEN DE CREACIÓN ==="
    
    # Mostrar estado de las VMs
    echo
    info "Estado actual de las VMs:"
    qm list | grep -E "(VMID|231|232|233)" || true
    
    # Mostrar advertencias y opciones
    show_warnings
    show_start_options
    
    echo
    log "✅ Configuración de VMs completada exitosamente"
    echo
    echo -e "${GREEN}📚 Documentación adicional:${NC}"
    echo "  • Instalación automatizada: debian/README.md"
    echo "  • Configuración post-instalación: docs/PROXMOX_DEBIAN.md"
    echo "  • Configuración DRBD: docs/INSTALLATION.md"
    echo
}

# Verificar argumentos
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Script para crear VMs del laboratorio DRBD en Proxmox"
    echo
    echo "🚀 CONFIGURACIÓN POR DEFECTO (sin parámetros necesarios):"
    echo "  - ISO: debian-12.11.0-amd64-preseed.iso (instalación completamente automatizada)"
    echo "  - Storage: local-lvm"
    echo "  - VMs: 231 (node1-drbd), 232 (node2-drbd), 233 (node3-docker)"
    echo
    echo "Uso: $0 [opciones]"
    echo
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  --storage PATH Especificar storage alternativo (default: local-lvm)"
    echo "  --iso PATH     Especificar ISO alternativa (default: preseed automatizada)"
    echo
    echo "Ejemplos:"
    echo "  $0                           # Usar configuración por defecto (recomendado)"
    echo "  $0 --storage local-zfs       # Solo cambiar storage"
    echo "  $0 --iso local:iso/custom.iso # Solo cambiar ISO"
    exit 0
fi

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --storage)
            STORAGE="$2"
            shift 2
            ;;
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        *)
            error "Argumento desconocido: $1"
            echo "Use --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# Ejecutar función principal
main

exit 0
