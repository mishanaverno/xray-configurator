#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/USER/REPO/main/install.sh"
SCRIPT_PATH="/tmp/remote-install.sh"

echo "[INFO] Downloading script from GitHub..."
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

echo "[INFO] Running downloaded script..."
sh "$SCRIPT_PATH"

echo "[INFO] Installing Docker..."

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

docker --version
