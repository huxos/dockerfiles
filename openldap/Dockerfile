FROM debian:stretch-slim
MAINTAINER Hu Jun <hujun@17paipai.cn>

RUN groupadd -r openldap && useradd -r -g openldap openldap

RUN  sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list \
      && apt-get -y update \
	  && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ldap-utils \
       slapd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD assets /assets
ADD initialize.sh /initialize.sh
ADD docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
