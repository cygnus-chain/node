# Cygnus Node Installation Guide

This repository contains the necessary files to install and run a Cygnus blockchain node. The node includes `boot.key`, `genesis.json`, and scripts for installation and setup.

## Prerequisites

* Linux-based OS (Ubuntu/Debian recommended)
* `curl`, `wget`, `tar` installed
* At least 2GB RAM
* 20GB free disk space
* Open ports: 30303 (P2P), 6228 (HTTP), 8291 (WebSocket)

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/cygnus-chain/node.git
cd node
chmod +x installer.sh
./installer.sh
```

The `installer.sh` script will:

* Install Geth v1.10.23
* Install Go if not present
* Set up the `~/cygnus_data` directory
* Place the `genesis.json` and `boot.key`
* Create a default Ethereum account and save the password in `~/cygnus_data/password.txt`

## Initialize the Blockchain

After installation, initialize your node with the provided genesis block:

```bash
geth --datadir ~/cygnus_data init ~/node/genesis.json
```

This will prepare the local data directory for blockchain synchronization.

## Running the Node

Start the node with mining enabled and connect to the bootnode:

```bash
geth --datadir ~/cygnus_data \
    --networkid 235 \
    --bootnodes "enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303" \
    --port 30303 \
    --nat any \
    --http --http.addr 0.0.0.0 --http.port 6228 --http.api personal,eth,net,web3,miner \
    --ws --ws.addr 0.0.0.0 --ws.port 8291 --ws.api personal,eth,net,web3,miner \
    --allow-insecure-unlock \
    --unlock "Your_eth_account_wallet_address" --password ~/cygnus_data/password.txt \
    --mine --miner.threads 1 \
    --verbosity 4 \
    --nodiscover=false
```

Replace `<YOUR_ACCOUNT_ADDRESS>` with the Ethereum account created during installation.

## Adding Trusted Peers

If needed, you can manually add the trusted bootnode to ensure connectivity:

```javascript
> admin.addPeer("enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303")
true
```

Check the connected peers:

```javascript
> admin.peers
```

You should see the bootnode listed in the output.

## Verifying Node Status

Check current block number:

```javascript
> eth.blockNumber
```

Check coinbase (mining address):

```javascript
> eth.coinbase
```

## Notes

* Make sure ports are open and accessible if running behind NAT/firewall.
* Mining with one thread is default; adjust `--miner.threads` as needed.
* Your Ethereum account is unlocked only while the node is running; the password is stored in `~/cygnus_data/password.txt`.

This setup ensures your node is connected, mining, and synchronized with the Cygnus network.
