#!/bin/bash -ex

[ -d /var/lib/ldap ] || mkdir -p /var/lib/ldap
[ -d /etc/ldap/slapd.d ] || mkdir -p /etc/ldap/slapd.d

chown -R openldap:openldap /var/lib/ldap
chown -R openldap:openldap /etc/ldap

if [ -z "$LDAP_BASE_DN" ]; then
  IFS='.' read -ra LDAP_BASE_DN_TABLE <<< "$LDAP_DOMAIN"
  for i in "${LDAP_BASE_DN_TABLE[@]}"; do
    EXT="dc=$i,"
    LDAP_BASE_DN=$LDAP_BASE_DN$EXT
  done
  LDAP_BASE_DN=${LDAP_BASE_DN::-1}
fi

function is_new_schema() {
  local COUNT=$(ldapsearch -Q -Y EXTERNAL -H ldapi:/// -b cn=schema,cn=config cn | grep -c $1)
  if [ "$COUNT" -eq 0 ]; then
    echo 1
  else
    echo 0
  fi
}

function ldap_add_or_modify() {
  local LDIF_FILE=$1
  sed -i "s|{{ LDAP_BASE_DN }}|${LDAP_BASE_DN}|g" $LDIF_FILE
  sed -i "s|{{ LDAP_BACKEND }}|${LDAP_BACKEND}|g" $LDIF_FILE
  if grep -iq changetype $LDIF_FILE ; then
      ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE || ldapmodify -h localhost -p 389 -D cn=admin,$LDAP_BASE_DN -w $LDAP_ADMIN_PASSWORD -f $LDIF_FILE
  else
      ldapadd -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE
  fi
}

cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string ${LDAP_BACKEND^^}
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

dpkg-reconfigure -f noninteractive slapd

slapd -h "ldap://${HOSTNAME}.${SUBDOMAIN} ldap://localhost ldapi:///" -u openldap -g openldap

ldapadd -c -Y EXTERNAL -Q -H ldapi:/// -f /etc/ldap/schema/ppolicy.ldif

SCHEMAS=""
for f in $(find /assets/config/bootstrap/schema -name \*.schema -type f); do
    SCHEMAS="$SCHEMAS ${f}"
done
/assets/schema-to-ldif.sh "$SCHEMAS"

for f in $(find /assets/config/bootstrap/schema -name \*.ldif -type f); do
  SCHEMA=$(basename "${f}" .ldif)
  ADD_SCHEMA=$(is_new_schema $SCHEMA)
  if [ "$ADD_SCHEMA" -eq 1 ]; then
    ldapadd -c -Y EXTERNAL -Q -H ldapi:/// -f $f
  fi
done

LDAP_CONFIG_PASSWORD_ENCRYPTED=$(slappasswd -s $LDAP_CONFIG_PASSWORD)
sed -i "s|{{ LDAP_CONFIG_PASSWORD_ENCRYPTED }}|${LDAP_CONFIG_PASSWORD_ENCRYPTED}|g" /assets/config/bootstrap/ldif/00-config-password.ldif

LDAP_READONLY_USER_PASSWORD_ENCRYPTED=$(slappasswd -s $LDAP_READONLY_USER_PASSWORD)
sed -i "s|{{ LDAP_READONLY_USER_USERNAME }}|${LDAP_READONLY_USER_USERNAME}|g" /assets/config/bootstrap/ldif/01-readonly-user.ldif
sed -i "s|{{ LDAP_READONLY_USER_PASSWORD_ENCRYPTED }}|${LDAP_READONLY_USER_PASSWORD_ENCRYPTED}|g" /assets/config/bootstrap/ldif/01-readonly-user.ldif
sed -i "s|{{ LDAP_BASE_DN }}|${LDAP_BASE_DN}|g" /assets/config/bootstrap/ldif/01-readonly-user.ldif

sed -i "s|{{ LDAP_READONLY_USER_USERNAME }}|${LDAP_READONLY_USER_USERNAME}|g" /assets/config/bootstrap/ldif/02-security.ldif
sed -i "s|{{ LDAP_BASE_DN }}|${LDAP_BASE_DN}|g" /assets/config/bootstrap/ldif/02-security.ldif

for f in $(find /assets/config/bootstrap/ldif -mindepth 1 -maxdepth 1 -type f -name \*.ldif  | sort); do
  ldap_add_or_modify "$f"
done

for f in $(find /assets/config/bootstrap/ldif/custom -type f -name \*.ldif  | sort); do
  ldap_add_or_modify "$f"
done

sed -i "s|{{ LDAP_TLS_CA_CRT_PATH }}|${LDAP_TLS_CA_CRT_PATH}|g" /assets/config/tls/tls-enable.ldif
sed -i "s|{{ LDAP_TLS_CRT_PATH }}|${LDAP_TLS_CRT_PATH}|g" /assets/config/tls/tls-enable.ldif
sed -i "s|{{ LDAP_TLS_KEY_PATH }}|${LDAP_TLS_KEY_PATH}|g" /assets/config/tls/tls-enable.ldif
sed -i "s|{{ LDAP_TLS_DH_PARAM_PATH }}|${LDAP_TLS_DH_PARAM_PATH}|g" /assets/config/tls/tls-enable.ldif
sed -i "s|{{ LDAP_TLS_CIPHER_SUITE }}|${LDAP_TLS_CIPHER_SUITE}|g" /assets/config/tls/tls-enable.ldif
sed -i "s|{{ LDAP_TLS_VERIFY_CLIENT }}|${LDAP_TLS_VERIFY_CLIENT}|g" /assets/config/tls/tls-enable.ldif
ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f /assets/config/tls/tls-enable.ldif
ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f /assets/config/tls/tls-enforce-enable.ldif

LDAP_REPLICATION_HOSTS_ARR=($LDAP_REPLICATION_HOSTS)
i=1
for host in ${LDAP_REPLICATION_HOSTS_ARR[@]}
do
  sed -i "s|{{ LDAP_REPLICATION_HOSTS }}|olcServerID: $i ${host}\n{{ LDAP_REPLICATION_HOSTS }}|g" /assets/config/replication/replication-enable.ldif
  sed -i "s|{{ LDAP_REPLICATION_HOSTS_CONFIG_SYNC_REPL }}|olcSyncRepl: rid=00$i provider=${host} ${LDAP_REPLICATION_CONFIG_SYNCPROV}\n{{ LDAP_REPLICATION_HOSTS_CONFIG_SYNC_REPL }}|g" /assets/config/replication/replication-enable.ldif
  sed -i "s|{{ LDAP_REPLICATION_HOSTS_DB_SYNC_REPL }}|olcSyncRepl: rid=10$i provider=${host} ${LDAP_REPLICATION_DB_SYNCPROV}\n{{ LDAP_REPLICATION_HOSTS_DB_SYNC_REPL }}|g" /assets/config/replication/replication-enable.ldif
  ((i++))
done
sed -i "s|\$LDAP_BASE_DN|$LDAP_BASE_DN|g" /assets/config/replication/replication-enable.ldif
sed -i "s|\$LDAP_ADMIN_PASSWORD|$LDAP_ADMIN_PASSWORD|g" /assets/config/replication/replication-enable.ldif
sed -i "s|\$LDAP_CONFIG_PASSWORD|$LDAP_CONFIG_PASSWORD|g" /assets/config/replication/replication-enable.ldif
sed -i "/{{ LDAP_REPLICATION_HOSTS }}/d" /assets/config/replication/replication-enable.ldif
sed -i "/{{ LDAP_REPLICATION_HOSTS_CONFIG_SYNC_REPL }}/d" /assets/config/replication/replication-enable.ldif
sed -i "/{{ LDAP_REPLICATION_HOSTS_DB_SYNC_REPL }}/d" /assets/config/replication/replication-enable.ldif
sed -i "s|{{ LDAP_BACKEND }}|${LDAP_BACKEND}|g" /assets/config/replication/replication-enable.ldif
ldapmodify -c -Y EXTERNAL -Q -H ldapi:/// -f /assets/config/replication/replication-enable.ldif

SLAPD_PID=$(cat /run/slapd/slapd.pid)
kill -15 $SLAPD_PID
while [ -e /proc/$SLAPD_PID ]; do sleep 0.1; done

touch /var/lib/ldap/initialized

exit 0
