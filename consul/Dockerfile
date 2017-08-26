FROM alpine:3.6
MAINTAINER Hu Jun <hujun@17paipai.cn>
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
        apk add tzdata --no-cache && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" >  /etc/timezone && apk del tzdata
RUN apk add --no-cache ca-certificates dumb-init curl
ADD consul /usr/bin/consul
ADD config.json /etc/consul/config.json
VOLUME  /var/consul
ADD docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
