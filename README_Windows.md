# Cygnus Node Installer (Windows)

This repository contains a complete installer for running a **Cygnus blockchain node** on Windows.
It builds the Cygnus Geth binary, sets up your datadir, static peers, mining options, and ensures your node ID (`enode`) does not change across restarts.

GitHub URL: [https://github.com/cygnus-chain/node](https://github.com/cygnus-chain/node)

---

## Features

* Builds and installs Cygnus core v1.11.33.2 with dapp/defi support activation at block 100,000.
* Automatically initializes the chain using `genesis.json`.
* Static peer configuration for consistent P2P connectivity.
* Optional CPU mining setup.
* Auto-start node with `.bat` script or Task Scheduler.
* Persistent `nodekey` → enode ID stays fixed across restarts.
* Safe upgrade path — preserves existing blockchain data.

---

## Prerequisites

* Windows 10 / 11 (64-bit).
* At least 2 GB RAM recommended.
* Installed:

  * [Go](https://go.dev/dl/)
  * [Git for Windows](https://git-scm.com/download/win)
  * [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)

---

## Installation

1. Clone the repository:

```powershell
git clone https://github.com/cygnus-chain/node.git
cd node
```

2. Run the installer script:

```powershell
.\installer.ps1
```

3. Installer steps:

* Installs build dependencies if missing.
* Builds the Cygnus Geth binary.
* Copies `genesis.json` to your data directory (`C:\cygnus_data`).
* Initializes the chain if fresh install.
* Configures static peers and optional mining settings.
* Generates a **persistent nodekey** if missing:

```powershell
openssl rand -hex 32 | Out-File -Encoding ascii C:\cygnus_data\geth\nodekey-static
```

---

## Running the Node

Start the node manually:

```powershell
.\cygnusd.bat
```

Or configure **Task Scheduler** for automatic startup at boot.

Check logs (inside `C:\cygnus_data\logs`).

---

## Mining Options

During installation, you can choose:

1. **CPU mining**

   * Enter your Cygnus wallet address for rewards.
   * Choose number of CPU threads to mine with.

2. **No mining**

   * Node will just sync and validate the chain.

---

## Upgrading Existing Nodes

1. Backup your existing datadir:

```powershell
Copy-Item -Recurse C:\cygnus_data C:\cygnus_data-backup
```

2. Stop the node (`Ctrl+C` or stop Task Scheduler job).

3. Run `installer.ps1` — it will detect existing chain and preserve blocks.

4. Restart node:

```powershell
.\cygnusd.bat
```

---

## Static Peers / Bootnodes

* Main node enode:

```text
enode://404245728d5d24c06b58c5e809809a30302c8560aff1f9adfacedb3c50dafae1f417b459e190110ca797eda564a3f9dee1a79385bb467d5a481d685ff70aaa3f@88.99.217.236:30303
```

* Can be added manually in `C:\cygnus_data\static-nodes.json`:

```json
[
  "enode://404245728d5d24c06b58c5e809809a30302c8560aff1f9adfacedb3c50dafae1f417b459e190110ca797eda564a3f9dee1a79385bb467d5a481d685ff70aaa3f@88.99.217.236:30303"
]
```

---

## Connecting via IPC

Open Geth console:

```powershell
geth attach \\.\pipe\geth.ipc
```

Examples:

```javascript
> eth.blockNumber
> admin.peers
> eth.getBalance(eth.coinbase)
```

---

## Notes

* Your enode ID is **stable** thanks to `nodekey-static`.
* The installer can be safely run multiple times — it will detect existing chains and preserve data.
* Windows logs are stored in `C:\cygnus_data\logs`.

