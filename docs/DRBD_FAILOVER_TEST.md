# Pruebas de Failover DRBD con WebApp

Esta guía cubre cómo probar la funcionalidad de failover de DRBD con una WebApp activa ejecutándose en Docker con almacenamiento NFS.

## Prerrequisitos

- Clúster DRBD correctamente configurado y ejecutándose
- WebApp Docker desplegada usando almacenamiento NFS
- Ambos nodos en el clúster DRBD operativos
- Acceso SSH a todos los nodos del clúster

## Procedimiento de Pruebas

### 1. Verificación del Estado Inicial

Antes de iniciar la prueba de failover, verifica el estado actual:

```bash
# Verificar estado DRBD
sudo drbdadm status

# Verificar estado del clúster Pacemaker (si aplica)
sudo pcs status

# Verificar estado del servicio NFS
sudo systemctl status nfs-kernel-server

# Verificar que la WebApp es accesible
curl http://192.168.10.233

# Verificar montajes NFS
df -h | grep nfs

# Verificar contenedor Docker
docker ps --filter "name=webapp-drbd"
```

### 2. Documentar Estado Inicial

```bash
# Crear log de prueba
echo "=== PRUEBA DE FAILOVER DRBD - $(date) ===" > /tmp/failover-test.log
echo "Estado inicial del clúster:" >> /tmp/failover-test.log
sudo drbdadm status >> /tmp/failover-test.log
echo "\nNodo primario actual:" >> /tmp/failover-test.log
sudo drbdadm status | grep Primary >> /tmp/failover-test.log
```

### 3. Simular Falla del Nodo Primario

Hay varias formas de simular una falla del nodo:

#### Opción A: Apagado Graceful
```bash
# En el nodo primario
echo "$(date): Iniciando apagado graceful" >> /tmp/failover-test.log
sudo systemctl stop nfs-kernel-server
sudo drbdadm secondary all
sudo shutdown -h now
```

#### Opción B: Desconexión de Red
```bash
# Desconectar interfaz de red (reemplaza ens18 con tu interfaz)
echo "$(date): Desconectando red" >> /tmp/failover-test.log
sudo ip link set ens18 down
```

#### Opción C: Forzar Desconexión DRBD
```bash
# Forzar que DRBD se desconecte del peer
echo "$(date): Forzando desconexión DRBD" >> /tmp/failover-test.log
sudo drbdadm disconnect all
```

#### Opción D: Simulación de Falla Crítica
```bash
# Simular falla crítica del sistema (¡CUIDADO!)
echo "$(date): Simulando falla crítica" >> /tmp/failover-test.log
sudo echo b > /proc/sysrq-trigger
```

### 4. Monitorear Proceso de Failover

En el nodo secundario, monitorea el failover:

```bash
# Monitorear estado del clúster en tiempo real
watch -n 2 "sudo pcs status 2>/dev/null || echo 'Pacemaker no configurado'"

# Monitorear estado DRBD
watch -n 2 "sudo drbdadm status"

# Verificar servicio NFS
sudo systemctl status nfs-kernel-server

# Verificar que los contenedores Docker siguen ejecutándose
docker ps

# Monitorear logs en tiempo real
sudo tail -f /var/log/syslog | grep -E "(drbd|nfs)"
```

### 5. Scripts de Monitoreo Automatizado

```bash
#!/bin/bash
# monitor-failover.sh

LOG_FILE="/tmp/failover-monitor-$(date +%Y%m%d-%H%M%S).log"
WEBAPP_URL="http://192.168.10.233"
INTERVAL=5

echo "Iniciando monitoreo de failover - $(date)" | tee -a $LOG_FILE

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Verificar estado DRBD
    DRBD_STATUS=$(sudo drbdadm status 2>/dev/null | grep -o "Primary\|Secondary")
    echo "[$TIMESTAMP] DRBD Status: $DRBD_STATUS" | tee -a $LOG_FILE
    
    # Verificar WebApp
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $WEBAPP_URL 2>/dev/null || echo "000")
    echo "[$TIMESTAMP] WebApp HTTP: $HTTP_CODE" | tee -a $LOG_FILE
    
    # Verificar NFS
    NFS_STATUS=$(sudo systemctl is-active nfs-kernel-server 2>/dev/null || echo "inactive")
    echo "[$TIMESTAMP] NFS Status: $NFS_STATUS" | tee -a $LOG_FILE
    
    echo "[$TIMESTAMP] ---" | tee -a $LOG_FILE
    sleep $INTERVAL
done
```

