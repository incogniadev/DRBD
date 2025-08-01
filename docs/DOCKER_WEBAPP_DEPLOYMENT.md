# Despliegue de una WebApp Simple en Docker con NFS

Esta guía cubre los pasos para desplegar una WebApp simple usando Docker, con sus datos almacenados en un volumen NFS.

## Prerrequisitos

- Docker instalado en tu sistema Debian.
- Servidor NFS configurado y operativo en tu configuración DRBD.
- Asegúrate de que NFS esté montado en `/mnt/nfs-docker` o tu punto de montaje en el Nodo 3.

## Pasos

1. **Crear un Dockerfile para tu WebApp:**

   ```dockerfile
   FROM ubuntu:20.04
   RUN apt-get update  26 26 apt-get install -y nginx
   COPY . /var/www/html
   CMD ["nginx", "-g", "daemon off;"]
   ```

2. **Construir la Imagen de Docker:**

   Navega a tu directorio de proyecto que contiene el Dockerfile.

   ```bash
   docker build -t mi-webapp .
   ```

3. **Ejecutar el Contenedor Docker:**

   Usa el siguiente comando para iniciar tu contenedor y mapear el volumen NFS.

   ```bash
   docker run -d -p 80:80 -v /mnt/nfs-docker/mi-webapp:/var/www/html mi-webapp
   ```

4. **Verificar el Despliegue:**

   Abre un navegador web y navega a `http://tu-ip-nodo`. Deberías ver la WebApp desplegada.

## Ejemplo completo paso a paso

### 1. Preparar el entorno

```bash
# Verificar que NFS esté montado
sudo mkdir -p /mnt/nfs-docker
sudo mount -t nfs 192.168.10.230:/mnt/docker-vol /mnt/nfs-docker

# Verificar el montaje
df -h | grep nfs
```

### 2. Crear contenido de ejemplo

```bash
# Crear directorio de trabajo
mkdir ~/mi-webapp
cd ~/mi-webapp

# Crear página HTML de ejemplo
cat > index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebApp DRBD - Prueba de Alta Disponibilidad</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; }
        .status { color: #4CAF50; font-weight: bold; }
        .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 WebApp DRBD - Alta Disponibilidad</h1>
        <p class="status">✅ Aplicación funcionando correctamente</p>
        
        <div class="info">
            <h3>📊 Información del Sistema</h3>
            <p><strong>Servidor:</strong> $(hostname)</p>
            <p><strong>Fecha:</strong> $(date)</p>
            <p><strong>Almacenamiento:</strong> NFS sobre DRBD</p>
            <p><strong>Estado:</strong> Operativo</p>
        </div>
        
        <h3>🔧 Prueba de Failover</h3>
        <p>Esta aplicación utiliza almacenamiento centralizado NFS respaldado por DRBD. 
        En caso de falla del nodo primario, la aplicación continuará funcionando 
        automáticamente en el nodo secundario.</p>
        
        <p><small>Actualizado: $(date)</small></p>
    </div>
</body>
</html>
EOF

# Crear Dockerfile
cat > Dockerfile << EOF
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
```

### 3. Construir y desplegar

```bash
# Construir la imagen
docker build -t mi-webapp-drbd .

# Crear directorio en NFS para los datos persistentes
sudo mkdir -p /mnt/nfs-docker/webapp-data
echo "Datos persistentes - $(date)" | sudo tee /mnt/nfs-docker/webapp-data/data.txt

# Ejecutar contenedor con volumen NFS
docker run -d \
  --name webapp-drbd \
  -p 80:80 \
  -v /mnt/nfs-docker/webapp-data:/usr/share/nginx/html/data \
  mi-webapp-drbd
```

### 4. Verificación y monitoreo

```bash
# Verificar que el contenedor esté ejecutándose
docker ps

# Verificar logs del contenedor
docker logs webapp-drbd

# Probar la aplicación
curl http://localhost

# Verificar datos persistentes
ls -la /mnt/nfs-docker/webapp-data/

# Probar desde otro nodo
curl http://192.168.10.233
```

## Scripts de automatización

### Script de despliegue rápido

```bash
#!/bin/bash
# deploy-webapp.sh

set -e

echo "🚀 Desplegando WebApp con almacenamiento NFS..."

# Verificar montaje NFS
if ! mountpoint -q /mnt/nfs-docker; then
    echo "❌ NFS no está montado. Montando..."
    sudo mount -t nfs 192.168.10.230:/mnt/docker-vol /mnt/nfs-docker
fi

# Crear directorio de datos
sudo mkdir -p /mnt/nfs-docker/webapp-data

# Detener contenedor existente si existe
docker stop webapp-drbd 2>/dev/null || true
docker rm webapp-drbd 2>/dev/null || true

# Ejecutar nuevo contenedor
docker run -d \
  --name webapp-drbd \
  --restart unless-stopped \
  -p 80:80 \
  -v /mnt/nfs-docker/webapp-data:/usr/share/nginx/html/data \
  nginx:alpine

echo "✅ WebApp desplegada exitosamente"
echo "🌐 Accede a: http://$(hostname -I | awk '{print $1}')"
```

### Script de verificación

```bash
#!/bin/bash
# verify-webapp.sh

echo "🔍 Verificando estado de la WebApp..."

# Verificar contenedor
if docker ps | grep -q webapp-drbd; then
    echo "✅ Contenedor webapp-drbd ejecutándose"
else
    echo "❌ Contenedor webapp-drbd no encontrado"
    exit 1
fi

# Verificar conectividad
if curl -s http://localhost > /dev/null; then
    echo "✅ WebApp responde correctamente"
else
    echo "❌ WebApp no responde"
    exit 1
fi

# Verificar almacenamiento NFS
if mountpoint -q /mnt/nfs-docker; then
    echo "✅ Almacenamiento NFS montado correctamente"
else
    echo "❌ Almacenamiento NFS no disponible"
    exit 1
fi

echo "🎉 Todas las verificaciones pasaron exitosamente"
```

## Resolución de problemas

### Problemas comunes

1. **NFS no montado**:
   ```bash
   sudo mount -t nfs 192.168.10.230:/mnt/docker-vol /mnt/nfs-docker
   ```

2. **Contenedor no inicia**:
   ```bash
   docker logs webapp-drbd
   docker inspect webapp-drbd
   ```

3. **Puerto ocupado**:
   ```bash
   sudo netstat -tulpn | grep :80
   docker stop $(docker ps -q --filter "publish=80")
   ```

4. **Permisos de NFS**:
   ```bash
   sudo chown -R $(whoami):$(whoami) /mnt/nfs-docker/webapp-data
   ```

¡Listo! Has desplegado una WebApp simple usando Docker con almacenamiento en NFS respaldado por DRBD.
