#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# CONFIG
# ----------------------
CYGNUS_DATADIR="${HOME}/cygnus_data"
GETH_VERSION="v1.11.33.2"
GETH_ZIP_URL="https://github.com/cygnus-chain/core/archive/refs/tags/${GETH_VERSION}.zip"
CYGNUS_NETWORKID="235"   # Cygnus network ID
CYGNUS_HTTP_PORT="6228"
CYGNUS_WS_PORT="8291"
CYGNUS_P2P_PORT="30303"
BOOTNODES=(
  'enode://404245728d5d24c06b58c5e809809a30302c8560aff1f9adfacedb3c50dafae1f417b459e190110ca797eda564a3f9dee1a79385bb467d5a481d685ff70aaa3f@88.99.217.236:30303'
  'enode://e55e59b560037cbb65c8679a737260b971a310a4e4953001dc3bb017d2c108e005bf0cde23485b25db3a51448ae2ea176903ad7e1f8045f1a6199029fe7812f1@51.15.18.216:30306'
)
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
$SUDO apt install -y curl wget unzip build-essential make gcc ca-certificates git openssl

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

  if [ -d /etc/profile.d ] && $SUDO bash -lc "touch /etc/profile.d/go.sh 2>/dev/null" ; then
    $SUDO bash -lc "echo 'export PATH=\$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh"
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
# Build geth from core fork
# ----------------------
echo "==> Downloading core source ${GETH_VERSION}..."
wget -q "${GETH_ZIP_URL}" -O "${WORKDIR}/geth.zip"
unzip -q "${WORKDIR}/geth.zip" -d "${WORKDIR}"
SRC_DIR="$(find "${WORKDIR}" -maxdepth 1 -type d -name 'core-*' | head -n 1)"
echo "==> Using source directory: ${SRC_DIR}"

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
git clone --depth 1 https://github.com/cygnus-chain/node.git "${TMP_REPO}"
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
# Static nodekey
# ----------------------
NODEKEY_FILE="${CYGNUS_DATADIR}/geth/nodekey-static"
if [ ! -f "$NODEKEY_FILE" ]; then
  echo "🔑 Generating static nodekey..."
  mkdir -p "${CYGNUS_DATADIR}/geth"
  openssl rand -hex 32 > "$NODEKEY_FILE"
  chmod 600 "$NODEKEY_FILE"
else
  echo "✅ Static nodekey already exists: $NODEKEY_FILE"
fi

# ----------------------
# Static peers
# ----------------------
echo "==> Writing static-nodes.json..."
STATIC_NODES_PATH="${CYGNUS_DATADIR}/geth/static-nodes.json"
printf '%s\n' "[$(printf '"%s",' "${BOOTNODES[@]}" | sed 's/,$//')]" > "${STATIC_NODES_PATH}"

# ----------------------
# Mining setup prompt
# ----------------------
echo "Do you want to enable mining on this node?"
echo "1) CPU mining with geth"
echo "2) Mining pool (GTpool or other stratum pool)"
echo "3) No mining (default)"
read -rp "Choose option [1-3]: " MINING_OPTION || true

ETHERBASE=""
MINER_THREADS="1"
MINING_FLAGS=""
if [ "$MINING_OPTION" = "1" ]; then
  read -rp "Enter your Cygnus wallet address for rewards: " ETHERBASE
  read -rp "Enter number of CPU threads to use [default: 1]: " MINER_THREADS
  MINER_THREADS=${MINER_THREADS:-1}
  MINING_FLAGS="--mine --miner.threads=${MINER_THREADS} --miner.etherbase=${ETHERBASE}"

elif [ "$MINING_OPTION" = "2" ]; then
  read -rp "Enter your Cygnus wallet address for pool payouts: " ETHERBASE
  read -rp "Enter stratum pool URL (default: stratum+tcp://eu.gtpool.io:8008): " POOL_URL
  POOL_URL=${POOL_URL:-"stratum+tcp://eu.gtpool.io:8008"}

  echo
  echo "✅ Your node will sync the chain, but mining will be done via pool."
  echo "   Example run (ethminer):"
  echo "   ethminer -P stratum1+tcp://$ETHERBASE@$POOL_URL"
  echo
  echo "⚠️ Reminder: You must install ethminer/lolminer manually to actually mine."
  MINING_FLAGS=""

else
  echo "✅ Running as a full node only (no mining)."
fi

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
  --nodekey "${NODEKEY_FILE}" \\
  --bootnodes "$(IFS=,; echo "${BOOTNODES[*]}")" \\
  --http --http.addr 0.0.0.0 --http.port "${CYGNUS_HTTP_PORT}" --http.api personal,eth,net,web3,miner,engine,debug,txpool \\
  --ws --ws.addr 0.0.0.0 --ws.port "${CYGNUS_WS_PORT}" --ws.api personal,eth,net,web3,miner,engine,debug,txpool \\
  --maxpeers 50 \\
  --syncmode "snap" \\
  --cache 2048 \\
  --verbosity 3 \\
  --authrpc.port 8551 --authrpc.addr 0.0.0.0 --authrpc.vhosts="*" --authrpc.jwtsecret "${CYGNUS_DATADIR}/geth/jwtsecret" \\
  ${MINING_FLAGS}
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
BOOTNODES=(
  'enode://404245728d5d24c06b58c5e809809a30302c8560aff1f9adfacedb3c50dafae1f417b459e190110ca797eda564a3f9dee1a79385bb467d5a481d685ff70aaa3f@88.99.217.236:30303'
  'enode://e55e59b560037cbb65c8679a737260b971a310a4e4953001dc3bb017d2c108e005bf0cde23485b25db3a51448ae2ea176903ad7e1f8045f1a6199029fe7812f1@51.15.18.216:30306'
)
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

# ----------------------
# Show enode
# ----------------------
echo "==> Fetching this node's enode..."
sleep 5
ENODE=$(geth --datadir "${CYGNUS_DATADIR}" --nodekey "${NODEKEY_FILE}" --ipcdisable --exec "admin.nodeInfo.enode" console 2>/dev/null | tr -d '"')
echo "==================================================="
echo "✅ Cygnus v${GETH_VERSION} node installed, running!"
echo "Check logs: sudo journalctl -u cygnusd -f"
echo
echo "🔗 Your permanent enode ID:"
echo "${ENODE}"
echo "==================================================="