### 6. Verificar Continuidad de la WebApp

Durante y después del failover:

```bash
# Probar accesibilidad de WebApp continuamente
while true; do
    if curl -s http://192.168.10.233 > /dev/null; then
        echo "$(date): ✅ WebApp accesible"
    else
        echo "$(date): ❌ WebApp no accesible"
    fi
    sleep 2
done

# Verificar que el montaje NFS sigue activo
df -h | grep nfs

# Verificar integridad de datos
ls -la /mnt/nfs-docker/webapp-data/
cat /mnt/nfs-docker/webapp-data/data.txt

# Verificar logs del contenedor Docker
docker logs webapp-drbd --tail 50
```

### 7. Resultados Esperados

Después de un failover exitoso:

- ✅ El nodo secundario se convierte en primario automáticamente
- ✅ El servicio NFS continúa ejecutándose en el nuevo primario
- ✅ La WebApp permanece accesible sin pérdida de datos
- ✅ Todos los contenedores Docker mantienen su estado
- ✅ Los datos persistentes en NFS permanecen íntegros

### 8. Pruebas de Recuperación

Cuando el nodo fallido vuelve en línea:

```bash
# Verificar estado de sincronización DRBD
sudo drbdadm status

# Monitorear reintegración del clúster
sudo pcs status 2>/dev/null || echo "Pacemaker no configurado"

# Verificar que ambos nodos estén operativos
sudo drbdadm status | grep Connected

# Monitorear sincronización de datos
watch 'cat /proc/drbd'

# Verificar logs de recuperación
sudo journalctl -u drbd --since "10 minutes ago"
```

### 9. Prueba de Failback (Opcional)

Para probar el retorno al nodo original:

```bash
# Promover manualmente el nodo original a primario
sudo drbdadm primary all --force

# O usar Pacemaker para migrar recursos
sudo pcs resource move drbd-master nodo-original

# Verificar que el failback fue exitoso
sudo drbdadm status
curl http://192.168.10.233
```

### 10. Resolución de Problemas

Si el failover no funciona como se esperaba:

```bash
# Verificar logs del sistema
sudo journalctl -u drbd --since "1 hour ago"
sudo journalctl -u nfs-kernel-server --since "1 hour ago"
sudo tail -f /var/log/syslog | grep -E "(drbd|nfs|error)"

# Verificar configuración de recursos
sudo pcs resource show 2>/dev/null || echo "Pacemaker no configurado"

# Verificar configuración DRBD
sudo drbdadm dump all

# Verificar conectividad de red
ping -c 3 nodo-secundario-ip

# Verificar puertos DRBD
sudo netstat -tlnp | grep 7788

# Forzar promoción manual si es necesario
sudo drbdadm primary all --force
sudo systemctl start nfs-kernel-server
sudo exportfs -ra
```

## Criterios de Éxito

Una prueba de failover exitosa debe demostrar:

1. ✅ **Detección automática**: Falla del nodo primario detectada en < 10 segundos
2. ✅ **Promoción rápida**: Nodo secundario promovido a primario en < 30 segundos
3. ✅ **Continuidad NFS**: Servicio NFS continúa sin interrupción
4. ✅ **Disponibilidad WebApp**: WebApp permanece accesible durante el proceso
5. ✅ **Integridad de datos**: Sin pérdida ni corrupción de datos
6. ✅ **Reintegración automática**: Nodo fallido se reintegra automáticamente
7. ✅ **Persistencia Docker**: Contenedores mantienen estado y datos

## Matriz de Pruebas

| Escenario | Tiempo Esperado | Estado | Notas |
|-----------|----------------|--------|-------|
| Apagado graceful | < 30s | ⬜ | Simulación de mantenimiento |
| Falla de red | < 15s | ⬜ | Simulación de partición |
| Falla crítica | < 45s | ⬜ | Simulación de hardware |
| Failback | < 60s | ⬜ | Retorno al nodo original |

## Scripts de Automatización Completa

### Script Principal de Pruebas

