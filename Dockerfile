FROM mcr.microsoft.com/dotnet/sdk:6.0 AS builder

ENV GIT_ROOT=https://github.com/okertanov

ENV NXA_GIT_VERSION=polaris-wip

ENV NXA_VM_REPO=${GIT_ROOT}/neo-vm.git
ENV NXA_VM_DIR=neo-vm

ENV NXA_CORE_REPO=${GIT_ROOT}/neo.git
ENV NXA_CORE_DIR=neo

ENV NXA_NODE_REPO=${GIT_ROOT}/neo-node.git
ENV NXA_NODE_DIR=neo-node

ENV NXA_MODULES_REPO=${GIT_ROOT}/neo-modules.git
ENV NXA_MODULES_DIR=neo-modules

ENV NXA_DVITA_MODULES_REPO=${GIT_ROOT}/nxa-modules.git
ENV NXA_DVITA_MODULES_DIR=nxa-modules

# Install deps
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    zip

# Clone all repos
WORKDIR /
RUN git clone ${NXA_VM_REPO} ${NXA_VM_DIR} && \
    git clone ${NXA_CORE_REPO} ${NXA_CORE_DIR} && \
    git clone ${NXA_NODE_REPO} ${NXA_NODE_DIR} && \
    git clone ${NXA_MODULES_REPO} ${NXA_MODULES_DIR} && \
    git clone ${NXA_DVITA_MODULES_REPO} ${NXA_DVITA_MODULES_DIR}

# Build VM
WORKDIR /${NXA_VM_DIR}
##RUN git checkout ${NXA_GIT_VERSION}
##RUN make

# Build Core
WORKDIR /${NXA_CORE_DIR}
##RUN git checkout ${NXA_GIT_VERSION}
##RUN make

# Build Modules
WORKDIR /${NXA_MODULES_DIR}
##RUN git checkout ${NXA_GIT_VERSION}
RUN make

# Build DVITA Modules
WORKDIR /${NXA_DVITA_MODULES_DIR}
##RUN git checkout ${NXA_GIT_VERSION}
RUN make

# Build Node
WORKDIR /${NXA_NODE_DIR}
##RUN git checkout ${NXA_GIT_VERSION}
RUN make

##
## Production
##

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS production

ENV NXA_NODE_DIR=neo-node
ENV NXA_MODULES_DIR=neo-modules
ENV NXA_DVITA_MODULES_DIR=nxa-modules

RUN apt-get update && apt-get install -y \
    build-essential \
    screen \
    libleveldb-dev \
    sqlite3 \
    libsqlite3-dev \
    libunwind8-dev \
    procps

WORKDIR /${NXA_NODE_DIR}

# Copy CLI
COPY --from=builder /${NXA_NODE_DIR}/neo-cli/dist ./

# Copy Modules
COPY --from=builder /${NXA_MODULES_DIR}/dist ./Plugins/

# Copy DVITA Modules
COPY --from=builder /${NXA_DVITA_MODULES_DIR}/dist ./Plugins/

# Cleanup modules
RUN rm -f \
    ./Plugins/RocksDBStore.dll \
    ./Plugins/OracleService.dll \
    ./Plugins/NXABlockListener.dll

# Cleanup main configs
RUN rm -f config*.json

# Select NXA testnet config as an active one
ENV NXA_CONFIG_FILE=config/testnet/public/config.json
ENV NXA_PLUGINS_CONFIG=config/testnet/public/plugins
ENV NXA_PLUGINS_DIR=./Plugins

# Override main config
COPY ${NXA_CONFIG_FILE} config.json

# Override plugins configs
COPY ${NXA_PLUGINS_CONFIG}/ApplicationLogs/config.json  ${NXA_PLUGINS_DIR}/ApplicationLogs/config.json
COPY ${NXA_PLUGINS_CONFIG}/DBFTPlugin/config.json       ${NXA_PLUGINS_DIR}/DBFTPlugin/config.json
COPY ${NXA_PLUGINS_CONFIG}/OracleService/config.json    ${NXA_PLUGINS_DIR}/OracleService/config.json
COPY ${NXA_PLUGINS_CONFIG}/TokensTracker/config.json    ${NXA_PLUGINS_DIR}/TokensTracker/config.json
COPY ${NXA_PLUGINS_CONFIG}/RpcServer/config.json        ${NXA_PLUGINS_DIR}/RpcServer/config.json
COPY ${NXA_PLUGINS_CONFIG}/StatesDumper/config.json     ${NXA_PLUGINS_DIR}/StatesDumper/config.json
COPY ${NXA_PLUGINS_CONFIG}/StateService/config.json     ${NXA_PLUGINS_DIR}/StateService/config.json
COPY ${NXA_PLUGINS_CONFIG}/NXABlockListener/config.json ${NXA_PLUGINS_DIR}/NXABlockListener/config.json
COPY ${NXA_PLUGINS_CONFIG}/NXAExtendedRpc/config.json   ${NXA_PLUGINS_DIR}/NXAExtendedRpc/config.json

# Require volume
VOLUME /neo-node-data

# Run the node inside screen session
ENTRYPOINT ["screen","-DmS","node","dotnet","neo-cli.dll","--rpc", "--log"]
