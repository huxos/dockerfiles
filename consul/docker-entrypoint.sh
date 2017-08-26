#!/usr/bin/dumb-init /bin/sh
set -x

[ "$BINDADDR" ] && \
    BIND="-bind $BINDADDR"

exec /usr/bin/consul agent $BIND -config-dir /etc/consul $@
