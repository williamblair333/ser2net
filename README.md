# ser2net-docker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Debian](https://img.shields.io/badge/Debian-Bullseye-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)

> **Serial-to-TCP bridge in Docker with stable device naming**

Expose USB-serial devices over TCP using [ser2net](https://github.com/cminyard/ser2net), with udev rules for persistent naming and optional nginx for logging.

```
USB-Serial Adapter → /dev/cisco0 (udev symlink) → ser2net → TCP:7000
```

⚠️ **This is not a web application.** It gives raw access to serial devices over TCP. Do not expose to untrusted networks.

---

## Table of Contents

- [Features](#features)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [udev Rules](#udev-rules)
  - [Adapters Without Serial Numbers (KERNELS Mode)](#adapters-without-serial-numbers-kernels-mode)
  - [ser2net.conf](#ser2netconf)
  - [docker-compose.yml](#docker-composeyml)
- [Connecting](#connecting)
- [Adding New Adapters](#adding-new-adapters)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| **Stable device names** | udev rules create `/dev/cisco0`, `/dev/cisco1`, etc. based on USB serial number |
| **Dockerized** | Isolated, reproducible deployment |
| **Survives reconnection** | Symlinks persist across reboots and USB re-plugs |
| **Optional logging** | nginx serves a log directory browser on port 80 |
| **Permission handling** | Scripts to fix common ttyUSB permission issues |

---

## Repository Layout

```
.
├── Dockerfile                    # Builds ser2net container (Debian Bullseye)
├── docker-compose.yml            # Orchestrates ser2net + nginx
├── ser2net.conf                  # Port-to-device mapping
├── nginx.conf                    # Log directory browser (optional)
├── z21_persistent-local.rules    # udev rules for stable symlinks
├── udev_set.sh                   # Installs udev rules
├── udev_mapper.sh                # Generates rules from connected devices (serial or KERNELS mode)
├── tty_get.sh                    # Lists detected tty devices
└── ser2net_chmod_ttyUSB.sh       # Emergency permission fix
```

---

## Prerequisites

- Linux host (tested on Debian/MX Linux)
- Docker and docker-compose-v2
- USB-serial adapter(s)
- Root access

```bash
# Install dependencies
sudo apt install docker.io docker-compose-v2

# Add user to required groups (logout/login after)
sudo usermod -aG dialout,docker $USER
```

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/williamblair333/ser2net.git
cd ser2net

# 2. Identify your adapters
./tty_get.sh

# 3. Edit udev rules with your adapter serial numbers
vim z21_persistent-local.rules

# 4. Install udev rules
sudo ./udev_set.sh

# 5. Verify symlinks exist
ls -la /dev/cisco*

# 6. Start containers
docker compose up --build -d

# 7. Test connection
nc <host-ip> 7000
```

---

## Configuration

### udev Rules

The file `z21_persistent-local.rules` creates stable symlinks based on USB serial numbers.

**Get adapter info:**

```bash
for d in /dev/ttyUSB*; do
  echo "=== $d ==="
  udevadm info --name="$d" | grep -E "(ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL_SHORT)"
done
```

**Example output:**

```
=== /dev/ttyUSB0 ===
E: ID_VENDOR_ID=0403
E: ID_MODEL_ID=6001
E: ID_SERIAL_SHORT=A9BPHHWM
```

**Rule format:**

```udev
# Serial-based rule (preferred — survives moving to different USB port)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", \
  ATTRS{serial}=="A9BPHHWM", SYMLINK+="cisco0", MODE="0660", GROUP="dialout"
```

### Adapters Without Serial Numbers (KERNELS Mode)

Some cheap USB-serial adapters (CH340, CH341) don't expose a USB serial number. For these, use **KERNELS mode** which creates rules based on the physical USB port position.

> ⚠️ **Tradeoff:** KERNELS-based rules break if the adapter is moved to a different USB port. Serial-based rules don't have this limitation.

**How to tell if your adapter has a serial:**

```bash
udevadm info --name=/dev/ttyUSB0 | grep ID_SERIAL_SHORT
```

If no output → adapter has no serial → use KERNELS mode.

**Generate KERNELS-based rules:**

```bash
# All adapters
./udev_mapper.sh -k

# Specific adapter
./udev_mapper.sh -k ttyUSB2
```

**Example output:**

```udev
# /dev/ttyUSB2
# Vendor: 1a86  Product: 7523  Serial: NONE
SUBSYSTEM=="tty", KERNELS=="1-1.3.4.4:1.0", \
  SYMLINK+="cisco2", MODE="0660", GROUP="dialout"
```

**Understanding KERNELS values:**

The value `1-1.3.4.4:1.0` represents the physical USB topology:

```
1-1.3.4.4:1.0
│ │ │ │ │ └── Interface number
│ │ │ │ └──── Port on hub
│ │ │ └────── Port on hub
│ │ └──────── Port on hub
│ └────────── Root hub port
└──────────── Bus number
```

If you move the adapter to a different USB port, this path changes and the rule stops matching.

**Best practice:** 

- Use serial-based rules whenever possible
- Reserve KERNELS mode for adapters without serials
- Label physical USB ports so you know which adapter goes where
- Consider replacing cheap adapters with FTDI or CP2102-based ones that have unique serials

**Apply rules:**

```bash
sudo ./udev_set.sh
# or manually:
sudo cp z21_persistent-local.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

### ser2net.conf

Maps TCP ports to device symlinks. Default: 9600 8N1 (Cisco console standard).

```
# FORMAT: PORT:MODE:TIMEOUT:DEVICE:BAUD [OPTIONS]
# TIMEOUT=0 = no idle disconnect
# LOCAL = suppress modem control (required for USB-serial)

7000:raw:0:/dev/cisco0:9600 8DATABITS NONE 1STOPBIT LOCAL
7001:raw:0:/dev/cisco1:9600 8DATABITS NONE 1STOPBIT LOCAL
```

<details>
<summary><strong>Common baud rates</strong></summary>

| Device Type | Baud Rate |
|-------------|-----------|
| Cisco console (default) | 9600 |
| Cisco ISR/ASR (some models) | 115200 |
| Zigbee/Z-Wave sticks | 115200 |
| Generic embedded | 9600 or 115200 |

</details>

---

### docker-compose.yml

```yaml
services:
  nginx:
    image: nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs:/usr/share/nginx/html:ro
    environment:
      - TZ=America/New_York

  ser2net:
    build: .
    restart: unless-stopped
    ports:
      - "10.33.1.38:7000:7000"
      - "10.33.1.38:7001:7001"
    devices:
      - "/dev/cisco0:/dev/cisco0"
      - "/dev/cisco1:/dev/cisco1"
    volumes:
      - ./ser2net.conf:/etc/ser2net.conf:ro
    environment:
      - TZ=America/New_York
```

> **Note:** Replace `10.33.1.38` with your management IP, or use `0.0.0.0` to bind all interfaces.

---

## Connecting

### Quick test

```bash
nc -zv <host> 7000          # Check port is open
nc <host> 7000              # Connect (Ctrl+C to exit)
```

### telnet

```bash
telnet <host> 7000          # Ctrl+] then 'quit' to exit
```

### From applications

```
tcp://<host>:7000
```

> **Important:** Only one client should connect at a time.

### Local access (bypassing Docker)

```bash
screen /dev/cisco0 9600     # Ctrl+A K to kill
minicom -D /dev/cisco0
```

---

## Adding New Adapters

### Quick method (using udev_mapper.sh)

```bash
# 1. Plug in adapter

# 2. Generate rules (auto-detects serial vs KERNELS)
./udev_mapper.sh

# 3. Review output, append to rules file
./udev_mapper.sh >> z21_persistent-local.rules

# 4. Reload udev
sudo ./udev_set.sh

# 5. Add to ser2net.conf
echo '7002:raw:0:/dev/cisco2:9600 8DATABITS NONE 1STOPBIT LOCAL' >> ser2net.conf

# 6. Add to docker-compose.yml (ports + devices sections)

# 7. Restart
docker compose down && docker compose up -d
```

### Manual method

```bash
# 1. Plug in adapter, get info
udevadm info --name=/dev/ttyUSB2 | grep -E "(ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL_SHORT)"

# 2. Add rule to z21_persistent-local.rules
SUBSYSTEM=="tty", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="XXXX", \
  ATTRS{serial}=="YYYYYYYY", SYMLINK+="cisco2", MODE="0660", GROUP="dialout"

# 3. Reload udev
sudo ./udev_set.sh

# 4. Add to ser2net.conf
echo '7002:raw:0:/dev/cisco2:9600 8DATABITS NONE 1STOPBIT LOCAL' >> ser2net.conf

# 5. Add to docker-compose.yml (ports + devices sections)

# 6. Restart
docker compose down && docker compose up -d
```

### For adapters without serial numbers

```bash
./udev_mapper.sh -k ttyUSB2
```

See [Adapters Without Serial Numbers](#adapters-without-serial-numbers-kernels-mode) for details.

---

## Troubleshooting

### Container won't start

```bash
docker compose logs ser2net
ls -la /dev/cisco*           # Symlinks exist?
```

### Connection refused

```bash
docker compose ps            # Container running?
ss -tulpn | grep 7000        # Port listening?
```

### Permission denied

```bash
sudo ./ser2net_chmod_ttyUSB.sh
docker compose restart
```

### No output after connecting

- Press **Enter** several times (wake console)
- Verify baud rate matches device
- Check cable (rollover vs straight-through)
- Test directly: `screen /dev/cisco0 9600`

### Symlink not created

```bash
# Check for syntax errors
sudo udevadm test $(udevadm info --query=path --name=/dev/ttyUSB0) 2>&1 | grep -i symlink

# Force re-trigger
sudo udevadm trigger --action=add --subsystem-match=tty
```

### Device reconnected but container can't see it

Devices are passed at container start. Reconnecting requires restart:

```bash
docker compose restart
```

---

## Security

> **ser2net provides NO authentication.** Anyone who can reach the port has raw console access.

| Control | Implementation |
|---------|----------------|
| Bind to specific IP | `10.33.1.38:7000:7000` in compose |
| Host firewall | `ufw allow from 10.0.0.0/8 to any port 7000:7009 proto tcp` |
| VPN / SSH tunnel | `ssh -L 7000:10.33.1.38:7000 user@host` |
| VLAN isolation | Put management IP on dedicated VLAN |

**Do not expose to the public internet.**

---

## License

[GPL v3](https://www.gnu.org/licenses/gpl-3.0)

---

## Why this exists

Linux names USB devices by enumeration order (`/dev/ttyUSB0`, `/dev/ttyUSB1`, ...), which changes on reboot or reconnection. This makes reliable automation impossible without udev rules.

This repository solves that problem and packages everything for repeatable deployment.
