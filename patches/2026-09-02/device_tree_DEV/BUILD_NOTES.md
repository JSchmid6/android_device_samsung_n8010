# LineageOS 21 Build Notes for Samsung Galaxy Note 10.1 (n8010)

## Build Status

**Date:** 2025-12-28  
**Device:** Samsung Galaxy Note 10.1 WiFi (GT-N8010)  
**ROM:** LineageOS 21.0 (Android 14)  
**Build Type:** userdebug  
**Architecture:** ARMv7-A NEON, Cortex-A9

## Current Build Configuration

### Build Command
```bash
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010
./docker-build.sh build
```

### Environment
- **Build System:** Docker container (Ubuntu 22.04)
- **Source Location:** `/media/RAID/lineageos-build/src`
- **ccache:** 50GB on `/media/RAID/lineageos-build/ccache`
- **Output:** `/media/RAID/lineageos-build/out`

### Special Flags
```bash
ALLOW_MISSING_DEPENDENCIES=true
```

## Applied Fixes

### 1. Health Service HAL (Resolved)
**Problem:** Android 14 incompatible health@2.0 service  
**Solution:** Disabled health service
```bash
mv hardware/samsung/exynos4/interfaces/health/Android.bp.disabled \
   hardware/samsung/exynos4/interfaces/health/Android.bp.disabled.bak
```

### 2. SamsungServiceMode (Resolved)
**Problem:** Missing SamsungServiceMode app  
**Solution:** Commented out in hardware/samsung/Android.mk line 52
```makefile
# include $(SAM_ROOT)/SamsungServiceMode/Android.mk
```

### 3. Mali GPU Blobs (Workaround Active)
**Problem:** Missing proprietary Mali GPU libraries (libMali)  
**Current Solution:** Build with `ALLOW_MISSING_DEPENDENCIES=true`  
**Impact:** 
- System will boot and run
- GPU acceleration may fall back to software rendering
- Sufficient for Home Assistant dashboard use

**Permanent Solution (TODO):**
Extract proprietary blobs from running device:
```bash
# Connect tablet via ADB
adb devices

# Run extraction script
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010
./extract-files.sh

# Scripts cascade:
# n8010/extract-files.sh -> n80xx-common/extract-files.sh -> smdk4412-common/extract-files.sh

# Files will be extracted to:
# vendor/samsung/n80xx/
# vendor/samsung/smdk4412-common-treble/
```

## Device-Specific Modifications

### System Properties (`system.prop`)
- Lines 15-17: Wide color display HAL workarounds
- Lines 63-65: Camera lazy HAL loading properties

### Board Configuration (`BoardConfig.mk`)
- Line 34: SELinux permissive mode (temporary for Binder debugging)
  ```makefile
  BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
  ```

### Init Script (`init.target.rc`)
- Lines 49-52: Camera user whitelist initialization on boot

### Removed Dependencies
- `n80xx-common` and `smdk4412-common` includes in `lineage_n8010.mk` were initially removed
- Later restored after syncing dependency repositories

## Dependencies Synced

Added to `.repo/local_manifests/roomservice.xml`:
- `android_device_samsung_n8010`
- `android_device_samsung_n80xx-common`
- `android_device_samsung_smdk4412-common`
- `android_kernel_samsung_smdk4412`
- `android_packages_apps_SamsungServiceMode` (not used)
- `android_hardware_samsung`

## Known Issues

### Current Build
1. **No Treble support** - Expected warning, device is non-Treble
2. **Filesystem loop warning** - Caused by copied `.git` in device tree (harmless)
3. **Missing vendor blobs** - GPU acceleration not available until blobs extracted

### Runtime Issues (from previous ROM)
1. **Camera:** Fixed with user whitelist in init.target.rc
2. **Apps crashing:** Fixed with SELinux permissive mode
3. **Binder access issues:** Workaround with SELinux permissive

## Post-Build TODO

### 1. Extract Vendor Blobs
When ROM boots successfully:
```bash
# Enable ADB on tablet
# Settings -> About -> Tap Build Number 7x -> Developer Options -> Enable ADB

# From build machine
adb root
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010
./extract-files.sh

# Rebuild with vendor blobs
cd /home/jochen/DEV/lineagos/android_device_samsung_n8010
docker exec -u build lineageos-build bash -c "
  cd /lineage/src/device/samsung/smdk4412-common
  sed -i '393s/^# //' common.mk  # Uncomment vendor blob include
"
./docker-build.sh build
```

### 2. SELinux Policy (Security Hardening)
Current: SELinux is permissive (insecure)  
Goal: Create proper policies, enable enforcing mode

```bash
# After stable boot, collect denials
adb shell dmesg | grep avc: audit: > /tmp/denials.txt

# Create custom policies in:
# device/samsung/n80xx-common/sepolicy/
```

### 3. Test & Verify
- [ ] Boot test
- [ ] WiFi connectivity
- [ ] Touch screen
- [ ] Camera (with whitelist fix)
- [ ] Audio playback
- [ ] Home Assistant app installation (F-Droid or Aurora Store)
- [ ] GPU performance (check `dumpsys SurfaceFlinger`)

### 4. Optimization
- [ ] Remove unnecessary apps to reduce ROM size
- [ ] Optimize heap sizes for tablet use
- [ ] Test battery drain on idle

## Installation

### Prerequisites
- Unlocked bootloader
- TWRP recovery installed
- Backup of current ROM

### Flash Instructions
```bash
# Copy ROM to device
adb push /media/RAID/lineageos-build/out/target/product/n8010/lineage-21.0-*-n8010.zip /sdcard/

# Boot to recovery
adb reboot recovery

# In TWRP:
# 1. Wipe -> Factory Reset
# 2. Install -> Select lineage-21.0-*-n8010.zip
# 3. Wipe dalvik/cache
# 4. Reboot System
```

## Build Time Estimates

- **Clean build:** 2-6 hours (depending on hardware)
- **Incremental build:** 10-30 minutes
- **Kernel only:** ~30 minutes

## References

- Original device tree: https://github.com/html6405/android_device_samsung_n8010
- LineageOS Wiki: https://wiki.lineageos.org/devices/n8010/
- n8010 XDA Thread: https://forum.xda-developers.com/t/samsung-galaxy-note-10-1-gt-n8010.1807970/

## Project Goal

Convert Samsung Galaxy Note 10.1 tablet into a dedicated Home Assistant wall-mounted dashboard with:
- Stable LineageOS 21 (Android 14)
- All hardware functional (camera, WiFi, touch)
- Minimal bloat
- Aurora Store for app updates
- Optimized for 24/7 operation
