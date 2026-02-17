FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ser2net && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["ser2net", "-n", "-c", "/etc/ser2net.conf"]
