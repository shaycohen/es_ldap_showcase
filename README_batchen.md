# startup
docker-compose up -d --build

# create users and groups
docker-compose exec dirsrv bash -c "bash -x dirsrv_init.sh"

# Check if connection to elastics is working:
curl -u elastic:ABC@123 -k https://localhost:9200/_cat/nodes?v


# ================ Create elastics certificate for TLS ===================
mkdir -p elasticsearch/certs && cd elasticsearch/certs

# Generate CA key
openssl genrsa -out ca.key 4096

# Create CA cert
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=Elastic CA"

# Generate private key
openssl genrsa -out es01.key 2048
openssl genrsa -out es02.key 2048
openssl genrsa -out es03.key 2048

# Generate CSR
openssl req -new -key es01.key -out es01.csr \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=es01"

  openssl req -new -key es02.key -out es02.csr \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=es02"

  openssl req -new -key es03.key -out es03.csr \
  -subj "/C=US/ST=Elastic/L=Elastic/O=Elastic/CN=es03"

  # Create cert for the node
openssl x509 -req -in es01.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es01.crt -days 365 -sha256

  openssl x509 -req -in es02.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es02.crt -days 365 -sha256

  openssl x509 -req -in es03.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es03.crt -days 365 -sha256

# copy file to certs path for each node
cp es01.* ../node1/certs/.       
cp es02.* ../node2/certs/.                                          
cp es03.* ../node3/certs/.       

cp ca.crt        ../node1/certs/.     
cp ca.crt        ../node2/certs/.                             
cp ca.crt        ../node3/certs/.                             

cp ca.key        ../node1/certs/.     
cp ca.key       ../node2/certs/.   
cp ca.key       ../node3/certs/.                             


chmod 644 ../node*/certs/*.crt
chmod 600 ../node*/certs/*.key

# inside node[123]/certs (cd to dir and run)
  openssl req -new -key es01.key -out es01.csr -config openssl-san.cnf
openssl x509 -req -in es01.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es01.crt -days 365 -sha256 -extfile openssl-san.cnf -extensions v3_req


openssl req -new -key es02.key -out es02.csr -config openssl-san.cnf
openssl x509 -req -in es02.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es02.crt -days 365 -sha256 -extfile openssl-san.cnf -extensions v3_req


openssl req -new -key es03.key -out es03.csr -config openssl-san.cnf
openssl x509 -req -in es03.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es03.crt -days 365 -sha256 -extfile openssl-san.cnf -extensions v3_req


# Get free trial
curl -X POST -u elastic:ABC@123 -k "https://localhost:9200/_license/start_trial?acknowledge=true"
> {"acknowledged":true,"trial_was_started":true,"type":"trial"}          
                                                               
docker restart es01 es02 es03

# try to connect to elastic with user from role_mapping
curl -u ldap_user4:password -k https://localhost:9200/_security/_authenticate?pretty

# verify in all ecs
curl -u ldap_user4:password -k https://localhost:9200/_cat/nodes?v