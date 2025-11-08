#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone || true
fi

build_filters() {
  local vfilters=""
  if [[ "${ENABLE_OVERLAY:-0}" == "1" && -f "${OVERLAY_FILE:-}" ]]; then
    vfilters="overlay=${OVERLAY_POSITION:-10:10}"
  fi
  
  local afilters=""
  if [[ "${AUDIO_FADE_LOOP:-0}" == "1" ]]; then
    # Agregar fade in al inicio y fade out al final para suavizar el loop
    afilters="afade=t=in:st=0:d=0.5,afade=t=out:st=7.5:d=0.5"
  fi
  
  local filter_args=""
  [[ -n "$vfilters" ]] && filter_args="-vf $vfilters"
  [[ -n "$afilters" ]] && filter_args="$filter_args -af $afilters"
  
  echo "$filter_args"
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

  eval ffmpeg -hide_banner -loglevel "${LOG_LEVEL:-info}" \
    ${INPUT_ARGS} \
    -c:v "${VIDEO_CODEC:-libx264}" -preset "${VIDEO_PRESET:-veryfast}" \
    -r "${VIDEO_FRAMERATE:-30}" -s "${VIDEO_SIZE:-1920x1080}" \
    -b:v "${VIDEO_BITRATE:-3000k}" -maxrate "${VIDEO_MAXRATE:-3000k}" -bufsize "${VIDEO_BUFSIZE:-6000k}" \
    -pix_fmt "${PIX_FMT:-yuv420p}" \
    ${FILTER_ARGS} \
    -c:a "${AUDIO_CODEC:-aac}" -b:a "${AUDIO_BITRATE:-160k}" -ar "${AUDIO_RATE:-44100}" \
    -f flv "${OUTPUT_URL}" || true

  echo "FFmpeg finalizó. Reintentando en ${BACKOFF}s..."
  sleep "${BACKOFF}"

  BACKOFF=$(( BACKOFF * 2 ))
  (( BACKOFF > MAX_BACKOFF )) && BACKOFF=${MAX_BACKOFF}
done
