FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CLASHCTL_HOME=/opt/clashctl

# Install required dependencies for clash-for-linux-install
# xz-utils (xz), procps (pgrep/pkill), curl, tar, unzip, gzip,
# net-tools (netstat), iproute2 (ip/ss), git, ca-certificates
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
    && rm -rf /var/lib/apt/lists/*

# Clone the project
WORKDIR /opt
RUN git clone --branch master --depth 1 https://github.com/nelvko/clash-for-linux-install.git

# Configure install parameters for container use
WORKDIR /opt/clash-for-linux-install
RUN sed -i 's|CLASHCTL_HOME=~/clashctl|CLASHCTL_HOME=/opt/clashctl|' .env.install && \
    sed -i 's|GH_PROXY=.*|GH_PROXY=|' .env.install

# Run the install script
# The project auto-detects container environments and uses nohup mode
# (install_service is a no-op in containers), so this succeeds cleanly
RUN bash install.sh

# Ensure binaries are executable
RUN chmod +x /opt/clashctl/bin/* 2>/dev/null; exit 0

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default proxy ports:
# 7890 - HTTP/SOCKS mixed port
# 9090 - Web UI / REST API
EXPOSE 7890 9090

ENTRYPOINT ["/entrypoint.sh"]
