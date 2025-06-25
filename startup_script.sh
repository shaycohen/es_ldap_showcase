#!/bin/bash
set -e
cd "$(dirname "$0")" 

echo "Generating Elasticsearch TLS certificates"
mkdir -p elasticsearch/certs
cd elasticsearch/certs

# Generate CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=Elastic CA"

# Generate keys
for node in elasticsearch elasticsearch2 elasticsearch3; do
  openssl genrsa -out ${node}.key 2048
  openssl req -new -key ${node}.key -out ${node}.csr \
    -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=${node}"
  openssl x509 -req -in ${node}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out ${node}.crt -days 365 -sha256
done

echo "Copying certificates to node folders"
cp elasticsearch.* ../node1/certs/
cp ca.crt ../node1/certs/
cp ca.key ../node1/certs/
for i in 2 3
do
    cp elasticsearch${i}.* ../node$i/certs/
    cp ca.crt ../node$i/certs/
    cp ca.key ../node$i/certs/
done

chmod 644 ../node?/certs/*.crt
chmod 600 ../node?/certs/*.key


# If SAN-based certificates are needed, you can add openssl-san.cnf generation logic here
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting docker-compose services"
docker-compose build
docker-compose run --rm setup
docker-compose up -d elasticsearch elasticsearch2 elasticsearch3

echo "Waiting for cluster status = green"
while : 
do
    CLUSTER_STATUS=$(docker-compose exec elasticsearch curl -k -u 'elastic:password' "https://elasticsearch:9200/_cluster/health?filter_path=status")
    echo "Cluster status $CLUSTER_STATUS"
    echo $CLUSTER_STATUS | grep -i green && { break; }
    sleep 3
done

echo "Resetting kibana_system password"
docker-compose exec elasticsearch curl -k -u 'elastic:password' -X POST -H "Content-type: application/json" https://elasticsearch:9200/_security/user/kibana_system/_password -d '{ "password": "password" }'

echo "Starting dirsrv"
docker-compose up --build -d dirsrv

echo "Waiting for dirsrv to become ready"
URL='ldap://127.0.0.1:3389'                                                 
while : 
do
    docker-compose exec dirsrv ldapsearch -H $URL -x -b '' -s base vendorVersion && { break; }
    sleep 3
done


echo "Initializing LDAP users and groups"
docker-compose exec dirsrv bash -c "bash -x dirsrv_init.sh"

echo "Starting nginx"
docker-compose up -d nginx

echo "Checking Elasticsearch cluster status"
curl -u 'elastic:password' -k 'https://localhost:10443/elasticsearch/_cat/nodes?v'
echo "Activating Elasticsearch trial license"
docker-compose exec elasticsearch curl -X POST -u 'elastic:password' -k 'https://elasticsearch:9200/_license/start_trial?acknowledge=true'

echo "Authenticating with LDAP user"
curl -u 'ldap_user1:password' -k 'https://localhost:10443/elasticsearch/_security/_authenticate?pretty'

echo "Verifying all Elasticsearch nodes are joined"
curl -u 'ldap_user1:password' -k 'https://localhost:10443/elasticsearch/_cat/nodes?v'

curl -u 'kibana_system:password' -k 'https://localhost:10443/elasticsearch/_security/_authenticate'

echo "Waiting for kibana to become ready"
while : 
do
    KIBANA_STATUS=$(curl -s -k https://localhost:10443/kibana/api/status)
    echo "Kibana status $KIBANA_STATUS"
    echo $KIBANA_STATUS | grep -i '"available"' && { break; }
    sleep 3
done

echo "Setup completed!"
echo "Browse to https://localhost:10443/kibana user:ldap_user1 password:password"
