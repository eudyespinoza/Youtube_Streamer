#!/usr/bin/env bash
# Script para crear un video con loop perfecto sin cortes audibles
# Uso: ./create_perfect_loop.sh input.mp4 output.mp4 [duracion_crossfade_segundos]

set -e

INPUT_FILE="${1:?Error: Proporciona archivo de entrada}"
OUTPUT_FILE="${2:?Error: Proporciona archivo de salida}"
CROSSFADE_DURATION="${3:-1}"  # 1 segundo por defecto

echo "🎬 Creando loop perfecto con crossfade de ${CROSSFADE_DURATION}s..."

# Obtener duración del video
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
DURATION=${DURATION%.*}  # Convertir a entero

echo "📊 Duración del video: ${DURATION}s"

# Crear video con crossfade de audio
ffmpeg -i "$INPUT_FILE" -i "$INPUT_FILE" \
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
