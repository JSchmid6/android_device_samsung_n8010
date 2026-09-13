#!/bin/bash
# Faengt den ersten Boot von Build 33 ab: wartet, bis das Geraet TWRP verlaesst,
# meldet USB-Enumeration und adb-Zustand, sammelt dann logcat/dmesg/ps/getprop
# und die maps von surfaceflinger.
D=$HOME/n8010-logs/b33-boot1
mkdir -p "$D"
ts() { date +%H:%M:%S; }
echo "$(ts) warte auf Reboot (adb-Zustand: $(adb get-state 2>/dev/null))"
while [ "$(adb get-state 2>/dev/null)" = "recovery" ]; do sleep 1; done
echo "$(ts) Geraet hat TWRP verlassen — bootet"
t0=$(date +%s); lastusb=""; laststate=""
while :; do
  el=$(( $(date +%s) - t0 ))
  usb=$(lsusb 2>/dev/null | grep -E ' 04e8:| 18d1:' | sed 's/.*ID //')
  [ "$usb" != "$lastusb" ] && { echo "$(ts) +${el}s USB: ${usb:-nichts}"; lastusb=$usb; }
  st=$(adb devices 2>/dev/null | awk 'NR>1 && NF{print $2}' | head -1)
  [ "$st" != "$laststate" ] && { echo "$(ts) +${el}s adb: ${st:-kein Geraet}"; laststate=$st; }
  [ "$st" = "device" ] && break
  [ $el -gt 900 ] && { echo "$(ts) TIMEOUT: kein adb nach 15 min (USB zuletzt: ${usb:-nichts})"; exit 1; }
  sleep 2
done
echo "$(ts) ADB ONLINE nach ${el}s — sammle als shell"
adb logcat -b all -v threadtime > "$D/logcat-shell.txt" 2>&1 & LC=$!
adb shell cat /proc/last_kmsg > "$D/last_kmsg.txt" 2>/dev/null
adb shell dmesg > "$D/dmesg-0.txt" 2>/dev/null
adb shell getprop > "$D/getprop-0.txt" 2>/dev/null
adb shell ps -A > "$D/ps-0.txt" 2>/dev/null
echo "$(ts) dmesg $(wc -l < "$D/dmesg-0.txt") Zeilen, ps $(wc -l < "$D/ps-0.txt") Prozesse, uname: $(adb shell uname -r 2>/dev/null)"
sleep 30
kill $LC 2>/dev/null
echo "$(ts) adb root ..."
adb root >/dev/null 2>&1; sleep 4; adb wait-for-device
echo "$(ts) nach adb root: $(adb shell id 2>/dev/null | cut -c1-40)"
adb logcat -b all -v threadtime > "$D/logcat-root.txt" 2>&1 & LC=$!
lastsf=""; lastcr=-1
for i in $(seq 1 24); do
  adb shell dmesg > "$D/dmesg-$i.txt" 2>/dev/null
  adb shell ps -A > "$D/ps-$i.txt" 2>/dev/null
  pid=$(adb shell pidof surfaceflinger 2>/dev/null | tr -d '\r ')
  [ -n "$pid" ] && [ ! -s "$D/sf-maps-$pid.txt" ] && adb shell cat /proc/$pid/maps > "$D/sf-maps-$pid.txt" 2>/dev/null
  zy=$(adb shell pidof zygote 2>/dev/null | tr -d '\r ')
  bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  cr=$(cat "$D"/logcat-*.txt 2>/dev/null | grep -c 'Fatal signal')
  if [ "$pid" != "$lastsf" ] || [ "$cr" != "$lastcr" ] || [ $((i % 6)) -eq 0 ]; then
    echo "$(ts) tick $i: surfaceflinger=${pid:-tot} zygote=${zy:-tot} boot_completed=${bc:-0} 'Fatal signal'=$cr"
    lastsf=$pid; lastcr=$cr
  fi
  [ "$bc" = "1" ] && { echo "$(ts) BOOT_COMPLETED"; break; }
  sleep 20
done
adb shell getprop > "$D/getprop-end.txt" 2>/dev/null
sleep 5; kill $LC 2>/dev/null
echo "$(ts) FERTIG — Logs in $D"
