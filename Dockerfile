# LineageOS 21 Build Environment
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up build user
RUN useradd -m -s /bin/bash build && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install required packages
RUN apt-get update && apt-get install -y \
    bc bison build-essential ccache curl flex \
    g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
    lib32ncurses-dev lib32readline-dev lib32z1-dev liblz4-tool \
    libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 \
    libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc \
    zip zlib1g-dev python3 python-is-python3 \
    openjdk-11-jdk android-sdk-platform-tools-common \
    && rm -rf /var/lib/apt/lists/*

# Install repo tool
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Set up ccache
ENV USE_CCACHE=1
ENV CCACHE_EXEC=/usr/bin/ccache
ENV CCACHE_DIR=/lineage/ccache

# Configure git for repo
USER build
RUN git config --global user.email "build@lineageos.local" && \
    git config --global user.name "LineageOS Builder" && \
    git config --global color.ui auto

# Set working directory
WORKDIR /lineage

# Default command
CMD ["/bin/bash"]
