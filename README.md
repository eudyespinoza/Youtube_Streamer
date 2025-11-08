# 📡 YouTube 24/7 Streamer

Servicio Docker que transmite video y audio a **YouTube Live** en forma continua (24/7), con reconexión automática, healthcheck y configuración flexible.

## 🎯 Características

- ✅ Loop continuo de archivos locales o playlists
- ✅ Soporte para fuentes en vivo (RTSP/RTMP)
- ✅ Reconexión automática con backoff exponencial
- ✅ Healthcheck y restart automático
- ✅ Configuración completa vía `.env`
- ✅ Logs rotados automáticamente
- ✅ Overlays de imagen (watermarks/logos)

## 🧱 Requisitos

- Docker Engine y Docker Compose v2
- Conexión de salida a `rtmp://a.rtmp.youtube.com:1935`
- YouTube Stream Key válida

## 📂 Estructura del Proyecto

```
youtube-stream/
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── .env.example
├── media/
│   ├── video.mp4
│   └── playlist.txt
└── overlays/
    └── logo.png
```

## 🚀 Instalación Rápida

### 1. Clonar o crear el proyecto

```bash
mkdir -p /opt/youtube-stream/{media,overlays}
cd /opt/youtube-stream
# Copiar todos los archivos del proyecto aquí
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
nano .env  # Editar y añadir tu YOUTUBE_STREAM_KEY
chmod 600 .env
```

### 3. Añadir contenido multimedia

```bash
# Copiar videos a la carpeta media/
cp tus_videos.mp4 ./media/

# Opcional: añadir logo/overlay
cp tu_logo.png ./overlays/
```

### 4. Construir y ejecutar

```bash
docker compose up -d --build
```

### 5. Monitorear

```bash
docker logs -f youtube_stream
```

## ⚙️ Configuración

### Modos de Entrada (INPUT_MODE)

#### FILE - Archivo único
```env
INPUT_MODE=FILE
FILE_PATH=/media/video.mp4
FILE_LOOP=1  # 1 para loop infinito, 0 para una sola vez
```

#### PLAYLIST - Lista de reproducción
```env
INPUT_MODE=PLAYLIST
PLAYLIST_PATH=/media/playlist.txt
PLAYLIST_SAFE=0
```

Formato de `playlist.txt`:
```
file '/media/video1.mp4'
file '/media/video2.mp4'
file '/media/video3.mp4'
```

#### RTSP - Cámara IP
```env
INPUT_MODE=RTSP
INPUT_URL=rtsp://user:pass@192.168.1.100:554/stream
RTSP_TRANSPORT=tcp
```

#### RTMP - Stream directo
```env
INPUT_MODE=RTMP
INPUT_URL=rtmp://servidor.com/live/stream
```

### Calidad de Video

**1080p @ 30fps (recomendado)**
```env
VIDEO_SIZE=1920x1080
VIDEO_FRAMERATE=30
VIDEO_BITRATE=3000k
VIDEO_MAXRATE=3000k
VIDEO_BUFSIZE=6000k
```

**720p @ 30fps (bajo ancho de banda)**
```env
VIDEO_SIZE=1280x720
VIDEO_FRAMERATE=30
VIDEO_BITRATE=2000k
VIDEO_MAXRATE=2000k
VIDEO_BUFSIZE=4000k
```

**4K @ 60fps (alto rendimiento)**
```env
VIDEO_SIZE=3840x2160
VIDEO_FRAMERATE=60
VIDEO_BITRATE=8000k
VIDEO_MAXRATE=8000k
VIDEO_BUFSIZE=16000k
VIDEO_PRESET=fast  # Requiere más CPU
```

### Overlay/Watermark

```env
ENABLE_OVERLAY=1
OVERLAY_FILE=/overlays/logo.png
OVERLAY_POSITION=10:10  # x:y (píxeles desde arriba-izquierda)
```

