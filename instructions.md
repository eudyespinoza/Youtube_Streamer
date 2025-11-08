# 📡 Proyecto: Stream 24/7 a YouTube con Docker + FFmpeg

## 🎯 Objetivo
Montar un servicio Docker que envíe video y audio a **YouTube Live** en forma continua (24/7), con:
- Loop de un archivo o playlist de varios archivos.
- Opción de tomar una fuente en vivo (RTSP/RTMP).
- Reconexión automática, `restart: always`, healthcheck y logs rotados.
- Configurable vía `.env` sin tocar imágenes/compose.

---

## 🧱 Requisitos del entorno
- Ubuntu 24.04 LTS (server cloud).
- Docker Engine y Docker Compose v2.
- Salida TCP abierta a `rtmp://a.rtmp.youtube.com:1935` (YouTube ingest).
- **No se exponen puertos hacia Internet** (solo salida).

---

## 📂 Estructura del proyecto
```
/opt/youtube-stream/
├─ docker-compose.yml
├─ Dockerfile
├─ entrypoint.sh
├─ .env.example
├─ media/
│  ├─ video.mp4
│  ├─ audio.mp3
│  └─ playlist.txt
└─ overlays/
```

---

## ⚙️ Variables de configuración (`.env.example`)
```env
YOUTUBE_STREAM_KEY=xxxx-xxxx-xxxx-xxxx
YOUTUBE_INGEST_URL=rtmp://a.rtmp.youtube.com/live2

INPUT_MODE=FILE          # FILE | PLAYLIST | RTSP | RTMP
FILE_PATH=/media/video.mp4
FILE_LOOP=1

PLAYLIST_PATH=/media/playlist.txt
PLAYLIST_SAFE=0

INPUT_URL=rtsp://user:pass@ip:554/stream
RTSP_TRANSPORT=tcp

VIDEO_CODEC=libx264
VIDEO_PRESET=veryfast
VIDEO_FRAMERATE=30
VIDEO_SIZE=1920x1080
VIDEO_BITRATE=3000k
VIDEO_MAXRATE=3000k
VIDEO_BUFSIZE=6000k
PIX_FMT=yuv420p

AUDIO_CODEC=aac
AUDIO_BITRATE=160k
AUDIO_RATE=44100

ENABLE_OVERLAY=0
OVERLAY_FILE=/overlays/logo.png
OVERLAY_POSITION=10:10

TZ=America/Argentina/Cordoba
LOG_LEVEL=info
```

---

## 🐳 Dockerfile
```dockerfile
FROM jrottenberg/ffmpeg:6.0-ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends     procps ca-certificates tzdata &&     rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

VOLUME ["/media", "/overlays"]

ENTRYPOINT ["/app/entrypoint.sh"]
```

---

## 🔧 entrypoint.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone || true
fi

build_filters() {
  local filters=""
  if [[ "${ENABLE_OVERLAY:-0}" == "1" && -f "${OVERLAY_FILE:-}" ]]; then
    filters="overlay=${OVERLAY_POSITION:-10:10}"
  fi
  [[ -n "$filters" ]] && echo "-vf $filters" || echo ""
}

build_input_args() {
  case "${INPUT_MODE:-FILE}" in
    FILE)
      local loop_args=()
      [[ "${FILE_LOOP:-0}" == "1" ]] && loop_args=(-stream_loop -1)
      echo "-re ${loop_args[*]} -i \"${FILE_PATH:-/media/video.mp4}\""
      ;;
    PLAYLIST)
      echo "-re -f concat -safe ${PLAYLIST_SAFE:-0} -i \"${PLAYLIST_PATH:-/media/playlist.txt}\""
      ;;
    RTSP)
      echo "-rtsp_transport ${RTSP_TRANSPORT:-tcp} -i \"${INPUT_URL:?INPUT_URL requerido}\""
      ;;
    RTMP)
      echo "-i \"${INPUT_URL:?INPUT_URL requerido}\""
      ;;
    *)
      echo "INPUT_MODE inválido: ${INPUT_MODE}" >&2
      exit 1
      ;;
  esac
}

