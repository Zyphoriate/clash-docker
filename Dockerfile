FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime deps: clashctl + subconverter
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    tar \
    unzip \
    gzip \
    procps \
    iproute2 \
    net-tools \
    git \
    ca-certificates \
    libpcre3 \
    libevent-2.1-7 \
    libyaml-cpp0.7 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Install clashctl (use gh-proxy for China accessibility)
RUN git clone --branch master --depth 1 \
    https://github.com/nelvko/clash-for-linux-install.git \
    /tmp/clash-for-linux-install \
    && cd /tmp/clash-for-linux-install \
    && bash install.sh \
    && rm -rf /tmp/clash-for-linux-install

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7890 9090

ENTRYPOINT ["/entrypoint.sh"]
