#!/bin/bash
# Holt html6405s lineage-21.0-Branches in die Build-Tree-Repos (nur .git) und
# listet Commits, die unser HEAD nicht hat.
SRC=/media/RAID/lineageos-build/src
OUT=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad/forks
mkdir -p "$OUT"
while read -r path repo branch; do
  [ -z "$path" ] && continue
  echo "=== $path  <-  html6405/$repo@$branch"
  cd "$SRC/$path" || { echo "  FEHLT: $path"; continue; }
  if ! git fetch -q https://github.com/html6405/$repo "$branch" 2>"$OUT/$repo.fetch.err"; then
    echo "  FETCH FEHLGESCHLAGEN: $(tail -1 "$OUT/$repo.fetch.err")"; continue
  fi
  git update-ref "refs/html6405/$branch" FETCH_HEAD
  mb=$(git merge-base HEAD FETCH_HEAD)
  echo "  HEAD=$(git rev-parse --short HEAD) $(git log -1 --format=%cs HEAD)  fork=$(git rev-parse --short FETCH_HEAD) $(git log -1 --format=%cs FETCH_HEAD)  merge-base=$(git rev-parse --short $mb) $(git log -1 --format=%cs $mb)"
  n_theirs=$(git rev-list --count --no-merges $mb..FETCH_HEAD)
  n_ours=$(git rev-list --count --no-merges $mb..HEAD)
  echo "  Fork-eigene Commits: $n_theirs   Upstream-Commits die dem Fork fehlen: $n_ours"
  git log --no-merges --format='%h %as %an: %s' $mb..FETCH_HEAD > "$OUT/$repo.commits.txt"
  head -40 "$OUT/$repo.commits.txt" | sed 's/^/    /'
  [ "$n_theirs" -gt 40 ] && echo "    ... (Rest in $OUT/$repo.commits.txt)"
done <<'LIST'
bionic android_bionic lineage-21.0
system/core android_system_core lineage-21.0
system/vold android_system_vold lineage-21.0
system/libhidl android_system_libhidl lineage-21.0
frameworks/native android_frameworks_native lineage-21.0-r08
frameworks/av android_frameworks_av lineage-21.0
frameworks/base android_frameworks_base lineage-21.0
hardware/interfaces android_hardware_interfaces lineage-21.0
build/make android_build lineage-21.0
build/soong android_build_soong lineage-21.0
vendor/lineage android_vendor_lineage lineage-21.0
hardware/samsung android_hardware_samsung lineage-21.0-exynos4
hardware/lineage/interfaces android_hardware_lineage_interfaces lineage-21.0
frameworks/ex android_frameworks_ex lineage-21.0
frameworks/opt/net/wifi android_frameworks_opt_net_wifi lineage-21.0
frameworks/opt/telephony android_frameworks_opt_telephony lineage-21.0
packages/services/Telephony android_packages_services_Telephony lineage-21.0
packages/apps/SetupWizard android_packages_apps_SetupWizard lineage-21.0
system/nfc android_system_nfc lineage-21.0
packages/modules/Connectivity android_packages_modules_Connectivity_UL lineage-21.0
LIST
echo "=== FERTIG"
