#!/usr/bin/env bash
set -euo pipefail

CYGNUS_DATADIR="${HOME}/cygnus_data"
GETH_VERSION="v1.10.23"
GETH_ZIP_URL="https://github.com/ethereum/go-ethereum/archive/refs/tags/${GETH_VERSION}.zip"
WORKDIR="$(mktemp -d)"
SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  SUDO="sudo"
fi

# ---- OS check ----
if [ -f /etc/debian_version ]; then
  PKG_MANAGER="apt"
else
  echo "This installer currently supports Debian/Ubuntu only." >&2
  exit 1
fi

echo "==> Installing build dependencies..."
$SUDO apt update -y
$SUDO apt install -y curl wget unzip build-essential make gcc ca-certificates

# ---- Install Go if missing ----
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
  # Persist PATH
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

# ---- Build geth from the specified zip ----
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

echo "==> Cleaning up..."
rm -rf "${WORKDIR}"

mkdir -p "${CYGNUS_DATADIR}"

echo "==> Verifying installation..."
geth version || { echo "geth not found"; exit 1; }

cat << 'EOM'

✅ Installation complete.

Next steps:

1) Create a wallet account (you will be asked for a password):
   geth account new --datadir $HOME/cygnus_data

IMPORTANT: Store your password securely. It CANNOT be recovered.

2) Initialize and run your node using the CLI wrapper in this repo:
   chmod +x ./cli.sh
   ./cli.sh --http --http.addr "0.0.0.0" --http.port 8545 --port 30303

To mine:
   ./cli.sh --http --http.addr "0.0.0.0" --http.port 8545 --port 30303 --mine --miner.threads=1 --miner.etherbase=0xYourWallet

(Optional) Make the CLI available globally:
   sudo ln -sf "$(pwd)/cli.sh" /usr/local/bin/cygnus-cli
   cygnus-cli --help

EOM
