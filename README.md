# 🚀 Cygnus Blockchain Node Installer

**Automated installer for Debian/Ubuntu systems to run a full Cygnus blockchain node.**
This script installs dependencies, builds Go and Geth, initializes the blockchain, and sets up systemd services for automatic node start and peer management.

---

## 🧩 Features

* ✅ Installs required system dependencies (`curl`, `wget`, `git`, `gcc`, etc.)
* ✅ Builds and installs Go and Geth from source
* ✅ Initializes blockchain data directory with Cygnus genesis
* ✅ Configures static bootnodes for stable connectivity
* ✅ Installs `cygnusd` systemd service for easy node management
* ✅ Sets up systemd services for node and automatic peer connection

---

## ⚙️ Prerequisites

* Debian / Ubuntu (tested)
* User with `sudo` privileges
* Internet connection

> The installer handles missing dependencies automatically.

---

## 💻 Installation

```bash
# Clone Cygnus repository and navigate into it
git clone https://github.com/cygnus-chain/node
cd node
chmod +x installer.sh

# Run installer
./installer.sh
```

**During installation, the script will:**

1. Install system dependencies
2. Install Go if missing
3. Download & build Geth (`v1.10.23`)
4. Use the cloned Cygnus genesis repository
5. Initialize blockchain data in `$HOME/cygnus_data`
6. Configure static bootnodes
7. Install the `cygnusd` systemd service
8. Set up the peer auto-connect service (`cygnus-peercheck.timer`)

---

## 🔑 Post-Installation

### 1. Create a Wallet

```bash
geth account new --datadir $HOME/cygnus_data
```

> ⚠️ Store your password securely. It cannot be recovered if lost.

### 2. Start Your Node

```bash
sudo systemctl start cygnusd
sudo systemctl status cygnusd
```

* No CLI wrapper needed; the service runs `cygnusd` automatically.
* Logs can be viewed with:

```bash
sudo journalctl -u cygnusd -f
```

---

## ⛏️ Mining

Start mining by editing the `cygnusd` service options or running directly:

```bash
geth --datadir "$HOME/cygnus_data" --networkid 235 --mine --miner.threads=1 --miner.etherbase=0xYourWallet
```

> Replace `0xYourWallet` with your wallet address.

---

## 📦 Systemd Services

### Node Service (`cygnusd.service`)

* Starts node on boot
* Restarts automatically on failure
* Log inspection:

```bash
sudo journalctl -u cygnusd -f
```

### Peer Auto-connect (`cygnus-peercheck.timer`)

* Checks & reconnects to bootnodes every 2 minutes
* Ensures stable network connectivity

```bash
sudo systemctl status cygnus-peercheck.timer
```

---

## 🔗 Bootnodes & Peering

The script configures static bootnodes to ensure your node can sync reliably. Auto-peering reconnects nodes in case of disconnections.

---

## 📂 File Structure

```
$HOME/cygnus_data/
├── geth/
│   ├── chaindata/
│   ├── logs/
│   └── static-nodes.json
└── genesis.json
```

* `geth/` → node data and chain database
* `genesis.json` → network genesis configuration
* `static-nodes.json` → preconfigured bootnodes

---

## ✅ Verification

Check Geth version:

```bash
geth version
```

Check node logs:

```bash
sudo journalctl -u cygnusd -f
```

---

## 📌 Notes

* Supports Debian/Ubuntu only
* Ports used: HTTP `6228`, WS `8291`, P2P `30303` (customizable)
* Network ID: `235` (Cygnus network)
* Maximum peers: 50
* Sync mode: `snap` (fast sync)

---

✅ Cygnus node installed, running, and auto-peering.
