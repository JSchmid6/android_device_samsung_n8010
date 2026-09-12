#!/bin/bash
# Zweite Runde: frameworks/base (Auswahl) — wartet bis wt_setup.sh fertig ist.
S=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad
until grep -q '^=== FERTIG' $S/wt_setup.log; do sleep 15; done
sed -e '/^done <<.LIST.$/,/^LIST$/c\
done <<'"'"'LIST'"'"'\
frameworks/base android_frameworks_base lineage-21.0\
LIST' $S/wt_setup.sh > $S/wt_setup_base.sh
chmod +x $S/wt_setup_base.sh
$S/wt_setup_base.sh
