#!/bin/bash
# Kernel-Worktree ab html6405/lineage-21.0-BPF; wartet auf frameworks/base-Runde.
S=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad
SRC=/media/RAID/lineageos-build/src/kernel/samsung/smdk4412
WT=$HOME/n8010-wt/kernel
until grep -q '^=== FERTIG' $S/wt_setup_base.log 2>/dev/null; do sleep 20; done
echo "=== kernel worktree start $(date +%H:%M:%S)"
cd $SRC && nice -n 19 ionice -c3 git worktree add -b n8010-b33 "$WT" refs/html6405/lineage-21.0-BPF && echo "=== kernel worktree fertig $(date +%H:%M:%S)" || echo "=== kernel worktree FEHLGESCHLAGEN"
cd "$WT" && git log --oneline -1
echo "=== FERTIG"
