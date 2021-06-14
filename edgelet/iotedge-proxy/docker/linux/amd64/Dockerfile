FROM debian:10-slim

# package installation needs to exec as root
RUN apt-get update && apt-get install -y \
  ca-certificates && \
  echo "deb http://deb.debian.org/debian stretch main" >> /etc/apt/sources.list && \
  apt-get update && apt-get install -y \
  libssl1.0.2 \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd edgeproxy && useradd edgeproxy -g edgeproxy
USER edgeproxy

WORKDIR /app
COPY ./docker/linux/amd64/iotedge-proxy /app/iotedge-proxy

CMD ["/app/iotedge-proxy"]
