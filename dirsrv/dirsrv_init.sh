#!/bin/bash
set -e
cat << EOF > /data/config/container.inf
[localhost]
# Note that '/' is replaced to '%%2f' for ldapi url format.
# So this is pointing to /data/run/slapd-localhost.socket
uri = ldapi://%%2fdata%%2frun%%2fslapd-localhost.socket
binddn = cn=Directory Manager
# Set your basedn here
# basedn = dc=example,dc=com
basedn = dc=example,dc=com
EOF

URL='ldap://127.0.0.1:3389'
LDAP_USERS='ldap_user1 ldap_user2'
LDAP_PASSW='password'
ldapsearch -H $URL -x -b '' -s base vendorVersion
dsconf localhost backend suffix list
dsconf localhost backend create --suffix dc=example,dc=com --be-name userRoot

ldapadd -x -H ldap://localhost:3389 -D "cn=Directory Manager" -w myadminpass <<EOF
dn: dc=example,dc=com
objectClass: top
objectClass: domain
dc: example
EOF

ldapadd -x -H ldap://localhost:3389 -D "cn=Directory Manager" -w myadminpass <<EOF
dn: ou=people,dc=example,dc=com
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups
EOF

/usr/sbin/dsidm -b dc=example,dc=com localhost group create --cn test_group
for USER in $LDAP_USERS
do
    /usr/sbin/dsidm -b dc=example,dc=com localhost user create --uid $USER --cn $USER --displayName $USER --uidNumber 1000 --gidNumber 1000 --homeDirectory /home/$USER
    /usr/sbin/dsidm -b dc=example,dc=com localhost group add_member test_group uid=$USER,ou=people,dc=example,dc=com
    /usr/sbin/dsidm -b dc=example,dc=com localhost account reset_password uid=$USER,ou=people,dc=example,dc=com $LDAP_PASSW
    ldapwhoami -H $URL -x -D uid=$USER,ou=people,dc=example,dc=com -w $LDAP_PASSW
done
ldapsearch -H $URL -x -b 'dc=example,dc=com'
