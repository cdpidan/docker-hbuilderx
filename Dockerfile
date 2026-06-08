FROM ubuntu:24.04 AS hbuilderx-extract

ARG HBUILDER_X_VERSION=5.07.2026041006

COPY hbuilderx/HBuilderX.${HBUILDER_X_VERSION}.linux_x64.full.tar.gz /tmp/hbuilderx.tar.gz

RUN set -eux; \
    mkdir -p /tmp/hbuilderx; \
    tar -xzf /tmp/hbuilderx.tar.gz -C /tmp/hbuilderx; \
    mv /tmp/hbuilderx/HBuilderX /tmp/hbuilderx/hbuilderx-linux; \
    rm -f /tmp/hbuilderx.tar.gz


FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /opt

# 安装系统工具和依赖
RUN set -eux; \
    sed -i 's#archive.ubuntu.com#mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's#security.ubuntu.com#mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's#ports.ubuntu.com#mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    tar \
    zip \
        git \
        sudo \
        libglib2.0-0 \
        libkrb5-3 \
        libgssapi-krb5-2 \
        libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 nvm 和 Node.js
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=20.19.0

RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default



# 复制并解压 HBuilderX
COPY --from=hbuilderx-extract /tmp/hbuilderx/hbuilderx-linux /usr/local/hbuilderx-linux

# 不创建非 root 用户，构建与运行均以 root 执行（测试阶段）

# 将 NVM_DIR 放到全局目录，构建与运行均使用 root（更快，适合测试阶段）
ENV NVM_DIR=/usr/local/nvm \
    NODE_PATH=/usr/local/nvm/versions/node/v$NODE_VERSION/lib/node_modules \
    PATH=/usr/local/hbuilderx-linux:/usr/local/nvm/versions/node/v$NODE_VERSION/bin:$PATH

# 保持工作目录为 /opt，构建与运行都用 root
WORKDIR /opt

# 在 root 下安装全局 npm 包并配置 uapp
RUN npm install -g uapp && \
    uapp sdk init && \
    uapp config node "$(which node)" && \
    corepack enable && \
    corepack prepare pnpm@latest-9 --activate && \
    uapp config hbx.dir /usr/local/hbuilderx-linux

CMD ["bash"]
    