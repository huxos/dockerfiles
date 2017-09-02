FROM ubuntu:14.04
ADD source.list /etc/apt/sources.list

RUN apt-get update -y && \
    apt-get install --no-install-recommends -y ca-certificates wget apt-transport-https libltdl7 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb https://packages.gitlab.com/runner/gitlab-ci-multi-runner/ubuntu/ `lsb_release -cs` main" > /etc/apt/sources.list.d/runner_gitlab-ci-multi-runner.list && \
    wget -q -O - https://packages.gitlab.com/gpg.key | apt-key add - && \
    apt-get update -y && \
    apt-get install -y gitlab-ci-multi-runner && \
    apt-get clean && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    rm -rf /var/lib/apt/lists/*

ADD dumb-init /usr/bin/dumb-init

ADD entrypoint /
RUN chmod +x /entrypoint

ENTRYPOINT ["/entrypoint"]