build_output_url() {
  local url="${YOUTUBE_INGEST_URL:-rtmp://a.rtmp.youtube.com/live2}"
  local key="${YOUTUBE_STREAM_KEY:?Falta YOUTUBE_STREAM_KEY}"
  echo "${url}/${key}"
}

BACKOFF=2
MAX_BACKOFF=60

while true; do
  INPUT_ARGS=$(build_input_args)
  FILTER_ARGS=$(build_filters)
  OUTPUT_URL=$(build_output_url)

  eval ffmpeg -hide_banner -loglevel "${LOG_LEVEL:-info}"     ${INPUT_ARGS}     -c:v "${VIDEO_CODEC:-libx264}" -preset "${VIDEO_PRESET:-veryfast}"     -r "${VIDEO_FRAMERATE:-30}" -s "${VIDEO_SIZE:-1920x1080}"     -b:v "${VIDEO_BITRATE:-3000k}" -maxrate "${VIDEO_MAXRATE:-3000k}" -bufsize "${VIDEO_BUFSIZE:-6000k}"     -pix_fmt "${PIX_FMT:-yuv420p}"     ${FILTER_ARGS}     -c:a "${AUDIO_CODEC:-aac}" -b:a "${AUDIO_BITRATE:-160k}" -ar "${AUDIO_RATE:-44100}"     -f flv "${OUTPUT_URL}" || true

  echo "FFmpeg finalizó. Reintentando en ${BACKOFF}s..."
  sleep "${BACKOFF}"

  BACKOFF=$(( BACKOFF * 2 ))
  (( BACKOFF > MAX_BACKOFF )) && BACKOFF=${MAX_BACKOFF}
done
```

---

## 🧩 docker-compose.yml
```yaml
version: "3.9"
services:
  youtube-stream:
    build: .
    container_name: youtube_stream
    restart: always
    env_file:
      - .env
    environment:
      - TZ=${TZ}
    volumes:
      - ./media:/media:ro
      - ./overlays:/overlays:ro
    healthcheck:
      test: ["CMD-SHELL", "pgrep -x ffmpeg >/dev/null || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
```

---

## 🪜 Tareas del agente
1. Crear estructura `/opt/youtube-stream` y copiar los archivos.
2. Subir videos o lista de reproducción a `/opt/youtube-stream/media`.
3. Crear `.env` a partir de `.env.example` y completar `YOUTUBE_STREAM_KEY`.
4. Build y ejecutar:
   ```bash
   docker compose up -d --build
   docker logs -f youtube_stream
   ```
5. Verificar señal en la consola de YouTube Live.
6. Supervisar:
   ```bash
   docker ps
   docker stats youtube_stream
   docker inspect --format='{{json .State.Health}}' youtube_stream | jq
   ```
7. Ajustar resolución o bitrate según rendimiento.
8. Mantener `.env` privado (`chmod 600 .env`).
9. Actualizar:
   ```bash
   docker compose pull && docker compose up -d --build
   ```
10. Verificar logs rotados automáticamente.

---

## ✅ Checklist
- [ ] Señal continua >10 minutos.
- [ ] Reconexión automática.
- [ ] Healthcheck `healthy`.
- [ ] Overlay visible (si aplica).
- [ ] CPU/red normales.

---

## 💡 Notas finales
- YouTube requiere audio válido (usar `-f lavfi -i anullsrc` si no hay).
- Overlay PNG con transparencia.
- Asegurar derechos de contenido.
- Logs contienen info útil (bitrate, frames).

---

## 📦 Entregable final
- Archivos: `docker-compose.yml`, `Dockerfile`, `entrypoint.sh`, `.env.example`, `media/`, `overlays/`
- Este `instructions.md` como README.
- `.env` privado configurado en servidor.
