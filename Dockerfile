FROM jrottenberg/ffmpeg:6.0-ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

VOLUME ["/media", "/overlays"]

ENTRYPOINT ["/app/entrypoint.sh"]
