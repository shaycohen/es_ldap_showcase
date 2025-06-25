# Stratup env + creating certificates
bash -x startup_script.sh

# destroy env + deleting certificates
bash -x destroy_script.sh

# create nginx certificates
cd nginx/certs

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout privkey.pem \
  -out fullchain.pem \
  -subj "/CN=elasticsearch.local"

cp fullchain.pem nginx_ca.crt

