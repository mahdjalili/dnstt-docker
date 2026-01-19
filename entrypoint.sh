#!/bin/bash
set -e

# Define paths
PRIV_KEY="/etc/dnstt/server.key"
PUB_KEY="/etc/dnstt/server.pub"

# 1. Generate Keys if they don't exist
if [ ! -f "$PRIV_KEY" ]; then
    echo "Generating new dnstt keys..."
    dnstt-server -gen-key -privkey-file "$PRIV_KEY" -pubkey-file "$PUB_KEY"
fi

echo "--------------------------------------------------------"
echo "Public Key (Copy this to your client):"
cat "$PUB_KEY"
echo "--------------------------------------------------------"

# 2. Configure Dante (Socks Proxy)
# We overwrite the config to ensure it works with the container network
cat > /etc/danted.conf << EOF
logoutput: stderr
internal: 0.0.0.0 port = 1080
external: eth0
socksmethod: none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
EOF

# 3. Start Dante in the background
echo "Starting Dante SOCKS server..."
/usr/sbin/danted -D &

# 4. Start dnstt-server
# If NS_SUBDOMAIN is not set, we cannot start properly
if [ -z "$NS_SUBDOMAIN" ]; then
    echo "Error: NS_SUBDOMAIN environment variable is not set."
    exit 1
fi

echo "Starting dnstt-server on port 5300..."
echo "Subdomain: $NS_SUBDOMAIN"
echo "MTU: ${MTU_VALUE:-1232}"

# Exec allows dnstt to take over PID 1 and handle signals correctly
exec dnstt-server \
    -udp :5300 \
    -privkey-file "$PRIV_KEY" \
    -mtu "${MTU_VALUE:-1232}" \
    "$NS_SUBDOMAIN" \
    127.0.0.1:1080