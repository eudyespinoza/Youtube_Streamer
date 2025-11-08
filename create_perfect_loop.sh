#!/usr/bin/env bash
# Script para crear un video con loop perfecto sin cortes audibles
# Uso: docker run --rm -v ./media:/media jrottenberg/ffmpeg:6.0-ubuntu /media/create_perfect_loop.sh input.mp4 output.mp4 [crossfade_segundos]
# O simplemente: ./create_perfect_loop.sh input.mp4 output.mp4 [crossfade_segundos]

set -e

# Detectar si estamos dentro o fuera de Docker
if command -v ffmpeg &> /dev/null; then
    # Estamos dentro del contenedor o FFmpeg está instalado
    FFMPEG="ffmpeg"
    FFPROBE="ffprobe"
else
    # Ejecutar dentro del contenedor Docker
    echo "🐳 FFmpeg no encontrado, ejecutando dentro del contenedor Docker..."
    docker run --rm -v "$(pwd)/media:/media" jrottenberg/ffmpeg:6.0-ubuntu bash -c "
        INPUT_FILE=\"/media/\${1##*/}\"
        OUTPUT_FILE=\"/media/\${2##*/}\"
        CROSSFADE_DURATION=\"\${3:-1}\"
        
        echo '🎬 Creando loop perfecto con crossfade de '\${CROSSFADE_DURATION}'s...'
        
        DURATION=\$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"\$INPUT_FILE\")
        DURATION=\${DURATION%.*}
        
        echo '📊 Duración del video: '\${DURATION}'s'
        
        ffmpeg -i \"\$INPUT_FILE\" -i \"\$INPUT_FILE\" \\
          -filter_complex \"
            [0:a]aformat=sample_rates=44100:channel_layouts=stereo[a0];
            [1:a]aformat=sample_rates=44100:channel_layouts=stereo[a1];
            [a0][a1]acrossfade=d=\${CROSSFADE_DURATION}:c1=tri:c2=tri[audio];
            [0:v][1:v]xfade=transition=fade:duration=\${CROSSFADE_DURATION}:offset=\$((DURATION - CROSSFADE_DURATION))[video]\" \\
          -map \"[video]\" -map \"[audio]\" \\
          -c:v libx264 -preset medium -crf 18 \\
          -c:a aac -b:a 160k \\
          -movflags +faststart \\
          -y \"\$OUTPUT_FILE\"
        
        echo '✅ Loop perfecto creado: '\$OUTPUT_FILE
    " -- "$1" "$2" "${3:-1}"
    exit 0
fi

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
