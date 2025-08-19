# ========================================
# Cygnus Node Windows Installer (PowerShell)
# ========================================

$ErrorActionPreference = "Stop"

# ----------------------
# CONFIG
# ----------------------
$CYGNUS_DATADIR = "$env:USERPROFILE\cygnus_data"
$GETH_VERSION   = "v1.11.33.1"
$GETH_ZIP_URL   = "https://github.com/cygnus-chain/core/archive/refs/tags/$GETH_VERSION.zip"
$CYGNUS_NETWORKID = "235"
$CYGNUS_HTTP_PORT = "6228"
$CYGNUS_WS_PORT   = "8291"
$CYGNUS_P2P_PORT  = "30303"
$BOOTNODES = @(
    "enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303"
)

$INSTALL_DIR = "C:\Program Files\Cygnus"
$WORKDIR = Join-Path $env:TEMP "cygnus_build"

if (!(Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR | Out-Null
}

# ----------------------
# Download & Build
# ----------------------
Write-Host "==> Downloading Cygnus core $GETH_VERSION ..."
Invoke-WebRequest -Uri $GETH_ZIP_URL -OutFile "$WORKDIR.zip"
Expand-Archive "$WORKDIR.zip" -DestinationPath $WORKDIR -Force
$SRC_DIR = Get-ChildItem $WORKDIR | Where-Object { $_.PSIsContainer -and $_.Name -like "core-*" } | Select-Object -First 1

Write-Host "==> Building geth.exe (requires Go installed)..."
Push-Location $SRC_DIR.FullName
go run build/ci.go install ./cmd/geth
Pop-Location

Copy-Item "$SRC_DIR\build\bin\geth.exe" "$INSTALL_DIR\geth.exe" -Force

# ----------------------
# Init Chain
# ----------------------
Write-Host "==> Fetching Cygnus genesis..."
if (!(Test-Path $CYGNUS_DATADIR)) { New-Item -ItemType Directory -Path $CYGNUS_DATADIR | Out-Null }
git clone --depth 1 https://github.com/cygnus-chain/node.git "$WORKDIR\node"
Copy-Item "$WORKDIR\node\genesis.json" "$CYGNUS_DATADIR\genesis.json" -Force

if (!(Test-Path "$CYGNUS_DATADIR\geth\chaindata\CURRENT")) {
    Write-Host "==> Initializing chain..."
    & "$INSTALL_DIR\geth.exe" --datadir "$CYGNUS_DATADIR" init "$CYGNUS_DATADIR\genesis.json"
}

# ----------------------
# Static Peers
# ----------------------
$STATIC_PATH = "$CYGNUS_DATADIR\geth\static-nodes.json"
$BOOTSTRAP = "[" + ($BOOTNODES | ForEach-Object { "`"$_`"" }) -join "," + "]"
Set-Content -Path $STATIC_PATH -Value $BOOTSTRAP

# ----------------------
# Mining Setup
# ----------------------
$MINING_FLAGS = ""
Write-Host "`nDo you want to enable mining?"
Write-Host "1) CPU mining with geth"
Write-Host "2) External ASIC/GPU miner (Ethminer, PhoenixMiner, lolMiner)"
Write-Host "3) No mining (default)"
$choice = Read-Host "Choose option [1-3]"

if ($choice -eq "1") {
    $ETHERBASE = Read-Host "Enter your Cygnus wallet address for rewards"
    $THREADS   = Read-Host "Enter number of CPU threads to use [default: 1]"
    if ([string]::IsNullOrEmpty($THREADS)) { $THREADS = "1" }
    $MINING_FLAGS = "--mine --miner.threads=$THREADS --miner.etherbase=$ETHERBASE"
} elseif ($choice -eq "2") {
    Write-Host "✅ Node will sync and serve work to an external miner."
    Write-Host "   Connect miners to: http://localhost:$CYGNUS_HTTP_PORT"
}

# ----------------------
# cygnusd.bat Wrapper
# ----------------------
$WRAPPER = @"
@echo off
"$INSTALL_DIR\geth.exe" ^
  --datadir "$CYGNUS_DATADIR" ^
  --networkid $CYGNUS_NETWORKID ^
  --port $CYGNUS_P2P_PORT ^
  --http --http.addr 0.0.0.0 --http.port $CYGNUS_HTTP_PORT --http.api personal,eth,net,web3,miner,engine,debug,txpool ^
  --ws --ws.addr 0.0.0.0 --ws.port $CYGNUS_WS_PORT --ws.api personal,eth,net,web3,miner,engine,debug,txpool ^
  --maxpeers 50 ^
  --syncmode snap ^
  --cache 2048 ^
  --verbosity 3 ^
  $MINING_FLAGS
"@
Set-Content "$INSTALL_DIR\cygnusd.bat" $WRAPPER -Encoding ASCII

# ----------------------
# Windows Service (NSSM)
# ----------------------
Write-Host "==> Installing Cygnus as a Windows service..."
$nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
$nssmZip = "$env:TEMP\nssm.zip"
$nssmDir = "$env:ProgramFiles\nssm"

Invoke-WebRequest $nssmUrl -OutFile $nssmZip
Expand-Archive $nssmZip -DestinationPath $env:TEMP -Force
Copy-Item "$env:TEMP\nssm-2.24\win64\nssm.exe" $nssmDir -Force

& "$nssmDir\nssm.exe" install Cygnus "$INSTALL_DIR\cygnusd.bat"
& "$nssmDir\nssm.exe" set Cygnus Start SERVICE_AUTO_START
& "$nssmDir\nssm.exe" start Cygnus

# ----------------------
# Peercheck.ps1
# ----------------------
$PEERCHECK = @"
`$datadir = "$CYGNUS_DATADIR"
`$ipc = "$CYGNUS_DATADIR\geth.ipc"
`$bootnodes = @(
    "enode://89714f18d2d4500790b1b2b7c4e286736987b2cd414c16a305a5767f2631fe4a179b6f54b1aecbe5de1ccce11fd19f65c407553841ff950bfd482ac8bc498293@88.99.217.236:30303"
)
try {
    `$peers = & "$INSTALL_DIR\geth.exe" attach ipc:`$ipc --exec "admin.peers.length"
} catch { `$peers = 0 }
if (-not `$peers -or `$peers -lt 1) {
    foreach (`$enode in `$bootnodes) {
        try { & "$INSTALL_DIR\geth.exe" attach ipc:`$ipc --exec "admin.addPeer(`"`$enode`")" | Out-Null } catch {}
    }
}
"@
Set-Content "$INSTALL_DIR\cygnus-peercheck.ps1" $PEERCHECK -Encoding ASCII

# ----------------------
# Scheduled Task
# ----------------------
Write-Host "==> Creating scheduled task for peer healthcheck..."
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$INSTALL_DIR\cygnus-peercheck.ps1`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "CygnusPeerCheck" -Description "Reconnects to bootnodes if no peers" -User "SYSTEM" -RunLevel Highest -Force

Write-Host "✅ Cygnus node installed, running, and auto-peering (Windows service + scheduler ready)."
