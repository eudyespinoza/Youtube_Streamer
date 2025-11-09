#!/usr/bin/env bash
# Script para optimizar/comprimir videos manteniendo calidad visual
# Uso: ./optimize_video.sh input.mp4 output.mp4 [calidad]
# Calidad: 23 (alta, ~50% tamaño), 28 (media, ~30% tamaño), 32 (baja, ~20% tamaño)

set -e

INPUT_FILE="${1:?Error: Proporciona archivo de entrada (ej: media/rain.mp4)}"
OUTPUT_FILE="${2:?Error: Proporciona archivo de salida (ej: media/rain_optimized.mp4)}"
CRF="${3:-23}"  # Calidad: menor = mejor calidad pero más tamaño (18-28 recomendado)

# Validar CRF
if [ "$CRF" -lt 18 ] || [ "$CRF" -gt 35 ]; then
    echo "⚠️  CRF debe estar entre 18 (máxima calidad) y 35 (mínimo tamaño)"
    echo "    Recomendado: 23 (balance), 28 (más compresión)"
    exit 1
fi

echo "🎬 Optimizando video..."
echo "   Input: $INPUT_FILE"
echo "   Output: $OUTPUT_FILE"
echo "   CRF: $CRF (menor = mejor calidad)"

# Detectar si estamos dentro o fuera de Docker
if ! command -v ffmpeg &> /dev/null; then
    echo "🐳 Ejecutando en Docker..."
    
    INPUT_NAME=$(basename "$INPUT_FILE")
    OUTPUT_NAME=$(basename "$OUTPUT_FILE")
    
    # Obtener tamaño original
    ORIGINAL_SIZE=$(ls -lh "media/$INPUT_NAME" | awk '{print $5}')
    echo "📦 Tamaño original: $ORIGINAL_SIZE"
    
    # Optimizar con FFmpeg
    docker run --rm -v "$(pwd)/media:/media" jrottenberg/ffmpeg:6.0-ubuntu \
      -i "/media/$INPUT_NAME" \
      -c:v libx264 -preset slow -crf "$CRF" \
      -pix_fmt yuv420p \
      -profile:v main -level 4.0 \
      -movflags +faststart \
      -c:a aac -b:a 128k -ar 44100 \
      -max_muxing_queue_size 1024 \
      -y "/media/$OUTPUT_NAME"
    
    # Mostrar tamaño final
    NEW_SIZE=$(ls -lh "media/$OUTPUT_NAME" | awk '{print $5}')
    echo ""
    echo "✅ Optimización completada!"
    echo "   Original: $ORIGINAL_SIZE"
    echo "   Optimizado: $NEW_SIZE"
    
    # Calcular reducción aproximada
    ORIGINAL_BYTES=$(stat -f%z "media/$INPUT_NAME" 2>/dev/null || stat -c%s "media/$INPUT_NAME")
    NEW_BYTES=$(stat -f%z "media/$OUTPUT_NAME" 2>/dev/null || stat -c%s "media/$OUTPUT_NAME")
    REDUCTION=$((100 - (NEW_BYTES * 100 / ORIGINAL_BYTES)))
    echo "   Reducción: ~${REDUCTION}%"
    echo ""
    echo "🔄 Para usar el video optimizado:"
    echo "   nano /opt/environment/youtube_streamer/.env"
    echo "   FILE_PATH=/media/$OUTPUT_NAME"
    echo "   docker compose restart"
    
    exit 0
fi

# Si FFmpeg está instalado localmente
echo "📦 Tamaño original: $(ls -lh "$INPUT_FILE" | awk '{print $5}')"

ffmpeg -i "$INPUT_FILE" \
  -c:v libx264 -preset slow -crf "$CRF" \
  -pix_fmt yuv420p \
  -profile:v main -level 4.0 \
  -movflags +faststart \
  -c:a aac -b:a 128k -ar 44100 \
  -max_muxing_queue_size 1024 \
  -y "$OUTPUT_FILE"

echo ""
echo "✅ Optimización completada!"
echo "   Original: $(ls -lh "$INPUT_FILE" | awk '{print $5}')"
echo "   Optimizado: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
