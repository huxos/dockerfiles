FROM alpine:latest

RUN apk add --no-cache musl iptables gnutls readline libnl3 protobuf-c libseccomp lz4-libs libev talloc

ENV OC_VERSION 0.11.8

RUN buildDeps="xz gcc autoconf make linux-headers libev-dev protobuf-c-dev musl-dev gnutls-dev readline-dev libnl3-dev lz4-dev libseccomp-dev talloc-dev"; \
	set -x \
	&& apk add --no-cache $buildDeps \
	&& cd \
	&& OC_FILE="ocserv-$OC_VERSION" \
	&& wget ftp://ftp.infradead.org/pub/ocserv/$OC_FILE.tar.xz \
	&& tar xJf $OC_FILE.tar.xz \
	&& rm -fr $OC_FILE.tar.xz \
	&& cd $OC_FILE \
	&& ./configure \
	&& make -j4 \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp ./doc/sample.config /etc/ocserv/ocserv.conf \
	&& cd \
	&& rm -fr ./$OC_FILE \
	&& apk del --purge $buildDeps

WORKDIR /etc/ocserv
EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
