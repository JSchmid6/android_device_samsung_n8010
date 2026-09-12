#!/bin/bash
# Build 33 — html6405-Forks nachgezogen, Kernel auf lineage-21.0-BPF
#
# Befund nach Build 32: html6405 baut seine LOS-21-Images nicht mit
# Stock-LineageOS, sondern mit ~20 eigenen Framework-Forks und dem
# Kernel-Branch lineage-21.0-BPF (eBPF-Backport + ARM-JIT, renameat2,
# Kernelversion nach aussen "4.9.337", aktuelle Defconfigs). Unser Manifest
# hatte Stock-LineageOS und den veralteten Kernel-Branch lineage-21.0.
#
# Aenderungen gegenueber Build 32 (alle als Cherry-Picks auf unsere
# neueren Upstream-Staende, Branch n8010-b33 im jeweiligen Repo):
#   kernel/samsung/smdk4412  -> lineage-21.0-BPF (f29c7c3c576) + lineageos_n8010_defconfig
#                               (aus lineageos_n8000_defconfig, user_debug=31,
#                               LOG_BUF_SHIFT=20) + dm-verity argc>=10
#   frameworks/native        16 Fork-Commits, u.a. GLESRenderEngine zurueck
#                               (debug.renderengine.backend=gles greift damit erst),
#                               PostRenderCleanup-Skip, Gralloc-Usage-Bits
#   system/core               6 Fork-Commits (Freezer/Schedtune cgroup v1,
#                               inprocess tethering, reboot-to-recovery, healthd)
#   bionic                    7 Fork-Commits (SDK-Override im Linker, hosts-Cache,
#                               pre-P-Mutex, inaddr.h, pthread_t-Hack) + rename()->renameat
#   system/libhidl 2, system/vold 1, hardware/interfaces 4 (wifi-HIDL, Audio-Reverts)
#   packages/modules/Connectivity 13 Connectivity_UL-Commits (no-BPF-Faelle,
#                               netd wartet nicht auf bpf.progs_loaded), bpfloader
#                               wird jetzt nicht-blockierend gestartet
#   frameworks/base          10 ausgewaehlte Commits (Freezer cgroup v1, cgroup-
#                               Fehler ignorieren, ColorFade-EGL-Fix, Ripple/Stretch)
#   vendor/lineage            2 Soong-Configs (process_sdk_version_overrides_defaults,
#                               disable_postrender_cleanup_defaults) fuer bionic/SF
#   device: config_displayColorFadeDisabled=true statt config_colorFade_enabled
#
# Ablauf: erst bootimage (Kernel-Compile-Test auf dem neuen Branch), dann
# mka bacon. Drosselung wie gehabt: 4 Jobs, nice 15, ionice 7.
SRC=/media/RAID/lineageos-build/src
LOG=$SRC/build33.log
JOBS="${JOBS:-4}"

export GOMAXPROCS="$JOBS"
export SOONG_JAVAC_WRAPPER=""
export _JAVA_OPTIONS="-Xmx2g"

step() { echo "=== [$(date +%H:%M:%S)] $* ===" >> "$LOG"; }

exec >>"$LOG" 2>&1
step "Start, PID $$, JOBS=$JOBS"
cd "$SRC" || { step "cd fehlgeschlagen"; exit 1; }

step "envsetup"
source build/envsetup.sh >/dev/null 2>&1
step "envsetup rc=$?"

step "lunch"
lunch lineage_n8010-ap2a-userdebug >/dev/null 2>&1
step "lunch rc=$?"

renice -n 15 -p $$ >/dev/null 2>&1
ionice -c2 -n7 -p $$ >/dev/null 2>&1
step "Prioritaet: nice=$(ps -o ni= -p $$ | tr -d ' ')"

step "mka bootimage -j$JOBS (Kernel-Compile-Test, Branch lineage-21.0-BPF)"
mka -j"$JOBS" bootimage
rc=$?
step "BOOTIMAGE_EXIT=$rc"
[ "$rc" -eq 0 ] || { step "Abbruch, Kernel baut nicht"; exit "$rc"; }

step "mka bacon -j$JOBS"
mka -j"$JOBS" bacon
step "BUILD_EXIT=$?"
