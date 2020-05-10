FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build

COPY ./Auth /build
WORKDIR /build
RUN dotnet publish --self-contained=true -r linux-x64 -o deploy

#############################################################################
# GitHub's Linux runners default to the latest Ubunutu
# https://help.github.com/en/actions/automating-your-workflow-with-github-actions/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources
# Ubuntu uses the latest tag to represent the latest stable release
# https://hub.docker.com/_/ubuntu/

FROM ubuntu:18.04 AS runner

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

# Cleanup
RUN sudo rm -rf /var/lib/apt/lists/*

COPY --from=build /build/deploy ./Auth

RUN sudo chown -R runner:runner . \
    && sudo tar fcz ../runner.tgz . \
    && rm -rf *

COPY entrypoint.sh /entrypoint.sh
RUN sudo chmod 755 /entrypoint.sh

ENTRYPOINT /entrypoint.sh

#############################################################################
## Actions Runner for F# SAFE with dotnet 3.1, node, yarn and chrome headless

FROM runner

RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb > packages-microsoft-prod.deb \
    && sudo dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb

RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo bash

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

RUN sudo apt-get update \
    && sudo apt-get install -y \
       dotnet-sdk-3.1 nodejs p7zip-full yarn git procps libgdiplus

# Install google-chrome for Canopy/Selenium
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb > google-chrome-stable_current_amd64.deb \
    && sudo apt install -y ./google-chrome-stable_current_amd64.deb \
    && sudo sed -i 's,HERE/chrome",& --no-sandbox ,' /opt/google/chrome/google-chrome \
    && rm -f google-chrome-stable_current_amd64.deb

# Clean up
RUN sudo apt-get autoremove -y \
    && sudo apt-get clean -y \
    && sudo rm -rf /var/lib/apt/lists/*

# Install fake
RUN dotnet tool install fake-cli -g

# Install Paket
RUN dotnet tool install paket -g

# Install dotnet-retire
RUN dotnet tool install dotnet-retire -g

# Install retire.js
RUN sudo npm install -g retire

# Trouble brewing
RUN sudo rm /etc/ssl/openssl.cnf

# add dotnet tools to path to pick up fake and paket installation
ENV PATH="/home/runner/.dotnet/tools:${PATH}"

