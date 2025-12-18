ser2net-docker
===============

Tags: linux, serial, ser2net, tty, usb-serial, rs232, rs485, tcp, networking, docker, docker-compose, udev, systemd, headless, embedded, industrial, automation, zigbee, zwave, console-server

This repository packages **ser2net** in a Docker-based setup and adds
supporting scripts to deal with problems that exist in real systems:
unstable device names, broken permissions, and repeatable deployment.

This is not a web application.  
It exposes serial devices over TCP.

If You do not understand what that means, do not run it on a public
network.

---

What this repository contains
------------------------------

ser2net itself is simple. The surrounding environment is not.

This repository provides:

- A Docker image running ser2net
- A docker-compose file to run it
- udev rules and scripts to make USB serial devices stable
- Permission fixups for tty devices
- Optional TCP proxying via nginx

The goal is that a serial device connected to a Linux host can be
reliably accessed over TCP without changing configuration every reboot.

---

Repository layout
-----------------

```
Dockerfile
    Builds the ser2net container.

docker-compose.yml
    Runs the container with the required device mappings.

ser2net.conf
    ser2net port-to-device configuration.

nginx.conf
    Optional TCP stream proxy configuration.

tty_get.sh
    Lists detected tty devices.

udev_mapper.sh
    Maps USB vendor/product IDs to stable device names.

udev_set.sh
    Installs udev rules for persistent device naming.

z21_persistent-local.rules
    Example udev rules file.

ser2net_chmod_ttyUSB.sh
    Fixes permissions on ttyUSB devices.
```


---

Requirements
------------

- Linux host
- Docker and docker compose
- A serial device exposed as `/dev/tty*`

This repository assumes You have root access.

---

Usage
-----

1. Identify the serial device.

```
./tty_get.sh
```

This prints available tty devices.

2. Install persistent udev rules.

```
./udev_set.sh
```

This installs rules from `z21_persistent-local.rules` so that the device
name does not change across reboots.

Reload udev:

```
udevadm control --reload-rules
udevadm trigger
```

3. Fix permissions.

```
./ser2net_chmod_ttyUSB.sh
```

This avoids the common failure mode where permissions break after a
reboot or reconnect.

4. Configure ser2net.

Edit `ser2net.conf`.

Example:

```
20108:raw:0:/dev/ttyUSB_Z21:115200 8DATABITS NONE 1STOPBIT
```

This exposes the device on TCP port 20108.

5. Start the container.

```
docker compose up --build --detach
```

---

Access
------

Connect from another system:

```
nc <host> 20108
```

Applications that support TCP serial connections should point to:

```
tcp://<host>:20108
```

Only one client should connect at a time.

---

nginx
-----

`nginx.conf` provides TCP stream proxying.

This is optional.

It exists for cases where ports need to be remapped or isolated.
If You do not know why You need it, do not enable it.

---

Security
--------

ser2net does not provide authentication.

It gives raw access to the serial device.

Do not expose it to the public internet.

Use a firewall, VPN, or SSH port forwarding.

This is intentional.

---

Failure modes
-------------

- Device disappears:
  Use udev rules. Do not rely on `/dev/ttyUSB0`.

- Permission denied:
  Fix permissions or group membership.

- Unstable connections:
  Check baud rate, flow control, and USB power.

---

License
-------

GPL version 3.

---

Notes
-----

This repository exists because serial hardware is still common and
Linux still names devices poorly by default.


