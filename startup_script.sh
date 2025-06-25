#!/bin/bash
set -e
cd "$(dirname "$0")" 

echo "🔐 Generating Elasticsearch TLS certificates..."
mkdir -p elasticsearch/certs
cd elasticsearch/certs

# Generate CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=Elastic CA"

# Generate keys
for node in es01 es02 es03; do
  openssl genrsa -out ${node}.key 2048
  openssl req -new -key ${node}.key -out ${node}.csr \
    -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=${node}"
  openssl x509 -req -in ${node}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out ${node}.crt -days 365 -sha256
done

echo "📂 Copying certificates to node folders..."
cp es01.* ../node1/certs/
cp es02.* ../node2/certs/
cp es03.* ../node3/certs/
cp ca.crt ../node1/certs/
cp ca.crt ../node2/certs/
cp ca.crt ../node3/certs/
cp ca.key ../node1/certs/
cp ca.key ../node2/certs/
cp ca.key ../node3/certs/

chmod 644 ../node*/certs/*.crt
chmod 600 ../node*/certs/*.key


# If SAN-based certificates are needed, you can add openssl-san.cnf generation logic here
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting docker-compose services..."
/usr/local/bin/docker-compose up -d --build

sleep 17

echo "🔧 Initializing LDAP users and groups..."
docker-compose exec dirsrv bash -c "bash -x dirsrv_init.sh"

sleep 60
echo "✅ Checking Elasticsearch cluster status..."
curl -u 'elastic:ABC@123' -k 'https://localhost:10443/elasticsearch/_cat/nodes?v'
echo "🎫 Activating Elasticsearch trial license..."
curl -X POST -u 'elastic:ABC@123' -k 'https://localhost:10443/elasticsearch/_license/start_trial?acknowledge=true'

# echo "🧪 Authenticating with LDAP user..."
curl -u 'ldap_user4:password' -k 'https://localhost:10443/elasticsearch/_security/_authenticate?pretty'

# echo "📊 Verifying all Elasticsearch nodes are joined..."
curl -u 'ldap_user4:password' -k 'https://localhost:10443/elasticsearch/_cat/nodes?v'

# docker-compose restart
# check kibana password
curl -u elastic:ABC@123 -X POST https://localhost:10443/elasticsearch/_security/user/kibana_system/_password \
  -H "Content-Type: application/json" \
  -d '{"password":"123456"}' -k 

curl -u kibana_system:123456 -k 'https://localhost:10443/elasticsearch/_security/_authenticate'

sleep 3
docker-compose restart kibana
curl -u kibana_system:123456 -k 'https://localhost:10443/elasticsearch/_security/_authenticate'

echo "✅ Setup completed!"
