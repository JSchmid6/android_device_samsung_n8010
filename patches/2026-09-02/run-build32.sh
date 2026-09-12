#!/bin/bash
# Build 32 — adbd bekommt den synchronen FunctionFS-Pfad zurueck
#
# Aenderung gegenueber Build 31 (nur packages/modules/adb):
#   Patch "adb: Bring back support for legacy FunctionFS" (Arne Coucheron,
#   2021, aus html6405/android_packages_modules_adb lineage-20.0, Commit
#   ba39fe821) auf den Android-14-Stand portiert. Neu: daemon/usb_legacy.cpp,
#   daemon/usb_legacy.h, daemon/usb_dummy.cpp, transport_legacy.cpp;
#   geaendert: Android.bp (-DLEGACY_FFS=1), daemon/usb.cpp (Fallback +
#   Property-Auswertung), transport.cpp/.h (#if ADB_HOST || LEGACY_FFS,
#   von Hand angepasst, da sich der Kontext seit Android 13 verschoben hat).
#
# Befund aus Boot 31 (erster Boot, bei dem adbd ueberhaupt existierte,
# nachdem die .capex-Aktivierung mit PRODUCT_COMPRESSED_APEX := false
# umgangen wurde):
# - Tablet enumeriert stabil als 04e8:6860 mit ADB-Interface (Klasse ff,
#   ep_01/ep_82), adb devices pendelt zwischen "offline" und weg -- der
#   Host bekommt auf CNXN nie eine Antwort.
# - adbd (Android 14) kennt nur noch AIO (io_submit) auf den ffs-Endpunkten;
#   der synchrone Pfad wurde 2020 entfernt (adb-Commit 6b55e755). Kernel 3.4
#   f_fs.c hat keine aio_read/aio_write -> fs/aio.c aio_setup_iocb liefert
#   -EINVAL -> adbd "failed to submit read" -> Verbindung zu, von vorn.
# - ro.adb.nonblocking_ffs=false (common.mk:88), sys.usb.ffs.aio_compat=1 und
#   persist.adb.nonblocking_ffs=0 (init.smdk4x12.rc) waren dafuer schon
#   vorgesehen und werden mit dem Patch wieder ausgewertet.
#
# Ablauf: zuerst nur adbd bauen (Compile-Test des Patches, schlaegt schnell
# fehl), danach mka bacon. Drosselung wie gehabt: 4 Jobs, nice 15, ionice 7.
SRC=/media/RAID/lineageos-build/src
LOG=$SRC/build32.log
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

step "mka adbd -j$JOBS (Compile-Test)"
mka -j"$JOBS" adbd
rc=$?
step "ADBD_EXIT=$rc"
[ "$rc" -eq 0 ] || { step "Abbruch, adbd baut nicht"; exit "$rc"; }

step "mka bacon -j$JOBS"
mka -j"$JOBS" bacon
step "BUILD_EXIT=$?"
