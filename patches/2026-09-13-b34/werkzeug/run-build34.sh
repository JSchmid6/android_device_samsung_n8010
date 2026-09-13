#!/bin/bash
# Build 34 — Mali-Blobs auf UK-API 29, adbd-Transport startet, tombstoned ohne O_TMPFILE
#
# Befund aus dem ersten Boot von Build 33 (persistierter logcat aus
# /data/misc/logd, Kernel/init/apexd/vold/bpfloader/USB-Gadget alle ok):
#   1. surfaceflinger stirbt ~90x mit SIGSEGV (fault addr 0x200) in
#      egl_display_t::initialize -> findExtension -> strstr. Ursache davor
#      im Log: "Device driver API mismatch, Device driver API version: 29,
#      User space API version: 23" -> eglInitialize EGL_BAD_ALLOC. Unser
#      libMali.so stammt aus N8010XXUDNE4 (Maerz 2014, UK-API 23), der
#      Kernel-Mali-Treiber (r3p2, Commit bea61001a38) verlangt API 29.
#   2. adbd laeuft (legacy FunctionFS), Host sieht "offline": AOSP-Commit
#      36c8520873d5 setzt in fdevent_register_transport() jeden
#      kTransportUsb-Transport auf kCsDetached, auch auf dem Geraet.
#   3. tombstoned stirbt beim Start: O_TMPFILE gibt es erst ab Linux 3.11,
#      AOSP aa1d18a59 hat den Fallback entfernt.
#   4. USB-Bus-Resets alle 20-45 s kommen vom Host (04e8:6860 ist in libmtp
#      als MTP-Geraet gelistet, gvfs probt).
#
# Aenderungen gegenueber Build 33:
#   vendor/samsung/smdk4412-common/proprietary/lib/libMali.so + egl/libGLESv{1_CM,2}_mali.so
#       -> html6405-Stand (T311XXUBNH6, Juli 2014, "mov r1, #29"); Originale in
#          /media/RAID/lineageos-build/backup/mali-api23-from-N8010XXUDNE4/
#   packages/modules/adb/transport.cpp
#       -> Detached-Start nur unter ADB_HOST, Geraet startet jeden Transport
#   system/core (n8010-b33 + 1)
#       -> Revert aa1d18a59 (tombstoned: Fallback auf .temporaryN ohne O_TMPFILE)
#   frameworks/native (n8010-b33 + lokal)
#       -> libEGL: queryString nullinitialisiert, initialize() bricht nach
#          fehlgeschlagenem eglInitialize sauber mit EGL_NOT_INITIALIZED ab
#   device/samsung/smdk4412-common/rootdir/init.smdk4x12.usb.rc
#       -> sys.usb.config=adb meldet sich als 18d1:4ee7 statt 04e8:6860
#
# Ablauf wie Build 33: bootimage, dann mka bacon. 4 Jobs, nice 15, ionice 7.
SRC=/media/RAID/lineageos-build/src
LOG=$SRC/build34.log
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

step "mka bootimage -j$JOBS"
mka -j"$JOBS" bootimage
rc=$?
step "BOOTIMAGE_EXIT=$rc"
[ "$rc" -eq 0 ] || { step "Abbruch, bootimage baut nicht"; exit "$rc"; }

step "mka bacon -j$JOBS"
mka -j"$JOBS" bacon
step "BUILD_EXIT=$?"
