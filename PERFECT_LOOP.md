# 🔄 Cómo crear un loop perfecto sin cortes

## Problema
Cuando el video hace loop se escucha un corte audible en el audio.

## Soluciones

### ✅ Opción 1: Pre-procesar el video (RECOMENDADO)

Usa el script incluido para crear un video con crossfade perfecto:

```bash
# En tu servidor
cd /opt/youtube_streamer
chmod +x create_perfect_loop.sh

# Crear loop perfecto (1 segundo de crossfade)
./create_perfect_loop.sh media/rain.mp4 media/rain_loop.mp4 1

# Usar el nuevo video
nano /opt/environment/youtube_streamer/.env
# Cambiar: FILE_PATH=/media/rain_loop.mp4

# Reiniciar
docker compose restart
```

### ⚡ Opción 2: Fade automático en tiempo real

Agrega fade in/out automático al audio:

```bash
# Editar .env
nano /opt/environment/youtube_streamer/.env

# Agregar esta línea:
AUDIO_FADE_LOOP=1

# Reiniciar
docker compose restart
```

Esto agrega:
- 0.5s fade in al inicio
- 0.5s fade out al final
- Suaviza la transición del loop

### 🎯 Opción 3: Crear audio específico para loop

Si tu audio de lluvia es muy corto (8 segundos), considera:

1. **Extender el audio** a 30-60 segundos para que el loop sea menos notable
2. **Usar muestras diseñadas para loop** (buscar "seamless loop" en sitios de audio)
3. **Crear con IA** un audio más largo diseñado específicamente para loop

#### Crear audio extendido con FFmpeg:

```bash
# Concatenar el mismo audio 10 veces (80 segundos)
echo "file 'rain.mp4'" > /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt
echo "file 'rain.mp4'" >> /tmp/list.txt

ffmpeg -f concat -safe 0 -i /tmp/list.txt -c copy media/rain_extended.mp4
```

### 📝 Mejor práctica

Para streams 24/7 de lluvia:
- Usa audio de mínimo 30-60 minutos
- El loop largo es imperceptible
- Busca en YouTube "1 hour rain loop" y descarga con `yt-dlp`

```bash
# Instalar yt-dlp
pip install yt-dlp

# Descargar video de lluvia largo
yt-dlp -f "best[height<=1080]" "https://www.youtube.com/watch?v=VIDEO_ID" -o media/rain_long.mp4
```

## Comparación

| Método | Calidad | Facilidad | CPU |
|--------|---------|-----------|-----|
| Pre-procesar con crossfade | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Bajo |
| Fade automático | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Bajo |
| Audio más largo | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Bajo |

## Recomendación

Para el mejor resultado:
1. Descarga un video de lluvia de 1+ hora
2. O usa el script `create_perfect_loop.sh` con tu video actual
3. Ajusta `VIDEO_FRAMERATE=24` para evitar duplicación de frames
