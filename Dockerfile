# GitHub's Linux runners default to the latest Ubunutu
# https://help.github.com/en/actions/automating-your-workflow-with-github-actions/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources
# Ubuntu uses the latest tag to represent the latest stable release
# https://hub.docker.com/_/ubuntu/
FROM ubuntu:18.04

ARG ACTIONS_RUNNER_VERSION="2.169.1"
ENV ACTIONS_RUNNER_VERSION=$ACTIONS_RUNNER_VERSION
ENV HOST_DOCKER_GID=131

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        lsb-release \
        software-properties-common \
        inetutils-ping \
        sudo \
        jq \
        ;

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository -y ppa:git-core/ppa \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt-get install -y git docker-ce

RUN groupadd -g $HOST_DOCKER_GID _docker \
    && useradd --groups $HOST_DOCKER_GID -ms /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

USER runner
WORKDIR /home/runner

RUN curl -sL https://github.com/actions/runner/releases/download/v${ACTIONS_RUNNER_VERSION}/actions-runner-linux-x64-${ACTIONS_RUNNER_VERSION}.tar.gz | tar xz \
    && sudo ./bin/installdependencies.sh

RUN sudo chown -R runner:runner . \
    && sudo tar fcz ../runner.tgz . \
    && rm -rf *

# Cleanup
RUN sudo rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN sudo chmod 755 /entrypoint.sh

ENTRYPOINT /entrypoint.sh
