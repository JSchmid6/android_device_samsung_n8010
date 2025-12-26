# LineageOS 21 Build Instructions for Samsung Galaxy Note 10.1 (n8010)

## Prerequisites
- Docker installed and running
- At least 250GB free disk space
- 16GB RAM (32GB recommended)
- Fast internet connection

## Docker Build (Recommended)

This method uses Docker to isolate the build environment from your host system.

### Quick Start

```bash
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010

# One-command full build (init + sync + breakfast + build)
./docker-build.sh full
```

### Step-by-Step Build

```bash
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010

# 1. Initialize repo (first time only, ~5 minutes)
./docker-build.sh init

# 2. Download LineageOS source code (~60GB, takes 1-3 hours)
./docker-build.sh sync

# 3. Setup device tree
./docker-build.sh breakfast

# 4. Build ROM (takes 2-6 hours)
./docker-build.sh build
```

### Other Commands

```bash
# Access container shell for manual commands
./docker-build.sh shell

# Clean build output
./docker-build.sh clean

# Stop container
./docker-build.sh stop

# Remove container (keeps volumes)
./docker-build.sh remove
```

### Docker Volumes

The build uses persistent Docker volumes:
- `lineageos-src`: Source code (~60GB)
- `lineageos-ccache`: Build cache (~50GB)
- `lineageos-out`: Build output (~10GB)

To completely reset and start fresh:
```bash
./docker-build.sh remove
docker volume rm lineageos-src lineageos-ccache lineageos-out
```

## Native Build (Alternative)

If you prefer to build directly on your system without Docker:

<details>
<summary>Click to expand native build instructions</summary>

```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y bc bison build-essential ccache curl flex \
  g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
  lib32ncurses-dev lib32readline-dev lib32z1-dev liblz4-tool \
  libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 \
  libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc \
  zip zlib1g-dev python3 python-is-python3 openjdk-11-jdk

# Install repo tool
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH

# Initialize and sync source
mkdir -p ~/lineage && cd ~/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags

# Setup device tree
ln -sf /home/jochen/DEV/lineagos/android_device_samsung_n8010 device/samsung/n8010
source build/envsetup.sh
breakfast n8010

# Build
brunch n8010
```

</details>

## Flash to Device

```bash
# After successful build, the ROM will be in the current directory:
# lineage-21.0-*-n8010.zip

# Boot device into recovery mode (TWRP recommended)
# Power off device, then hold Volume Up + Power until recovery appears

# Transfer the zip file to the device
adb push lineage-21.0-*-n8010.zip /sdcard/

# In TWRP Recovery:
# 1. Wipe > Format Data (type "yes" to confirm)
# 2. Wipe > Advanced Wipe > Select System, Cache, Dalvik
# 3. Install > Select the lineage zip file
# 4. Swipe to confirm flash
# 5. Reboot System

# First boot will take 5-10 minutes
```

## Applied Fixes in This Device Tree

### 1. SELinux Permissive Mode (BoardConfig.mk)
- **Temporary fix** for binder access issues
- Allows apps to properly initialize ProcessState
- TODO: Create proper SELinux policies for production use

### 2. Wide Color Display Workaround (system.prop)
- Disables wide color gamut queries
- Prevents EGL from querying missing HIDL configstore service
- Fixes graphics initialization on non-Treble devices

### 3. Camera Multi-User Fix (init.target.rc)
- Forces user 0 into camera service whitelist after boot
- Fixes "camera in use" errors on multi-user systems

## Testing After Flash

1. **DocumentsUI (File Explorer)**: Should open without crashing
2. **Camera Apps**: Should initialize without "camera in use" errors  
3. **Home Assistant**: Should launch and connect properly
4. **Binder**: Apps should not crash with ProcessState errors

## Known Issues
- SELinux is in permissive mode (less secure, but necessary for stability)
- Some system apps may still have compatibility issues with Android 14

## Next Steps for Production
1. Create proper SELinux policies to replace permissive mode
2. Test all critical apps (especially Home Assistant)
3. Create proper unit tests for device tree changes
4. Consider upstreaming fixes to LineageOS gerrit
