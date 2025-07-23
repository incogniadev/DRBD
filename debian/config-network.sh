#!/bin/bash

# Script de configuración de red post-instalación
# Autor: Rodrigo Álvarez (@incognia)
# Descripción: Permite cambiar la IP estática y hostname después del primer arranque

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Configuración de Red - Debian Preseed    ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Verificar si se ejecuta como root (necesario para modificar configuraciones del sistema)
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}⚠ ADVERTENCIA: Este script requiere permisos de administrador.${NC}"
   echo -e "${YELLOW}Ejecuta: sudo ./config-network.sh${NC}"
   exit 1
fi

# Función para validar IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Función para validar CIDR
validate_cidr() {
    local cidr=$1
    if [[ $cidr =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/([0-9]{1,2})$ ]]; then
        local ip=${BASH_REMATCH[1]}
        local prefix=${BASH_REMATCH[2]}
        
        # Validar IP
        if ! validate_ip "$ip"; then
            return 1
        fi
        
        # Validar prefijo (0-32)
        if [[ $prefix -lt 0 || $prefix -gt 32 ]]; then
            return 1
        fi
        
        return 0
    else
        return 1
    fi
}

# Función para convertir CIDR a máscara de subred
cidr_to_netmask() {
    local prefix=$1
    local mask_parts=()
    local full_octets=$((prefix / 8))
    local partial_octet=$((prefix % 8))
    
    # Octetos completos (255)
    for ((i = 0; i < full_octets; i++)); do
        mask_parts+=('255')
    done
    
    # Octeto parcial
    if [[ $partial_octet -gt 0 && ${#mask_parts[@]} -lt 4 ]]; then
        local partial_value=$((256 - 2**(8 - partial_octet)))
        mask_parts+=("$partial_value")
    fi
    
    # Completar con ceros
    while [[ ${#mask_parts[@]} -lt 4 ]]; do
        mask_parts+=('0')
    done
    
    # Unir con puntos
    local IFS='.'
    echo "${mask_parts[*]}"
}

# Función para calcular la dirección de red
get_network_address() {
    local ip=$1
    local prefix=$2
    
    IFS='.' read -ra IP_PARTS <<< "$ip"
    local netmask=$(cidr_to_netmask $prefix)
    IFS='.' read -ra MASK_PARTS <<< "$netmask"
    
    local network=""
    for i in {0..3}; do
        local net_octet=$((IP_PARTS[i] & MASK_PARTS[i]))
        network+="$net_octet"
        if [[ $i -lt 3 ]]; then
            network+="."
        fi
    done
    
    echo "$network"
}

# Función para inferir gateway (primera IP de la red)
infer_gateway() {
    local ip=$1
    local prefix=$2
    
    local network=$(get_network_address "$ip" "$prefix")
    IFS='.' read -ra NET_PARTS <<< "$network"
    
    # Gateway típicamente es la primera IP útil (network + 1)
    local gateway="${NET_PARTS[0]}.${NET_PARTS[1]}.${NET_PARTS[2]}.$((NET_PARTS[3] + 1))"
    echo "$gateway"
}

# Función para validar hostname
validate_hostname() {
    local hostname=$1
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Mostrar configuración actual
echo -e "${YELLOW}Configuración actual:${NC}"
echo "IP actual: $(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+')"
echo "Hostname actual: $(hostname)"
echo "FQDN actual: $(hostname -f)"
echo ""

# Solicitar nueva IP y prefijo CIDR
while true; do
    read -p "Nueva IP estática con prefijo CIDR (formato: 192.168.1.100/24): " NEW_CIDR
    if validate_cidr "$NEW_CIDR"; then
        NEW_IP=$(echo $NEW_CIDR | cut -d'/' -f1)
        NEW_PREFIX=$(echo $NEW_CIDR | cut -d'/' -f2)
        break
    else
        echo -e "${RED}Formato inválido. Usa: xxx.xxx.xxx.xxx/yy${NC}"
    fi
done

# Calcular máscara de red
NEW_NETMASK=$(cidr_to_netmask $NEW_PREFIX)

# Inferir gateway y permitir corrección
SUGGESTED_GATEWAY=$(infer_gateway $NEW_IP $NEW_PREFIX)
read -p "Gateway (presiona Enter para usar $SUGGESTED_GATEWAY): " NEW_GATEWAY
if [ -z "$NEW_GATEWAY" ]; then
    NEW_GATEWAY=$SUGGESTED_GATEWAY
fi

if ! validate_ip "$NEW_GATEWAY"; then
    echo -e "${RED}Gateway inválido, usando el sugerido: $SUGGESTED_GATEWAY${NC}"
    NEW_GATEWAY=$SUGGESTED_GATEWAY
fi

# Solicitar nuevo hostname
while true; do
    read -p "Nuevo hostname (ej: servidor01): " NEW_HOSTNAME
    if validate_hostname "$NEW_HOSTNAME"; then
        break
    else
        echo -e "${RED}Hostname inválido. Solo letras, números y guiones.${NC}"
    fi
done

# Solicitar dominio
read -p "Dominio (presiona Enter para usar faraday.org.mx): " NEW_DOMAIN
if [ -z "$NEW_DOMAIN" ]; then
    NEW_DOMAIN="faraday.org.mx"
fi

# Configuración de interfaz secundaria
echo ""
echo -e "${BLUE}Configuración de interfaz secundaria (opcional):${NC}"
read -p "¿Deseas configurar una segunda interfaz de red? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    # Solicitar IP para interfaz secundaria
    while true; do
        read -p "IP secundaria con prefijo CIDR (formato: 192.168.10.100/24): " SECONDARY_CIDR
        if validate_cidr "$SECONDARY_CIDR"; then
            SECONDARY_IP=$(echo $SECONDARY_CIDR | cut -d'/' -f1)
            SECONDARY_PREFIX=$(echo $SECONDARY_CIDR | cut -d'/' -f2)
            break
        else
            echo -e "${RED}Formato inválido. Usa: xxx.xxx.xxx.xxx/yy${NC}"
        fi
    done
    
    # Calcular máscara de red para interfaz secundaria
    SECONDARY_NETMASK=$(cidr_to_netmask $SECONDARY_PREFIX)
    
    # Detectar interfaz de red principal primero (si no se ha hecho)
    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(ip route | grep default | head -1 | sed 's/.*dev \([^ ]*\).*/\1/')
    fi
    
    # Detectar segunda interfaz disponible
    SECONDARY_INTERFACE=$(ip link show | grep -E '^[0-9]+: e' | grep -v "$INTERFACE" | head -1 | cut -d: -f2 | tr -d ' ')
    if [ -z "$SECONDARY_INTERFACE" ]; then
        # Asumir ens19 como interfaz secundaria típica en VMs
        SECONDARY_INTERFACE="ens19"
        echo -e "${YELLOW}⚠${NC} Usando interfaz predeterminada: $SECONDARY_INTERFACE"
    else
        echo -e "${GREEN}✓${NC} Interfaz secundaria detectada: $SECONDARY_INTERFACE"
    fi
    
    CONFIGURE_SECONDARY=true
else
    CONFIGURE_SECONDARY=false
fi

# Mostrar resumen
echo ""
echo -e "${YELLOW}Resumen de cambios:${NC}"
echo "Nueva IP: $NEW_IP"
echo "Gateway: $NEW_GATEWAY" 
echo "Máscara: $NEW_NETMASK"
echo "Nuevo hostname: $NEW_HOSTNAME"
echo "Dominio: $NEW_DOMAIN"
echo "FQDN: $NEW_HOSTNAME.$NEW_DOMAIN"
if [ "$CONFIGURE_SECONDARY" = true ]; then
    echo "IP secundaria: $SECONDARY_IP"
    echo "Máscara secundaria: $SECONDARY_NETMASK"
    echo "Interfaz secundaria: $SECONDARY_INTERFACE"
fi
echo ""

# Confirmar cambios
read -p "¿Aplicar estos cambios? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Configuración cancelada.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Aplicando configuración...${NC}"

# Crear archivo de respaldo
BACKUP_DIR="/home/$(whoami)/network-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Respaldar archivos actuales
cp /etc/network/interfaces "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/hostname "$BACKUP_DIR/"
cp /etc/hosts "$BACKUP_DIR/"

echo -e "${GREEN}✓${NC} Archivos respaldados en: $BACKUP_DIR"

# Actualizar hostname
echo "$NEW_HOSTNAME" | tee /etc/hostname > /dev/null
hostnamectl set-hostname "$NEW_HOSTNAME"
echo -e "${GREEN}✓${NC} Hostname actualizado"

# Actualizar /etc/hosts
tee /etc/hosts > /dev/null << EOF
127.0.0.1	localhost
127.0.1.1	$NEW_HOSTNAME.$NEW_DOMAIN	$NEW_HOSTNAME
$NEW_IP	$NEW_HOSTNAME.$NEW_DOMAIN	$NEW_HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
echo -e "${GREEN}✓${NC} Archivo /etc/hosts actualizado"

# Detectar interfaz de red principal
INTERFACE=$(ip route | grep default | head -1 | sed 's/.*dev \([^ ]*\).*/\1/')

# Crear configuración de /etc/network/interfaces (Debian tradicional)
if [ "$CONFIGURE_SECONDARY" = true ]; then
    # Configuración con interfaz secundaria
    tee /etc/network/interfaces > /dev/null << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $INTERFACE
iface $INTERFACE inet static
    address $NEW_IP
    netmask $NEW_NETMASK
    gateway $NEW_GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4

# The secondary network interface
auto $SECONDARY_INTERFACE
iface $SECONDARY_INTERFACE inet static
    address $SECONDARY_IP
    netmask $SECONDARY_NETMASK
EOF
else
    # Configuración solo con interfaz primaria
    tee /etc/network/interfaces > /dev/null << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $INTERFACE
iface $INTERFACE inet static
    address $NEW_IP
    netmask $NEW_NETMASK
    gateway $NEW_GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4
EOF
fi

echo -e "${GREEN}✓${NC} Configuración de /etc/network/interfaces actualizada"

# Verificar y deshabilitar NetworkManager si está presente
echo -e "${BLUE}Verificando servicios de red conflictivos...${NC}"
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} NetworkManager detectado - deshabilitando para usar networking tradicional"
    systemctl stop NetworkManager
    systemctl disable NetworkManager
    echo -e "${GREEN}✓${NC} NetworkManager deshabilitado"
fi

# Verificar y deshabilitar systemd-networkd si está activo
if systemctl is-active --quiet systemd-networkd 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} systemd-networkd detectado - deshabilitando para usar networking tradicional"
    systemctl stop systemd-networkd
    systemctl disable systemd-networkd
    echo -e "${GREEN}✓${NC} systemd-networkd deshabilitado"
fi

# Habilitar y asegurar que ifupdown esté disponible
systemctl enable networking
echo -e "${GREEN}✓${NC} Servicio networking habilitado"

# Aplicar configuración
echo -e "${BLUE}Aplicando configuración de red...${NC}"

# Desactivar salida inmediata en errores para la sección de red
set +e

# Método 1: Reiniciar el servicio networking
if systemctl restart networking 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Servicio de red reiniciado exitosamente"
    
    # Verificar que la interfaz tenga IP
    sleep 2
    if ip addr show $INTERFACE | grep -q "inet $NEW_IP"; then
        echo -e "${GREEN}✓${NC} IP aplicada correctamente en $INTERFACE"
    else
        echo -e "${YELLOW}⚠${NC} IP no aplicada, intentando métodos alternativos..."
        NETWORK_RESTART_FAILED=true
    fi
else
    NETWORK_RESTART_FAILED=true
fi

# Métodos alternativos si falla el reinicio del servicio
if [ "$NETWORK_RESTART_FAILED" = true ]; then
    echo -e "${YELLOW}⚠${NC} El reinicio automático del servicio falló (normal cuando se cambia IP activa)"
    echo -e "${BLUE}Intentando métodos alternativos...${NC}"
    
    # Método 2: Usar ifdown/ifup (método tradicional Debian)
    echo -e "${BLUE}Intentando ifdown/ifup...${NC}"
    if ifdown $INTERFACE 2>/dev/null && ifup $INTERFACE 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Interfaz reconfigurada con ifdown/ifup"
        
        # Verificar que la IP se aplicó
        sleep 2
        if ip addr show $INTERFACE | grep -q "inet $NEW_IP"; then
            echo -e "${GREEN}✓${NC} Nueva IP aplicada correctamente"
        else
            echo -e "${YELLOW}⚠${NC} IP no aplicada con ifdown/ifup, intentando método manual"
            IFUPDOWN_FAILED=true
        fi
    else
        echo -e "${YELLOW}⚠${NC} ifdown/ifup falló, intentando método manual"
        IFUPDOWN_FAILED=true
    fi
    
    # Método 3: levantar/bajar interfaz manualmente si falla ifupdown
    if [ "$IFUPDOWN_FAILED" = true ]; then
        echo -e "${BLUE}Intentando reinicio manual de interfaz...${NC}"
        if ip link set $INTERFACE down 2>/dev/null && ip link set $INTERFACE up 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Interfaz de red reiniciada manualmente"
        else
            echo -e "${YELLOW}⚠${NC} Reinicio manual de interfaz falló - requerirá reinicio del sistema"
        fi
    fi
    
    # Aplicar configuración IP manualmente
    echo -e "${BLUE}Aplicando configuración IP manualmente...${NC}"
    
    # Limpiar configuración anterior
    ip addr flush dev $INTERFACE 2>/dev/null || true
    ip route del default 2>/dev/null || true
    
    # Aplicar nueva configuración
    if ip addr add $NEW_IP/$NEW_PREFIX dev $INTERFACE 2>/dev/null; then
        echo -e "${GREEN}✓${NC} IP configurada: $NEW_IP/$NEW_PREFIX"
        
        # Configurar gateway
        if ip route add default via $NEW_GATEWAY 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Gateway configurado: $NEW_GATEWAY"
            echo -e "${GREEN}✓${NC} Configuración IP aplicada manualmente"
        else
            echo -e "${YELLOW}⚠${NC} Gateway no configurado - se aplicará tras reinicio"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Configuración IP manual falló - se aplicará tras reinicio"
    fi
fi

# Reactivar salida inmediata en errores
set -e

# Verificar conectividad
echo -e "${BLUE}Verificando conectividad...${NC}"
sleep 2

# Desactivar temporalmente para la verificación de conectividad
set +e
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓${NC} Conectividad verificada"
    CONNECTIVITY_OK=true
else
    echo -e "${YELLOW}⚠${NC} Advertencia: No se pudo verificar conectividad externa"
    echo -e "${BLUE}Esto es normal si la nueva IP requiere configuración de red adicional${NC}"
    CONNECTIVITY_OK=false
fi
set -e

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Configuración aplicada exitosamente!     ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Información importante:${NC}"
echo "• Nueva IP: $NEW_IP"
if [ "$CONFIGURE_SECONDARY" = true ]; then
    echo "• IP secundaria: $SECONDARY_IP"
fi
echo "• Nuevo hostname: $NEW_HOSTNAME.$NEW_DOMAIN"
echo "• Respaldos en: $BACKUP_DIR"
echo "• Reinicia el sistema para asegurar que todos los servicios usen la nueva configuración"
echo ""
echo -e "${BLUE}Para conectarte por SSH usa:${NC}"
echo "ssh $(whoami)@$NEW_IP"
if [ "$CONFIGURE_SECONDARY" = true ]; then
    echo "ssh $(whoami)@$SECONDARY_IP"
fi
echo ""

# Preguntar si desea reiniciar
read -p "¿Reiniciar el sistema ahora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${BLUE}Reiniciando sistema...${NC}"
    reboot
else
    echo -e "${YELLOW}Recuerda reiniciar el sistema más tarde.${NC}"
fi