Posiciones comunes:
- `10:10` - Superior izquierda
- `main_w-overlay_w-10:10` - Superior derecha
- `10:main_h-overlay_h-10` - Inferior izquierda
- `main_w-overlay_w-10:main_h-overlay_h-10` - Inferior derecha

## 🔧 Comandos Útiles

### Ver estado y logs
```bash
docker ps
docker logs -f youtube_stream
docker stats youtube_stream
```

### Verificar salud del contenedor
```bash
docker inspect --format='{{json .State.Health}}' youtube_stream | jq
```

### Ver cantidad de reinicios
```bash
docker inspect youtube_stream --format='{{.RestartCount}}'
```

### Reiniciar stream
```bash
docker compose restart
```

### Detener stream
```bash
docker compose down
```

### Actualizar configuración
```bash
# 1. Editar .env
nano .env

# 2. Reconstruir y reiniciar
docker compose up -d --build
```

### Limpiar y reconstruir
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 📊 Monitoreo y Debugging

### Señales de transmisión exitosa
Los logs deben mostrar:
```
Stream mapping:
  Stream #0:0 -> #0:0 (h264 (native) -> h264 (libx264))
  Stream #0:1 -> #0:1 (aac (native) -> aac (native))
frame=  150 fps= 30 q=28.0 size=    1024kB time=00:00:05.00 bitrate=1677.7kbits/s speed=1.00x
```

### Errores comunes

**"Invalid data found when processing input"**
- Verifica que el archivo de video sea válido
- Prueba con otro codec o re-encodea el video

**"Connection refused"**
- Stream key inválida
- YouTube stream no está activa
- Firewall bloqueando puerto 1935

**"Non-monotonous DTS"**
- Video con timestamps problemáticos
- Solución: añadir `-fflags +genpts` al comando FFmpeg en entrypoint.sh

**Healthcheck unhealthy**
- FFmpeg crasheando repetidamente
- Revisar logs para ver el error específico

**Alto uso de CPU**
- Bajar `VIDEO_PRESET` a `faster` o `fast`
- Reducir resolución o framerate
- Considerar codec de hardware si está disponible

## 🔒 Seguridad

- **Nunca** commitear el archivo `.env` con tu stream key
- Usar `chmod 600 .env` para proteger credenciales
- Los volúmenes `media/` y `overlays/` son read-only (`:ro`)
- No se exponen puertos al exterior

## 📋 Checklist de Verificación

- [ ] Stream transmitiendo por más de 10 minutos
- [ ] Reconexión automática funciona (probar deteniendo/iniciando)
- [ ] Healthcheck reporta `healthy`
- [ ] Video y audio correctos en YouTube Live
- [ ] Overlay visible (si está habilitado)
- [ ] Uso de CPU/memoria normal
- [ ] Logs rotando correctamente (max 10m x 5 archivos)

## 🆘 Soporte

Si encuentras problemas:

1. **Revisar logs**: `docker logs youtube_stream`
2. **Verificar .env**: Todas las variables configuradas correctamente
3. **Probar video local**: Asegurarte que el archivo funciona con FFmpeg
4. **Verificar stream key**: En YouTube Studio → Transmisión en vivo
5. **Revisar conectividad**: `telnet a.rtmp.youtube.com 1935`

## 📝 Notas Importantes

- YouTube **requiere audio** en el stream. Si tu video no tiene audio, se añade automáticamente uno silencioso
- Los overlays deben ser PNG con transparencia
- El bitrate debe mantenerse constante (CBR) para YouTube
- El formato de píxel debe ser `yuv420p` para compatibilidad
- Los videos deben tener derechos de autor apropiados

## 🔄 Actualización del Proyecto

```bash
cd /opt/youtube-stream
git pull  # Si usas git
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 📜 Licencia

Este proyecto es de código abierto. Asegúrate de tener los derechos apropiados para el contenido que transmites.
