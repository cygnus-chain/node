#!/bin/bash
set -e

# ===== Prompt User =====
read -p "Enter your node account address (0x...): " NODE_ACCOUNT
read -p "Enter the path to your node password file: " PASS_FILE
read -p "Peer with default/main node? (y/n): " PEER_DEFAULT

if [[ "$PEER_DEFAULT" == "y" || "$PEER_DEFAULT" == "Y" ]]; then
    NODE1_ENODE="enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303"
else
    read -p "Enter the enode URL to peer with: " NODE1_ENODE
fi

# ===== Configs =====
DATA_DIR=~/cygnus_data
GENESIS_JSON=~/node/genesis.json

# ===== Create Data Dir =====
mkdir -p "$DATA_DIR"

# ===== Initialize Genesis =====
echo "Initializing genesis block..."
rm -rf "$DATA_DIR/geth/chaindata" 2>/dev/null || true
geth --datadir "$DATA_DIR" init "$GENESIS_JSON"

# ===== Start Node in Screen =====
echo "Starting geth node in background..."
screen -dmS cygnus_node geth \
  --datadir "$DATA_DIR" \
  --networkid 235 \
  --http --http.addr 0.0.0.0 --http.port 6230 --http.api personal,eth,net,web3,miner \
  --ws --ws.addr 0.0.0.0 --ws.port 8293 --ws.api personal,eth,net,web3,miner \
  --port 30303 \
  --nat=any \
  --allow-insecure-unlock \
  --unlock "$NODE_ACCOUNT" \
  --password "$PASS_FILE" \
  --mine --miner.threads 1 \
  --ipcdisable=false

# ===== Wait for Node IPC =====
echo "Waiting for node to start..."
until geth attach "$DATA_DIR/geth.ipc" --exec "eth.blockNumber" &>/dev/null; do
  sleep 2
done

# ===== Add Peer =====
echo "Adding peer..."
geth attach "$DATA_DIR/geth.ipc" --exec "admin.addPeer('$NODE1_ENODE')"

# ===== Wait for Peer Connection =====
echo "Waiting for peer connection..."
until [ "$(geth attach "$DATA_DIR/geth.ipc" --exec "admin.peers.length")" -gt 0 ]; do
  sleep 2
done

# ===== Wait Until Blocks > 6000 =====
echo "Waiting for blockchain to sync past block 6000..."
until [ "$(geth attach "$DATA_DIR/geth.ipc" --exec "eth.blockNumber")" -ge 6000 ]; do
  sleep 5
done

# ===== Configure UFW =====
echo "Configuring firewall..."
ufw allow 30303/tcp
ufw allow 30303/udp
ufw allow 6230/tcp
ufw allow 8293/tcp
ufw reload

echo "Cygnus node is up, synced past block 6000, and peered successfully!"
echo "Use 'screen -r cygnus_node' to see logs or 'geth attach $DATA_DIR/geth.ipc' to interact."
