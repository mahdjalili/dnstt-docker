# dnstt-docker

> A lightweight and container-native Docker implementation for the **dnstt** (DNS Tunnel) server.

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.style=for-the-badge)](https://opensource.org/licenses/MIT)

This project provides a streamlined Docker image for deploying a DNS tunnel server. Unlike other implementations, this version removes the overhead of Systemd, uses a native entrypoint script, automatically manages keys, and configures an embedded SOCKS5 proxy (Dante) without complex internal routing.

---

## Features

- ** Lightweight & Fast**: stripped of Systemd and unnecessary bloat.
- ** Auto-Key Generation**: Automatically generates and persists private/public keys on first run.
- ** Built-in SOCKS5**: Pre-configured Dante server for SOCKS tunneling.
- ** Persistent Storage**: Keys are saved in Docker volumes and survive restarts.
- ** Native Docker Networking**: Maps host port 53 directly to the container, avoiding complex internal iptables.

---

## Prerequisites

Before deploying, ensure you have the following:

1.  **A Server** with a public IP address.
2.  **Docker & Docker Compose** installed.
3.  **A Domain Name** with the following DNS records configured at your registrar/DNS provider:

| Type | Host | Value | Description |
| :--- | :--- | :--- | :--- |
| **A** | `ns.example.com` | `<YOUR-SERVER-IP>` | Points to your server IP |
| **NS** | `t.example.com` | `ns.example.com` | Delegates the subdomain to the A record |

> Replace `example.com` with your actual domain. `t.example.com` will be your **NS_SUBDOMAIN**.

---

## 🚀 Quick Start

### 1. Create `docker-compose.yml`

Create a file named `docker-compose.yml` with the following content:

```yaml
version: '3.8'

services:
  dnstt:
    image: docker pull ghcr.io/mahdjalili/dnstt-docker
    build: .
    container_name: dnstt-server
    restart: unless-stopped
    environment:
      # ⚠️ CHANGE THIS to your configured NS domain
      - NS_SUBDOMAIN=t.example.com
      
      # Optional settings
      - MTU_VALUE=1232
    volumes:
      # Persist keys so they don't change on restart
      - ./dnstt-data:/etc/dnstt
    ports:
      # Map Host Port 53 (UDP) -> Container Port 5300
      - "53:5300/udp"
      
      # Optional: Expose SOCKS5 externally (Not recommended for public servers)
      # - "1080:1080/tcp"

```

### 2. Build and Run

Run the container in detached mode:

```bash
docker-compose up -d --build

```

### 3. Get Your Public Key 🔑

The container generates a public key on the first startup. You need this key for your client to connect.

View the logs to retrieve it:

```bash
docker logs dnstt-server

```

**Output example:**

```text
--------------------------------------------------------
Public Key (Copy this to your client):
725406983088899388f83038380838383083083083083083083083
--------------------------------------------------------

```

---

## 📡 Usage Methods

### Method 1: Standard Direct UDP (Recommended)

This connects directly to port 53 on your server. It is the fastest and most compatible method.

**Client Command:**

```bash
dnstt-client -udp ns.example.com:53 \
  -pubkey <YOUR-PUBLIC-KEY> \
  t.example.com \
  127.0.0.1:8000

```

### Method 2: DNS over HTTPS (DoH) / TLS (DoT)

Since this image is lightweight, it does not include a web server (Caddy/Nginx). To use DoH (which is more secure and bypasses firewalls better), you should run a reverse proxy alongside this container.

**1. Add Caddy to `docker-compose.yml`:**

```yaml
  # Add this service below the dnstt service
  caddy:
    image: caddy:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    depends_on:
      - dnstt

```

**2. Create a `Caddyfile`:**

```caddy
doh.example.com {
    reverse_proxy dnstt:5300 {
        transport http {
            versions h2c
        }
    }
}

```

**3. Connect via Client:**

```bash
dnstt-client -doh [https://doh.example.com/dns-query](https://doh.example.com/dns-query) \
  -pubkey <YOUR-PUBLIC-KEY> \
  t.example.com \
  127.0.0.1:8000

```

---

## 🛠 Configuration

You can configure the server using environment variables in `docker-compose.yml`.

| Variable | Default | Description |
| --- | --- | --- |
| `NS_SUBDOMAIN` | **Required** | The subdomain delegated to this server (e.g., `t.example.com`). |
| `MTU_VALUE` | `1232` | Maximum Transmission Unit. Lower this if connections are unstable. |

---

## 📂 File Structure

Data is persisted in the `./dnstt-data` directory on your host machine:

```text
./dnstt-data/
├── server.key       # Private Key (DO NOT SHARE)
└── server.pub       # Public Key (Share with clients)

```

---

## ❓ Troubleshooting

### The container restarts endlessly

* Check if you set the `NS_SUBDOMAIN` variable. The server cannot start without it.
* Check logs: `docker logs dnstt-server`.

### "Bind: permission denied" (Port 53)

* Ensure no other service is using port 53 on your host (like `systemd-resolved` or `dnsmasq`).
* On Ubuntu, you might need to disable systemd-resolved:
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

```



### Client cannot connect

* Verify your DNS records (A record and NS record) are correct.
* Ensure your firewall (UFW/AWS Security Groups) allows **UDP Port 53**.
* Double-check the **Public Key** matches the one in `server.pub`.

---

## License

This project is open-source and available under the MIT License.