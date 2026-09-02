# Patch-Set 2026-09-02 — gesicherte Arbeit aus dem Build-Baum

Diese Patches sichern rund acht Monate Arbeit, die ausschließlich als uncommittete
Änderungen im Build-Baum `/media/RAID/lineageos-build/src` und im Device-Tree
existierte. Ein `repo sync` oder ein versehentliches `git checkout` hätte sie
vernichtet.

**Nichts hiervon wurde am Build verändert** — die Patches sind Kopien des Zustands
vom 2. September 2026.

## Inhalt

| Verzeichnis | Repo | Dateien | Basis-Commit |
|---|---|---|---|
| `system_core/` | `system/core` | 4 | `ec299bf6` |
| `system_apex/` | `system/apex` | 1 | `62e364d8` |
| `system_netd/` | `system/netd` | 1 | `dbc81b7c` |
| `system_sepolicy/` | `system/sepolicy` | 1 | `83bf38d5` |
| `hardware_samsung/` | `hardware/samsung` | 14 | `567d455b` |
| `external_crosvm/` | `external/crosvm` | 4 | `f19362bb` |
| `device_tree_DEV/` | Device-Tree in `~/DEV/lineagos` | 7 | Branch `fix/l21_4_ha` |

Je Verzeichnis:

- `tracked.patch` — `git diff HEAD`, anwendbar mit `git apply`
- `untracked/` — unversionierte Dateien im Original
- `BASIS-COMMIT.txt` — der Commit, gegen den der Patch gilt
- `STATUS.txt` — `git status --porcelain` zum Zeitpunkt der Sicherung

`VOLLSTAENDIGER-SUCHLAUF.txt` listet alle Repos des Build-Baums mit Änderungen —
zur Kontrolle, ob dieses Patch-Set vollständig ist.

## Wiederherstellen

```sh
cd /media/RAID/lineageos-build/src/system/core
git apply patches/2026-09-02/system_core/tracked.patch
```

Vorher prüfen, ob der Basis-Commit noch stimmt — nach einem `repo sync` kann der
Patch gegen einen neueren Stand nicht mehr sauber greifen.

## Warum diese Änderungen wichtig sind

Der Kern ist der cgroup-v2-Patch in `system/core/libprocessgroup/processgroup.cpp`.

Das Gerät läuft auf **Kernel 3.4** (Exynos 4412). Android 14 setzt cgroup v2 voraus,
die es erst ab Kernel 4.5 gibt. `libprocessgroup` versucht die Prozessgruppen
trotzdem unbedingt anzulegen und scheitert:

```
libprocessgroup: failed to open /dev/blkio//cgroup.procs: No such file or directory
libprocessgroup: Failed to open /sys/fs/cgroup/uid_1000/pid_5887/cgroup.procs
```

Daraufhin startet kein Dienst korrekt. Im Boot-Log des installierten April-Builds
stürzen `zygote`, `surfaceflinger`, `gpu` und `vendor.gnss_service` jeweils viermal
ab, dazu `installd` und `netd`. Bei vier Abstürzen greift Androids Notbremse
`sys.init.updatable_crashing=1`, startet `flags_health_check UPDATABLE_CRASHING`
— das erzeugt über 53.000 Audit-Meldungen und überschreibt den Ringpuffer — und
rollt zurück. Nach etwa neun Minuten landet das Gerät in TWRP.

Der Patch prüft, ob cgroup v2 überhaupt verfügbar ist, und überspringt den Schritt
sauber, wenn nicht.

**Die in den alten Notizen als GPU-Problem geführte surfaceflinger-Schleife ist
Folge dieser Kette, nicht ihre Ursache.**

## Stand der Dinge

- **Build 26** (`lineage-21.0-20260809-UNOFFICIAL-n8010.zip`, 628 MB) enthält alle
  diese Fixes und ist erfolgreich gebaut — aber **nie geflasht**.
- Auf dem Tablet liegt `21.0-20260404`, gebaut am 3. April, also **vor** den Fixes.
- Die sechs unterschiedlich datierten Zip-Namen im Ausgabeverzeichnis sind
  Hardlinks auf dieselbe Datei: Stand 9. August.

## Bekannte Stolperfallen

- Device-Tree in `~/DEV/lineagos` und Build-Baum sind auseinandergelaufen:
  `init.target.rc`, `system.prop` und `vendor_prop.mk` existieren nur im Build-Baum.
  Ein Build aus dem Git-Repo ergäbe heute ein anderes ROM als das vorliegende Zip.
- Der `repo sync` ist vom Dezember 2025, also rund neun Monate alt.
- `external/crosvm` enthält vier **gelöschte** `Cargo.lock` — vermutlich unbeabsichtigt,
  der Patch hält den Zustand trotzdem fest.