```bash
#!/bin/bash
# comprehensive-failover-test.sh

set -e

# Configuración
TEST_LOG="/tmp/failover-comprehensive-$(date +%Y%m%d-%H%M%S).log"
WEBAPP_URL="http://192.168.10.233"
PRIMARY_NODE="192.168.10.231"
SECONDARY_NODE="192.168.10.232"

# Funciones de utilidad
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $TEST_LOG
}

test_webapp() {
    if curl -s -o /dev/null -w "%{http_code}" $WEBAPP_URL | grep -q "200"; then
        log "✅ WebApp accesible"
        return 0
    else
        log "❌ WebApp no accesible"
        return 1
    fi
}

test_drbd_status() {
    local status=$(sudo drbdadm status | grep -o "Primary\|Secondary")
    log "📊 Estado DRBD: $status"
}

# Inicio de pruebas
log "🚀 Iniciando pruebas comprensivas de failover DRBD"
log "📋 WebApp URL: $WEBAPP_URL"
log "🖥️ Nodo Primario: $PRIMARY_NODE"
log "🖥️ Nodo Secundario: $SECONDARY_NODE"

# Verificación inicial
log "🔍 Verificación del estado inicial..."
test_drbd_status
test_webapp

# Menú de pruebas
echo "Selecciona el tipo de prueba:"
echo "1) Apagado graceful"
echo "2) Desconexión de red"
echo "3) Falla crítica simulada"
echo "4) Solo monitoreo"
read -p "Opción (1-4): " option

case $option in
    1)
        log "🔄 Ejecutando prueba de apagado graceful"
        # Aquí irían los comandos específicos
        ;;
    2)
        log "🔄 Ejecutando prueba de desconexión de red"
        # Aquí irían los comandos específicos
        ;;
    3)
        log "⚠️ Ejecutando prueba de falla crítica"
        echo "⚠️ ADVERTENCIA: Esta prueba reiniciará forzosamente el nodo"
        read -p "¿Continuar? (y/N): " confirm
        [[ $confirm =~ ^[Yy]$ ]] || exit 1
        # Aquí irían los comandos específicos
        ;;
    4)
        log "👀 Modo solo monitoreo activado"
        ;;
    *)
        log "❌ Opción inválida"
        exit 1
        ;;
esac

# Monitoreo continuo
log "👀 Iniciando monitoreo continuo..."
log "📁 Log guardado en: $TEST_LOG"
log "🏁 Prueba completada. Revisa el log para detalles completos."
```

## Notas Importantes

- 📝 **Documentación**: Registra el tiempo que toma completar el failover
- 🧪 **Escenarios múltiples**: Prueba diferentes escenarios de falla (red, energía, crash de servicio)
- 🔄 **Funcionalidad de failback**: Verifica que el failback funcione correctamente
- 📊 **Pruebas bajo carga**: Considera probar bajo carga para escenarios más realistas
- 🚨 **Entorno de pruebas**: Realiza siempre estas pruebas en un entorno de desarrollo
- 📱 **Notificaciones**: Configura alertas para monitoreo en producción
- 🔐 **Respaldos**: Asegúrate de tener respaldos antes de ejecutar pruebas destructivas

## Reporte de Resultados

```bash
# Generar reporte final
echo "📊 REPORTE DE PRUEBAS DE FAILOVER - $(date)" > /tmp/failover-report.txt
echo "==========================================" >> /tmp/failover-report.txt
echo "" >> /tmp/failover-report.txt
echo "🎯 Resultados de las pruebas:" >> /tmp/failover-report.txt
echo "- Tiempo de detección: XX segundos" >> /tmp/failover-report.txt
echo "- Tiempo de failover: XX segundos" >> /tmp/failover-report.txt
echo "- Continuidad de servicio: ✅/❌" >> /tmp/failover-report.txt
echo "- Integridad de datos: ✅/❌" >> /tmp/failover-report.txt
echo "" >> /tmp/failover-report.txt
echo "📝 Observaciones:" >> /tmp/failover-report.txt
echo "- [Agregar observaciones específicas]" >> /tmp/failover-report.txt
```

¡Con esta guía comprensiva puedes probar exhaustivamente la funcionalidad de failover de tu clúster DRBD y asegurar la alta disponibilidad de tus aplicaciones!
