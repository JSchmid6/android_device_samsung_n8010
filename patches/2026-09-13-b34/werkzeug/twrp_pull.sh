#!/bin/bash
# Nach dem erzwungenen Reset in TWRP: last_kmsg, logcatd-Dateien, Tombstones
# einsammeln; Host-adb-Key nach /data/misc/adb/adb_keys legen.
D=$HOME/n8010-logs/b33-boot1
mkdir -p "$D"
ts() { date +%H:%M:%S; }
st=$(adb get-state 2>/dev/null); echo "$(ts) adb-Zustand: ${st:-keins}"
[ "$st" = "recovery" ] || { echo "nicht in TWRP — Abbruch"; exit 1; }
adb shell 'cat /proc/last_kmsg' > "$D/last_kmsg.txt" 2>/dev/null
echo "$(ts) last_kmsg: $(wc -c < "$D/last_kmsg.txt") Bytes, $(wc -l < "$D/last_kmsg.txt") Zeilen"
adb shell 'mount /data 2>/dev/null; ls -la /data/misc/logd/ /data/tombstones/ 2>&1; ls /data/misc/adb/ 2>&1' 2>/dev/null | grep -v tzdata
for f in $(adb shell 'ls /data/misc/logd/ 2>/dev/null' | tr -d '\r'); do adb pull "/data/misc/logd/$f" "$D/" >/dev/null 2>&1; done
for f in $(adb shell 'ls /data/tombstones/ 2>/dev/null' | tr -d '\r'); do adb pull "/data/tombstones/$f" "$D/" >/dev/null 2>&1; done
adb pull /data/system/dropbox "$D/dropbox" >/dev/null 2>&1
echo "$(ts) gezogen: $(ls "$D" | tr '\n' ' ')"
# Host-Key hinterlegen (adbd liest /data/misc/adb/adb_keys, system:shell 0640)
adb shell 'mkdir -p /data/misc/adb' 2>/dev/null
adb push "$HOME/.android/adbkey.pub" /data/misc/adb/adb_keys >/dev/null 2>&1 \
  && adb shell 'chown 1000:2000 /data/misc/adb /data/misc/adb/adb_keys; chmod 02750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys; ls -la /data/misc/adb/' 2>/dev/null | grep -v tzdata
echo "$(ts) FERTIG"
