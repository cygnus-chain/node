#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# CONFIG
# ----------------------
CYGNUS_DATADIR="${HOME}/cygnus_data"
GETH_VERSION="v1.10.23"
GETH_ZIP_URL="https://github.com/ethereum/go-ethereum/archive/refs/tags/${GETH_VERSION}.zip"
CYGNUS_NETWORKID="235"
CYGNUS_HTTP_PORT="6228"
CYGNUS_WS_PORT="8291"
CYGNUS_P2P_PORT="30303"
BOOTNODES=('enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303')
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  SUDO="sudo"
fi

WORKDIR="$(mktemp -d)"

# ----------------------
# OS check
# ----------------------
if [ -f /etc/debian_version ]; then
  PKG_MANAGER="apt"
else
  echo "This installer currently supports Debian/Ubuntu only." >&2
  exit 1
fi

# ----------------------
# Install build deps
# ----------------------
echo "==> Installing build dependencies..."
$SUDO apt update -y
$SUDO apt install -y curl wget unzip build-essential make gcc ca-certificates git

# ----------------------
# Install Go if missing
# ----------------------
if ! command -v go >/dev/null 2>&1; then
  echo "==> Installing Go..."
  GO_VERSION="1.22.2"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) GO_ARCH="amd64" ;;
    aarch64|arm64) GO_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" ; exit 1 ;;
  esac
  GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  wget -q "https://go.dev/dl/${GO_TARBALL}" -O "${WORKDIR}/${GO_TARBALL}"
  $SUDO rm -rf /usr/local/go
  $SUDO tar -C /usr/local -xzf "${WORKDIR}/${GO_TARBALL}"
  if [ -d /etc/profile.d ] && $SUDO bash -lc 'touch /etc/profile.d/go.sh 2>/dev/null'; then
    $SUDO bash -lc 'echo "export PATH=\$PATH:/usr/local/go/bin" > /etc/profile.d/go.sh'
  else
    if ! grep -q '/usr/local/go/bin' "${HOME}/.profile" 2>/dev/null; then
      echo 'export PATH=$PATH:/usr/local/go/bin' >> "${HOME}/.profile"
    fi
  fi
  export PATH=$PATH:/usr/local/go/bin
  echo "Go $(go version) installed."
else
  echo "==> Go already installed: $(go version)"
fi

# ----------------------
# Build geth from source
# ----------------------
echo "==> Downloading geth source ${GETH_VERSION}..."
wget -q "${GETH_ZIP_URL}" -O "${WORKDIR}/geth.zip"
unzip -q "${WORKDIR}/geth.zip" -d "${WORKDIR}"
SRC_DIR="${WORKDIR}/go-ethereum-$(echo ${GETH_VERSION} | sed 's/^v//')"

echo "==> Building geth (this may take a few minutes)..."
pushd "$SRC_DIR" >/dev/null
make geth
popd >/dev/null

echo "==> Installing geth binary to /usr/local/bin..."
$SUDO install -m 0755 "${SRC_DIR}/build/bin/geth" /usr/local/bin/geth

# ----------------------
# Cleanup
# ----------------------
rm -rf "${WORKDIR}"

# ----------------------
# Fetch Cygnus genesis
# ----------------------
mkdir -p "${CYGNUS_DATADIR}"
TMP_REPO="$(mktemp -d)"
git clone --depth 1 https://github.com/cygnus-chain/node "${TMP_REPO}"
cp "${TMP_REPO}/genesis.json" "${CYGNUS_DATADIR}/genesis.json"
rm -rf "${TMP_REPO}"

# ----------------------
# Init chain
# ----------------------
if [ ! -f "${CYGNUS_DATADIR}/geth/chaindata/CURRENT" ]; then
  echo "==> Initializing chain..."
  geth --datadir "${CYGNUS_DATADIR}" init "${CYGNUS_DATADIR}/genesis.json"
fi

# ----------------------
# Static peers
# ----------------------
echo "==> Writing static-nodes.json..."
STATIC_NODES_PATH="${CYGNUS_DATADIR}/geth/static-nodes.json"
printf '%s\n' "[$(printf '"%s",' "${BOOTNODES[@]}" | sed 's/,$//')]" > "${STATIC_NODES_PATH}"

# ----------------------
# Wrapper
# ----------------------
echo "==> Installing cygnusd wrapper..."
$SUDO tee /usr/local/bin/cygnusd >/dev/null <<EOF
#!/usr/bin/env bash
exec /usr/local/bin/geth \\
  --datadir "${CYGNUS_DATADIR}" \\
  --networkid "${CYGNUS_NETWORKID}" \\
  --port "${CYGNUS_P2P_PORT}" \\
  --nat any \\
  --http --http.addr 0.0.0.0 --http.port "${CYGNUS_HTTP_PORT}" --http.api personal,eth,net,web3,miner \\
  --ws --ws.addr 0.0.0.0 --ws.port "${CYGNUS_WS_PORT}" --ws.api personal,eth,net,web3,miner \\
  --maxpeers 50 \\
  --syncmode "snap" \\
  --cache 1024 \\
  --verbosity 3
EOF
$SUDO chmod +x /usr/local/bin/cygnusd

# ----------------------
# systemd service
# ----------------------
echo "==> Creating systemd service..."
$SUDO tee /etc/systemd/system/cygnusd.service >/dev/null <<EOF
[Unit]
Description=Cygnus blockchain node
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cygnusd
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# ----------------------
# Peer healthcheck
# ----------------------
echo "==> Creating peer healthcheck..."
$SUDO tee /usr/local/bin/cygnus-peercheck >/dev/null <<'EOF'
#!/usr/bin/env bash
DATADIR="${HOME}/cygnus_data"
BOOTNODES=('enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303')
IPC="${DATADIR}/geth.ipc"
PEERS=$(geth attach ipc:${IPC} --exec 'admin.peers.length' 2>/dev/null || echo 0)
if [ -z "$PEERS" ] || [ "$PEERS" -lt 1 ]; then
  for en in "${BOOTNODES[@]}"; do
    geth attach ipc:${IPC} --exec "admin.addPeer(\"${en}\")" >/dev/null 2>&1 || true
  done
fi
EOF
$SUDO chmod +x /usr/local/bin/cygnus-peercheck

$SUDO tee /etc/systemd/system/cygnus-peercheck.service >/dev/null <<EOF
[Unit]
Description=Cygnus peer auto-connect

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cygnus-peercheck
EOF

$SUDO tee /etc/systemd/system/cygnus-peercheck.timer >/dev/null <<EOF
[Unit]
Description=Run Cygnus peer auto-connect every 2 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Unit=cygnus-peercheck.service

[Install]
WantedBy=timers.target
EOF

# ----------------------
# Enable services
# ----------------------
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now cygnusd.service
$SUDO systemctl enable --now cygnus-peercheck.timer

echo "✅ Cygnus node installed, running, and auto-peering."
echo "Check logs: sudo journalctl -u cygnusd -f"