# Cygnus Node (Mainnet)

Run a Cygnus full node and optionally mine using Geth **v1.10.23**.

## Requirements
- Ubuntu/Debian
- 2 GB RAM, 10 GB disk (minimum)
- Internet access, ports 30303 (p2p) and 8545 (optional HTTP RPC)

## Quickstart
```bash
# Clone
git clone https://github.com/cygnus-chain/node
cd node

# Install
chmod +x installer.sh cli.sh
./installer.sh

# Create an account (choose a strong password and store it securely)
geth account new --datadir $HOME/cygnus_data

# Run a node (HTTP enabled)
./cli.sh --http --http.addr "0.0.0.0" --http.port 8545 --port 30303

# Start mining (replace with YOUR address)
./cli.sh --http --http.addr "0.0.0.0" --http.port 8545 --port 30303 \
  --mine --miner.threads=1 --miner.etherbase=0xYourWallet
