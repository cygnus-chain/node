# Cygnus Node Installer

Welcome to the **Cygnus Node** repository! This project provides an automated setup for running a full Cygnus blockchain node, including automatic peer connection, mining, and firewall configuration. The goal is to make launching and managing your Cygnus node fast, safe, and fully automated.

Repository: [https://github.com/cygnus-chain/node](https://github.com/cygnus-chain/node)

---

## Table of Contents

* [Overview](#overview)
* [Features](#features)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Usage](#usage)
* [Scripts](#scripts)
* [Node Syncing & Peering](#node-syncing--peering)
* [Firewall & Networking](#firewall--networking)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)
* [Support](#support)

---

## Overview

Cygnus Node is designed for blockchain enthusiasts, developers, and validators who want to easily run a full Cygnus blockchain node. It handles:

* Node initialization from a genesis file
* Running Geth in the background
* Automatic peer connection to main or custom nodes
* Mining configuration
* UFW firewall configuration for ports
* Automatic sync check for blocks

---

## Features

* Fully automated **node setup and configuration**
* Minimal user input: only account address, password file, and peer choice
* Background execution using `screen`
* Real-time **peer connection verification**
* Automatic **block sync check** (waits for block height > 6000)
* Built-in **firewall configuration** for secure networking

---

## Prerequisites

Before running the node, ensure you have:

* Ubuntu / Debian 64-bit server
* `geth` installed (v1.10.23 recommended)
* `screen` installed (`sudo apt install screen`)
* UFW enabled (`sudo ufw enable`)
* Genesis file available at `~/node/genesis.json`
* Node account created with keystore and password file

---

## Installation

Clone the repository:

```bash
git clone https://github.com/cygnus-chain/node.git
cd node
chmod +x installer.sh node.sh
```

The repository contains:

* `installer.sh` → Installs Geth, Go, and sets up environment
* `node.sh` → Wizard for creating and running a Cygnus node

---

## Usage

Run the node setup wizard:

```bash
./node.sh
```

You will be prompted to enter:

1. **Node account address** (e.g., `0x4608dfe66f785df639efbf60f487ace4cdc163d3`)
2. **Path to password file** (e.g., `~/cygnus_data/password.txt`)
3. **Peer choice** – either default/main node or a custom enode URL

The script will:

* Create the `cygnus_data` directory
* Initialize the genesis block
* Start the node in a `screen` session
* Add the peer node automatically
* Wait until the blockchain syncs past block 6000
* Configure UFW firewall for necessary ports

To attach to the node logs:

```bash
screen -r cygnus_node
```

To interact with the node via Geth console:

```bash
geth attach ~/cygnus_data/geth.ipc
```

---

## Scripts

### installer.sh

Installs all dependencies required for the Cygnus node:

* Geth (Ethereum client)
* Go language runtime
* Required libraries and utilities

### node.sh

The main wizard for:

* Node initialization
* Background node execution
* Peer addition and verification
* Blockchain sync check
* Automatic firewall configuration

---

## Node Syncing & Peering

After running `node.sh`:

* The node automatically connects to a main/default peer or custom enode URL
* Peer connections can be verified:

```javascript
> admin.peers
```

* Node will automatically wait until blockchain reaches **block number 6000+** to ensure sync is working
* Mining is automatically started with one thread

---

## Firewall & Networking

The following ports are automatically opened:

| Protocol | Port  | Description             |
| -------- | ----- | ----------------------- |
| TCP/UDP  | 30303 | Ethereum P2P networking |
| TCP      | 6230  | HTTP RPC                |
| TCP      | 8293  | WebSocket RPC           |

Firewall is configured using `ufw`, ensuring your node is reachable by peers but protected from unwanted traffic.

---

## Troubleshooting

* **Node does not sync**: check that the genesis file matches the main network
* **Peers not connecting**: ensure firewall allows 30303 TCP/UDP and the enode URL is correct
* **Node fails to start**: remove old chain data:

```bash
rm -rf ~/cygnus_data/geth/chaindata
```

and re-run `node.sh`.

* **Check logs**:

```bash
screen -r cygnus_node
```

---

## Contributing

We welcome contributions! Please submit pull requests for:

* Bug fixes
* Feature enhancements
* Updated scripts for new Geth versions

Before submitting, ensure:

* Scripts work end-to-end
* Proper permissions are set (`chmod +x`)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Support

For support, visit our official website: [https://cygnuschain.com](https://cygnuschain.com)

Cygnus Node — **Run a full Cygnus blockchain node effortlessly!**
