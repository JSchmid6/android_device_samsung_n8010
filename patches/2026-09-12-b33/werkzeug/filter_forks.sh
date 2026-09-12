#!/bin/bash
# Filtert die Fork-Commits: nur solche, deren Betreff in unserer HEAD-Historie
# seit merge-base NICHT vorkommt (LineageOS rebased eigene Patches -> neue Hashes).
SRC=/media/RAID/lineageos-build/src
OUT=/tmp/claude-1000/-home-jochen/883c600e-21b0-4b51-a555-2f1b1652608a/scratchpad/forks
while read -r path repo branch; do
  [ -z "$path" ] && continue
  cd "$SRC/$path" || continue
  ref="refs/html6405/$branch"
  git rev-parse -q --verify "$ref" >/dev/null || { echo "=== $path: kein Ref $ref"; continue; }
  mb=$(git merge-base HEAD "$ref")
  git log --no-merges --format='%s' $mb..HEAD | sort -u > "$OUT/$repo.ours.subjects"
  git log --no-merges --format='%h %as %an: %s' $mb..$ref > "$OUT/$repo.theirs.txt"
  n_all=$(wc -l < "$OUT/$repo.theirs.txt")
  # Betreff = alles nach ": " des Autors -> robuster: Betreff separat holen
  git log --no-merges --format='%h%x09%s' $mb..$ref | while IFS=$'\t' read -r h subj; do
    grep -qxF -- "$subj" "$OUT/$repo.ours.subjects" || echo "$h"
  done > "$OUT/$repo.unique.hashes"
  n_uniq=$(wc -l < "$OUT/$repo.unique.hashes")
  echo "=== $path: $n_all Fork-Commits, davon $n_uniq ohne Gegenstueck bei uns"
  while read -r h; do git log -1 --format='    %h %as %an: %s' "$h"; done < "$OUT/$repo.unique.hashes" > "$OUT/$repo.unique.txt"
  head -60 "$OUT/$repo.unique.txt"
  [ "$n_uniq" -gt 60 ] && echo "    ... (Rest in $OUT/$repo.unique.txt)"
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
