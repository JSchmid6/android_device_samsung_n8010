#!/bin/bash
set -e

# Build script for LineageOS 21 in Docker container
# Usage: ./docker-build.sh [breakfast|sync|build|clean]

CONTAINER_NAME="lineageos-build"
IMAGE_NAME="lineageos:21.0"
DEVICE="n8010"

# Build directories on host with plenty of space
BUILD_ROOT="/media/RAID/lineageos-build"
SRC_DIR="$BUILD_ROOT/src"
CCACHE_DIR="$BUILD_ROOT/ccache"
OUT_DIR="$BUILD_ROOT/out"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Build Docker image if it doesn't exist
build_image() {
    if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
        log_info "Building Docker image..."
        docker build -t $IMAGE_NAME -f Dockerfile .
    else
        log_info "Docker image already exists"
    fi
}

# Create or start container
setup_container() {
    # Create build directories on host if they don't exist
    log_info "Setting up build directories in $BUILD_ROOT..."
    mkdir -p "$SRC_DIR" "$CCACHE_DIR" "$OUT_DIR"
    
    if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=$CONTAINER_NAME)" ]; then
            log_info "Starting existing container..."
            docker start $CONTAINER_NAME
        else
            log_info "Creating new container..."
            docker run -d \
                --name $CONTAINER_NAME \
                -v $(pwd)/../..:/lineage/device/samsung \
                -v "$SRC_DIR":/lineage/src \
                -v "$CCACHE_DIR":/lineage/ccache \
                -v "$OUT_DIR":/lineage/out \
                $IMAGE_NAME \
                tail -f /dev/null
        fi
    fi
}

# Initialize repo
cmd_init() {
    log_info "Initializing LineageOS repository..."
    docker exec -u root $CONTAINER_NAME bash -c "
        mkdir -p /lineage/src && \
        chown -R build:build /lineage/src /lineage/ccache /lineage/out
    "
    docker exec -u build $CONTAINER_NAME bash -c "
        cd /lineage/src && \
        repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs
    "
}

# Sync source
cmd_sync() {
    log_info "Syncing LineageOS source (this will take a while)..."
    log_warn "Using -j1 to avoid repository corruption and rate limits"
    docker exec -u build $CONTAINER_NAME bash -c "
        cd /lineage/src && \
        repo sync -c -j1 --force-sync --no-clone-bundle --no-tags
    "
}

# Run breakfast to set up device tree
cmd_breakfast() {
    log_info "Setting up device tree for $DEVICE..."
    docker exec -u build $CONTAINER_NAME bash -c "
        cd /lineage/src && \
        rm -rf device/samsung/n8010 && \
        cp -r /lineage/device/samsung/android_device_samsung_n8010 device/samsung/n8010 && \
        source build/envsetup.sh && \
        breakfast $DEVICE
    "
}

# Build ROM
cmd_build() {
    log_info "Building LineageOS 21 for $DEVICE..."
    log_warn "This will take 2-6 hours depending on your hardware"
    docker exec -u build $CONTAINER_NAME bash -c "
        cd /lineage/src && \
        source build/envsetup.sh && \
        ccache -M 50G && \
        brunch $DEVICE
    "
    
    if [ $? -eq 0 ]; then
        log_info "Build completed successfully!"
        log_info "Output: /lineage/out/target/product/$DEVICE/"
        # Copy to host
        docker cp $CONTAINER_NAME:/lineage/out/target/product/$DEVICE/lineage-21.0-*-$DEVICE.zip ./
    else
        log_error "Build failed!"
        exit 1
    fi
}

# Clean build
cmd_clean() {
    log_warn "Cleaning build output..."
    docker exec -u build $CONTAINER_NAME bash -c "
        cd /lineage/src && \
        source build/envsetup.sh && \
        make clean
    "
}

# Shell access
cmd_shell() {
    log_info "Opening shell in container..."
    docker exec -it -u build $CONTAINER_NAME bash
}

# Stop and remove container
cmd_stop() {
    log_info "Stopping container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
}

cmd_remove() {
    log_warn "Removing container..."
    docker rm $CONTAINER_NAME 2>/dev/null || true
}

# Main
case "${1:-help}" in
    init)
        build_image
        setup_container
        cmd_init
        ;;
    sync)
        setup_container
        cmd_sync
        ;;
    breakfast)
        setup_container
        cmd_breakfast
        ;;
    build)
        setup_container
        cmd_build
        ;;
    clean)
        setup_container
        cmd_clean
        ;;
    shell)
        setup_container
        cmd_shell
        ;;
    stop)
        cmd_stop
        ;;
    remove)
        cmd_stop
        cmd_remove
        ;;
    full)
        build_image
        setup_container
        cmd_init
        cmd_sync
        cmd_breakfast
        cmd_build
        ;;
    help|*)
        echo "LineageOS 21 Docker Build Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  init      - Build Docker image and initialize repo"
        echo "  sync      - Sync LineageOS source code"
        echo "  breakfast - Setup device tree"
        echo "  build     - Build the ROM"
        echo "  clean     - Clean build output"
        echo "  shell     - Open shell in container"
        echo "  stop      - Stop the container"
        echo "  remove    - Remove the container"
        echo "  full      - Run all steps (init -> sync -> breakfast -> build)"
        echo ""
        echo "Example workflow:"
        echo "  $0 init       # Initialize (first time only)"
        echo "  $0 sync       # Download source code"
        echo "  $0 breakfast  # Setup device"
        echo "  $0 build      # Build ROM"
        ;;
esac
