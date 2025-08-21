# Cygnus Node Installer

This repository contains a complete installer for running a Cygnus blockchain node. It builds the Cygnus Geth binary, sets up your datadir, static peers, mining options, and systemd services for automatic startup.

GitHub URL: [https://github.com/cygnus-chain/node](https://github.com/cygnus-chain/node)

---

## Features

* Builds and installs Cygnus core v1.11.33.2 with dapp/defi support activation at block 100,000 .
* Automatically initializes the chain using genesis.json.
* Static peer configuration for consistent P2P connectivity.
* Optional CPU or external mining setup.
* Systemd service for automatic node startup.
* Peer healthcheck timer to auto-connect to bootnodes.
* Safe upgrade path — preserves existing blockchain data.

---

## Prerequisites

* Ubuntu / Debian Linux (supported versions only).
* At least 2 GB RAM recommended.
* Internet access for downloading Go and source code.

---

## Installation

1. Clone the repository:

```bash
git clone https://github.com/cygnus-chain/node.git
cd node
```

2. Run the installer:

```bash
chmod +x installer.sh
./installer.sh
```

3. Installer steps:

* Installs build dependencies and Go if missing.
* Downloads and builds the Cygnus Geth binary.
* Copies genesis.json to your data directory (`~/cygnus_data`).
* Initializes the chain if this is a fresh node.
* Configures static peers and optional mining settings.
* Installs a `cygnusd` wrapper script and systemd service.
* Installs a `cygnus-peercheck` timer for automatic peer connection.

---

## Running the Node

After installation, the node runs automatically via systemd:

```bash
sudo systemctl status cygnusd
sudo journalctl -u cygnusd -f
```

Check peer connectivity:

```bash
geth attach ipc:~/cygnus_data/geth.ipc
> admin.peers
```

Check current block and coinbase balance:

```javascript
> eth.blockNumber
> web3.fromWei(eth.getBalance(eth.coinbase), "ether")
```

---

## Mining Options

During installation, you can choose:

1. **CPU mining**

   * Enter your Cygnus wallet address for rewards.
   * Set number of CPU threads to use.

2. **No mining**

   * Node will just sync and serve the network.

---

## Upgrading Existing Nodes

1. Backup your existing datadir:

```bash
cp -r ~/cygnus_data ~/cygnus_data-backup
```

2. Stop the current node:

```bash
sudo systemctl stop cygnusd
```

3. Run `installer.sh` — it will detect the existing chain and preserve all blocks.

4. Start the upgraded node:

```bash
sudo systemctl start cygnusd
```

---

## Static Peers / Bootnodes

* Main node enode:

```text
enode://b9dd4eaea2f0f6fc193b3225c98590121cc03784788c2dded6d6c516007f6d06dc32f9b33fb2f084cdc71d05b5b035128d218c2cf1f4e44d8dda412078816901@88.99.217.236:30303
```

* Can be added manually in `static-nodes.json`:

```json
[
  "enode://b9dd4eaea2f0f6fc193b3225c98590121cc03784788c2dded6d6c516007f6d06dc32f9b33fb2f084cdc71d05b5b035128d218c2cf1f4e44d8dda412078816901@88.99.217.236:30303"
]
```

* Any node using this installer will auto-connect to the main node.

---

## Connecting via IPC

```bash
geth attach ipc:~/cygnus_data/geth.ipc
```

* This allows you to run commands in the Geth JS console.
* Examples:

```javascript
> eth.blockNumber
> admin.peers
> eth.getBalance(eth.coinbase)
```

---

## Systemd Services

* `cygnusd.service` → runs the node continuously and auto-restarts.
* `cygnus-peercheck.timer` → runs every 2 minutes to reconnect peers if disconnected.

Check status:

```bash
sudo systemctl status cygnusd
sudo systemctl status cygnus-peercheck.timer
```

---

## Notes

* All nodes using this installer will automatically peer with the main bootnode.
* The installer script can be safely run multiple times — it detects existing chains and preserves them.
