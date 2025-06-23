#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🧨 Stopping and removing all containers, networks, and volumes..."
docker compose down -v

echo "🧹 Cleaning up certificate files..."
for NODE in node1 node2 node3; do
  CERT_DIR="elasticsearch/${NODE}/certs"
  if [ -d "$CERT_DIR" ]; then
    echo "🔻 Deleting certs in $CERT_DIR"
    rm -f "${CERT_DIR}"/*.key "${CERT_DIR}"/*.crt "${CERT_DIR}"/*.csr "${CERT_DIR}"/*.srl
  else
    echo "⚠️ Directory $CERT_DIR does not exist. Skipping."
  fi
done

echo "✅ All containers stopped and certs deleted."