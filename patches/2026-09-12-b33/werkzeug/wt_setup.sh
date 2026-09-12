#!/bin/bash
# Legt fuer jedes Repo, das Fork-Commits bekommen soll, einen Worktree auf der
# Home-Platte an (Branch n8010-b33 ab aktuellem HEAD), uebernimmt unsere
# uncommitteten Build-Baum-Aenderungen als ersten Commit und versucht dann die
# html6405-Fork-Commits (aelteste zuerst) per Cherry-Pick.
SRC=/media/RAID/lineageos-build/src
WT=$HOME/n8010-wt
S=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad
mkdir -p "$WT" "$S/cp"
while read -r path repo branch; do
  [ -z "$path" ] && continue
  name=${path//\//_}
  echo "=== $path -> $WT/$name  ($(date +%H:%M:%S))"
  ref="refs/html6405/$branch"
  cd "$SRC/$path" || continue
  if [ -e "$WT/$name" ]; then
    echo "  Worktree existiert schon, setze fort"
    cd "$WT/$name"
  else
    nice -n 19 ionice -c3 git worktree add -q -b n8010-b33 "$WT/$name" HEAD || { echo "  worktree add FEHLGESCHLAGEN"; continue; }
    # unsere lokalen Aenderungen (tracked) mitnehmen
    nice -n 19 ionice -c3 git diff HEAD > "$S/cp/$name.local.patch"
    cd "$WT/$name"
  fi
  if git log --format=%s -20 | grep -q '^n8010: lokale Aenderungen'; then
    echo "  lokale Aenderungen bereits committed"
  elif [ -s "$S/cp/$name.local.patch" ]; then
    if git apply "$S/cp/$name.local.patch"; then
      git add -A && git commit -q -m "n8010: lokale Aenderungen aus dem Build-Baum (Stand Build 32)" && echo "  lokale Aenderungen committed: $(git diff --stat HEAD~1 | tail -1)"
    else
      echo "  lokale Aenderungen: apply FEHLGESCHLAGEN"
    fi
  else
    echo "  keine lokalen Aenderungen"
  fi
  mb=$(git merge-base HEAD "$ref")
  uniq="$S/forks/$repo.unique.hashes"
  sel="$S/cp/$name.select"   # optionale Auswahl (Hashes), sonst alle unique
  [ -s "$sel" ] && uniq="$sel"
  ok=0; fail=0
  for h in $(git rev-list --reverse --no-merges "$mb..$ref"); do
    grep -q "^${h:0:7}" "$uniq" || continue
    subj=$(git log -1 --format=%s "$h")
    if git log --format=%b "$mb..HEAD" | grep -q "cherry picked from commit $h"; then
      echo "  SCHON ${h:0:10} $subj"; ok=$((ok+1)); continue
    fi
    if git cherry-pick -x --allow-empty "$h" >/dev/null 2>"$S/cp/$name.err"; then
      ok=$((ok+1)); echo "  OK   ${h:0:10} $subj"
    else
      if git diff --name-only --diff-filter=U | grep -q .; then
        echo "  KONFLIKT ${h:0:10} $subj  -> $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
        git diff > "$S/cp/$name.${h:0:10}.conflict.diff"
        git cherry-pick --abort
      else
        echo "  FEHLER ${h:0:10} $subj: $(head -3 "$S/cp/$name.err" | tr '\n' ' ')"
        git cherry-pick --abort 2>/dev/null
      fi
      fail=$((fail+1))
    fi
  done
  echo "  Ergebnis: $ok uebernommen, $fail offen"
done <<'LIST'
frameworks/native android_frameworks_native lineage-21.0-r08
system/core android_system_core lineage-21.0
bionic android_bionic lineage-21.0
system/libhidl android_system_libhidl lineage-21.0
system/vold android_system_vold lineage-21.0
hardware/interfaces android_hardware_interfaces lineage-21.0
packages/modules/Connectivity android_packages_modules_Connectivity_UL lineage-21.0
LIST
echo "=== FERTIG $(date +%H:%M:%S)"
