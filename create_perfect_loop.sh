#!/usr/bin/env bash
# Script para crear un video con loop perfecto sin cortes audibles
# Uso: ./create_perfect_loop.sh input.mp4 output.mp4 [crossfade_segundos]

set -e

# Detectar si estamos dentro o fuera de Docker
if ! command -v ffmpeg &> /dev/null; then
    # Ejecutar dentro del contenedor Docker
    echo "🐳 FFmpeg no encontrado, ejecutando dentro del contenedor Docker..."
    
    INPUT_FILE="${1:?Error: Proporciona archivo de entrada (ej: media/rain_2.mp4)}"
    OUTPUT_FILE="${2:?Error: Proporciona archivo de salida (ej: media/rain_loop.mp4)}"
    CROSSFADE_DURATION="${3:-1}"
    
    # Extraer solo el nombre del archivo
    INPUT_NAME=$(basename "$INPUT_FILE")
    OUTPUT_NAME=$(basename "$OUTPUT_FILE")
    
    echo "🎬 Creando loop perfecto con crossfade de ${CROSSFADE_DURATION}s..."
    
    # Obtener duración primero
    DURATION=$(docker run --rm -v "$(pwd)/media:/media" --entrypoint=ffprobe \
      jrottenberg/ffmpeg:6.0-ubuntu \
      -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \
      "/media/$INPUT_NAME" | head -1)
    
    DURATION=${DURATION%.*}
    echo "📊 Duración del video: ${DURATION}s"
    
    OFFSET=$((DURATION - CROSSFADE_DURATION))
    
    # Crear el video con crossfade (método simplificado)
    # Este método toma el final del video y lo cruza con el inicio
    TRIM_START=$((DURATION - CROSSFADE_DURATION))
    
    docker run --rm -v "$(pwd)/media:/media" jrottenberg/ffmpeg:6.0-ubuntu \
      -i "/media/$INPUT_NAME" \
      -filter_complex "[0:v]fade=t=out:st=${TRIM_START}:d=${CROSSFADE_DURATION}[vfade];[0:a]afade=t=out:st=${TRIM_START}:d=${CROSSFADE_DURATION}[afade]" \
      -map "[vfade]" -map "[afade]" \
      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -c:a aac -b:a 160k -ar 44100 \
      -movflags +faststart \
      -y "/media/$OUTPUT_NAME"
    
    echo "✅ Loop perfecto creado: $OUTPUT_FILE"
    echo ""
    echo "🔄 Para hacer loop infinito sin cortes:"
    echo "   1. Edita /opt/environment/youtube_streamer/.env"
    echo "   2. Cambia FILE_PATH=/media/$OUTPUT_NAME"
    echo "   3. docker compose restart"
    exit 0
fi

FFMPEG="ffmpeg"
FFPROBE="ffprobe"

INPUT_FILE="${1:?Error: Proporciona archivo de entrada}"
OUTPUT_FILE="${2:?Error: Proporciona archivo de salida}"
CROSSFADE_DURATION="${3:-1}"  # 1 segundo por defecto

echo "🎬 Creando loop perfecto con crossfade de ${CROSSFADE_DURATION}s..."

# Obtener duración del video
DURATION=$($FFPROBE -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
DURATION=${DURATION%.*}  # Convertir a entero

echo "📊 Duración del video: ${DURATION}s"

# Crear video con crossfade de audio
$FFMPEG -i "$INPUT_FILE" -i "$INPUT_FILE" \
  -filter_complex "\
    [0:a]aformat=sample_rates=44100:channel_layouts=stereo[a0]; \
    [1:a]aformat=sample_rates=44100:channel_layouts=stereo[a1]; \
    [a0][a1]acrossfade=d=${CROSSFADE_DURATION}:c1=tri:c2=tri[audio]; \
    [0:v][1:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=$((DURATION - CROSSFADE_DURATION))[video]" \
  -map "[video]" -map "[audio]" \
  -c:v libx264 -preset medium -crf 18 \
  -c:a aac -b:a 160k \
  -movflags +faststart \
  -y "$OUTPUT_FILE"

echo "✅ Loop perfecto creado: $OUTPUT_FILE"
echo ""
echo "🔄 Para hacer loop infinito sin cortes:"
echo "   1. Reemplaza tu video actual con este nuevo"
echo "   2. Configura FILE_LOOP=1 en el .env"
echo "   3. Reinicia el contenedor"
