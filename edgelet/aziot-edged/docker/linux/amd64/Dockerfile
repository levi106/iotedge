FROM debian:10-slim

# package installation needs to exec as root
RUN apt-get update && apt-get install -y \
  ca-certificates && \
  echo "deb http://deb.debian.org/debian stretch main" >> /etc/apt/sources.list && \
  apt-get update && apt-get install -y \
  libssl1.0.2 \
  curl \
  strace \
  && rm -rf /var/lib/apt/lists/*

# run everything else as system user
RUN groupadd -g 995 iotedge \
  && groupadd -g 996 aziotid \
  && groupadd -g 997 aziotcs \
  && groupadd -g 998 aziottpm \
  && groupadd -g 999 aziotks \
  && useradd -u 995 -d /var/lib/aziot/edged -s /sbin/nologin -g 995 -G 996,997,999 iotedge \
  && useradd -u 996 -d /var/lib/aziot/identityd -s /sbin/nologin -g 996 -G 997,998,999 aziotid \
  && useradd -u 997 -d /var/lib/aziot/certd -s /sbin/nologin -g 997 -G 999 aziotcs \
  && useradd -u 998 -d /var/lib/aziot/tpmd -s /sbin/nologin -g 998 aziottpm \
  && useradd -u 999 -d /var/lib/aziot/keyd -s /sbin/nologin -g 999 aziotks
USER iotedge

WORKDIR /app
ADD ./docker/linux/amd64/ /app

CMD ["/app/aziot-edged"]