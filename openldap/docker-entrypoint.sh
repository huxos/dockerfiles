#!/bin/bash -x

if [ ! -f /var/lib/ldap/initialized ]; then
    /initialize.sh ||  exit 255
else
    sleep 10
fi

chown -R openldap:openldap /var/lib/ldap
chown -R openldap:openldap /etc/ldap

sed -i --follow-symlinks "s,TLS_CACERT.*,TLS_CACERT ${LDAP_TLS_CA_CRT_PATH},g" /etc/ldap/ldap.conf
echo "TLS_REQCERT ${LDAP_TLS_VERIFY_CLIENT}" >> /etc/ldap/ldap.conf
cp -f /etc/ldap/ldap.conf /assets/ldap.conf
[[ -f "$HOME/.ldaprc" ]] && rm -f $HOME/.ldaprc
echo "TLS_CERT ${LDAP_TLS_CRT_PATH}" > $HOME/.ldaprc
echo "TLS_KEY ${LDAP_TLS_KEY_PATH}" >> $HOME/.ldaprc
cp -f $HOME/.ldaprc /assets/.ldaprc
ln -sf /assets/.ldaprc $HOME/.ldaprc
ln -sf /assets/ldap.conf /etc/ldap/ldap.conf

exec slapd -h "ldap://${HOSTNAME}.${SUBDOMAIN} ldap://localhost ldaps:/// ldapi:///" -u openldap -g openldap -d $LDAP_LOG_LEVEL
