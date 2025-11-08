# YouTube 24/7 Streamer - AI Agent Instructions

## Project Overview
Dockerized FFmpeg service for continuous YouTube Live streaming with automatic reconnection, health monitoring, and flexible input sources (local files, playlists, RTSP/RTMP streams).

## Architecture & Key Components

### Core Stack
- **Base Image**: `jrottenberg/ffmpeg:6.0-ubuntu` - provides FFmpeg 6.0 on Ubuntu
- **Entry Point**: `entrypoint.sh` - infinite loop with exponential backoff (2s → 60s max)
- **Configuration**: `.env` file drives all runtime behavior (codec, bitrate, input mode, overlay)

### Input Modes (via `INPUT_MODE` env var)
- `FILE`: Single video with optional loop (`-stream_loop -1`)
- `PLAYLIST`: Concat demuxer with `playlist.txt` (one file path per line)
- `RTSP`: IP camera feeds with configurable transport (tcp/udp)
- `RTMP`: Direct RTMP stream ingestion

### Output Target
Always `rtmp://a.rtmp.youtube.com/live2/{YOUTUBE_STREAM_KEY}` via FLV container

## Critical Implementation Details

### FFmpeg Command Construction (in `entrypoint.sh`)
- **Input args**: Built dynamically via `build_input_args()` - uses `eval` for proper expansion
- **Video encoding**: H.264 with CBR (`-maxrate` = `-b:v`, `-bufsize` = 2x bitrate)
- **Pixel format**: Must be `yuv420p` for YouTube compatibility
- **Audio requirement**: YouTube rejects streams without audio - use `-f lavfi -i anullsrc` if needed
- **Rate enforcement**: `-re` flag for realtime playback (prevents buffer flooding)

### Reconnection Logic
```bash
while true; do
  ffmpeg ... || true  # Never exit on failure
  sleep $BACKOFF      # Exponential: 2→4→8→16→32→60 (capped)
done
```

### Health Check Strategy
- **Method**: `pgrep -x ffmpeg` (process must be running)
- **Timing**: 30s interval, 20s startup grace period, 3 retries
- **Purpose**: Enables `docker compose` to restart dead containers

## Development Workflows

### Initial Setup
```bash
# Create project structure at /opt/youtube-stream
mkdir -p /opt/youtube-stream/{media,overlays}
cd /opt/youtube-stream

# Copy all files from specification
# Create .env from .env.example and add your YOUTUBE_STREAM_KEY
chmod 600 .env
```

### Build & Run
```bash
docker compose up -d --build
docker logs -f youtube_stream  # Monitor FFmpeg output
```

### Debugging Commands
```bash
# Health status
docker inspect --format='{{json .State.Health}}' youtube_stream | jq

# Resource usage
docker stats youtube_stream

# Container restart count (high number = connection issues)
docker inspect youtube_stream --format='{{.RestartCount}}'
```

### Log Analysis
- Check for `"Stream mapping:"` and `"frame=..."` lines (indicates streaming)
- Bitrate info: `"bitrate= 3000kbits/s"` should match `VIDEO_BITRATE`
- Errors: Look for `"rtmp_write: error"` or `"Connection refused"`

## Project-Specific Conventions

### Environment Variables
- **Boolean values**: Use `0` or `1` (not true/false)
- **Paths**: Must match container mount points (`/media/...`, `/overlays/...`)
- **Codec names**: Match FFmpeg syntax exactly (`libx264`, not `h264`)

### File Organization
- **Read-only mounts**: `media/` and `overlays/` volumes are `:ro` (prevents accidental writes)
- **Playlist format**: Plain text, one file path per line, relative to `/media/`
- **Overlay images**: PNG with transparency, positioned via `x:y` coordinates

### Security Practices
- `.env` contains secret `YOUTUBE_STREAM_KEY` - never commit to Git
- No exposed ports (outbound RTMP only)
- Minimal Ubuntu base (only `procps`, `ca-certificates`, `tzdata` installed)

## Common Pitfalls

### FFmpeg Failures
- **"Invalid data found when processing input"**: Check file codec/format compatibility
- **"Connection refused"**: YouTube stream key likely invalid or stream offline
- **"Non-monotonous DTS"**: Input video has timestamp issues - add `-fflags +genpts`

### Docker Issues
- **Healthcheck never healthy**: `procps` package might be missing (needed for `pgrep`)
- **High CPU usage**: Lower `VIDEO_PRESET` to `faster` or `fast` (tradeoff: higher bitrate)
- **Container exits immediately**: Check logs for `INPUT_MODE` validation errors

## When Implementing New Features

### Adding Input Modes
1. Add new case in `build_input_args()` function
2. Document required env vars in `.env.example`
3. Ensure `-re` flag for non-realtime sources

### Modifying Video Filters
1. Update `build_filters()` function in `entrypoint.sh`
2. Chain multiple filters with commas: `scale=1280:720,overlay=10:10`
3. Test filter syntax separately: `ffmpeg -filters` for available options

### Adjusting Stream Quality
- Lower bitrate → lower quality but more reliable on slow networks
- `veryfast` preset → fast encoding, higher bitrate needed
- `slow` preset → better compression but higher CPU
