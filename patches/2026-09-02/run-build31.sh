#!/bin/bash
# Build 31 — reiner Debug-Build, keine Aenderung an der Grafikkette
#
# Aenderungen gegenueber Build 30 (alle in device/samsung/n8010):
#   BoardConfig.mk   audit=0 -> user_debug=31
#   vendor_prop.mk   ro.logd.auditd.dmesg=false
#                    persist.logd.logpersistd=logcatd, .size=32
#   init.target.rc   on property:init.svc.surfaceflinger=running
#                      -> exec_background /vendor/bin/sf_maps_snapshot.sh
#   n8010.mk         kopiert rootdir/sf_maps_snapshot.sh nach /vendor/bin
#
# Befund aus Build 30 (/proc/last_kmsg, 8,86 Tage im Crash-Loop):
# - audit=0 hat nichts gebracht: die avc-Zeilen tragen Praefix <38>
#   (LOG_AUTH|LOG_INFO), das ist logd/LogAudit.cpp, das sie selbst nach
#   /dev/kmsg schreibt. Abschalten geht nur ueber ro.logd.auditd.dmesg=false.
# - surfaceflinger erreicht den Mali-Treiber ("Mali: mem_usage before <pid>"
#   = erster ioctl nach open /dev/mali) und stirbt ~200 ms spaeter mit SIGSEGV.
# - Kein Tombstone, weil crash_dump32 beim Dump selbst mit SIGSEGV stirbt
#   ("Untracked pid ... received signal 11" direkt vor dem Tod von
#   surfaceflinger bzw. gpuservice). Fuer den einfaedigen mediaextractor
#   funktioniert crash_dump (SIGABRT, DEBUG-Block im Log).
# Deshalb jetzt Register-Dump durch den Kernel (user_debug=31 bei
# CONFIG_DEBUG_USER=y), maps-Schnappschuss per init-Hook und persistenter
# logcat unter /data/misc/logd.

# Drosselung wie bei Build 25/26: 4 Jobs, nice 15, ionice best-effort 7.
SRC=/media/RAID/lineageos-build/src
LOG=$SRC/build31.log
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

step "mka bacon -j$JOBS"
mka -j"$JOBS" bacon
step "BUILD_EXIT=$?"
