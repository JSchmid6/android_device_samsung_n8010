#!/system/bin/sh
# Debug-Hilfe (Build 31): crash_dump32 stuerzt beim Dump von surfaceflinger
# selbst ab, es gibt keinen Tombstone. Der Kernel liefert mit user_debug=31
# nur pc/lr; um die einer Bibliothek zuzuordnen, braucht man /proc/<pid>/maps
# des sterbenden Prozesses. Dieses Skript wird von init.target.rc bei jedem
# Start von surfaceflinger angestossen und schreibt maps so lange neu, bis der
# Prozess weg ist. Der letzte Stand bleibt in /data/local/tmp/sf_maps.txt.
OUT=/data/local/tmp
mkdir -p $OUT
p=$(pidof surfaceflinger) || exit 0
n=0
while [ -d /proc/$p ] && [ $n -lt 100 ]; do
    cat /proc/$p/maps > $OUT/sf_maps.tmp 2>/dev/null && mv -f $OUT/sf_maps.tmp $OUT/sf_maps.txt
    n=$((n+1))
    sleep 0.1
done
echo "pid $p, $n Schnappschuesse" > $OUT/sf_maps.info
