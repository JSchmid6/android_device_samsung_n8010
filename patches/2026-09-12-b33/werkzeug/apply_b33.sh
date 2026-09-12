#!/bin/bash
# Build-33-Quellen in den Build-Baum uebernehmen: pro Repo lokale Aenderungen
# stashen (bleiben als Stash erhalten) und auf den Commit des Branches
# n8010-b33 (aus den Worktrees unter ~/n8010-wt) detached auschecken.
# Erst ausfuehren, wenn Build 32 fertig ist (kein ninja auf dem RAID).
set -u
SRC=/media/RAID/lineageos-build/src
LOG=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad/apply_b33.log
exec >>"$LOG" 2>&1
echo "=== Start $(date +%H:%M:%S)"
REPOS="frameworks/native system/core bionic system/libhidl system/vold hardware/interfaces packages/modules/Connectivity frameworks/base vendor/lineage kernel/samsung/smdk4412"
for r in $REPOS; do
  cd "$SRC/$r" || { echo "FEHLER: $r fehlt"; continue; }
  echo "=== $r  ($(date +%H:%M:%S))"
  target=$(git rev-parse --verify -q n8010-b33) || { echo "FEHLER: Branch n8010-b33 fehlt in $r"; continue; }
  echo "  Ziel: $target  aktuell: $(git rev-parse HEAD)"
  nice -n 10 ionice -c2 -n7 git stash push -m "b32-lokal-vor-b33 $(date +%F)" 2>&1 | tail -1
  nice -n 10 ionice -c2 -n7 git checkout -q --detach n8010-b33 2>&1 | tail -3
  echo "  HEAD jetzt: $(git rev-parse HEAD) $(git log -1 --format=%s | cut -c1-70)"
  [ "$(git rev-parse HEAD)" = "$target" ] && echo "  OK" || echo "  FEHLER: Checkout nicht am Ziel"
done
echo "=== FERTIG $(date +%H:%M:%S)"
