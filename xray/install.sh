#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/xray/xr-conf.sh"
SCRIPT_PATH="/usr/local/bin/xr-conf"

if ! command -v docker >/dev/null 2>&1; then

    apt-get update -y
    apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    echo "[OK] Docker installed"
    usermod -aG docker $USER && newgrp docker
    docker --version
else
    echo "[INFO] Docker is already installed. Skipping installation."
fi

echo "[INFO] Downloading xr-conf utility from GitHub..."
rm -f "$SCRIPT_PATH"
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
