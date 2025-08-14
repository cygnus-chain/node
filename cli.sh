#!/usr/bin/env bash
set -euo pipefail

CHAINID=235
DATADIR="${HOME}/cygnus_data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENESIS="${SCRIPT_DIR}/genesis.json"

if [ ! -f "$GENESIS" ]; then
  echo "genesis.json not found next to cli.sh at $GENESIS" >&2
  exit 1
fi

# Initialize the datadir once
if [ ! -d "${DATADIR}/geth/chaindata" ]; then
  echo "==> Initializing datadir with genesis..."
  geth --datadir "${DATADIR}" init "${GENESIS}"
fi

# Pass through all user flags to geth
exec geth --datadir "${DATADIR}" --networkid "${CHAINID}" "$@"
