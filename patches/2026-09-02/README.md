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
| `device_samsung_n8010/` | `device/samsung/n8010` | 8 | im Build-Baum |
| `device_samsung_smdk4412-common/` | `device/samsung/smdk4412-common` | 4 | |
| `device_samsung_n80xx-common/` | `device/samsung/n80xx-common` | 1 | |
| `kernel_samsung_smdk4412/` | `kernel/samsung/smdk4412` | 6 | dm-verity-Patch, neues Defconfig |
| `frameworks_native/` | `frameworks/native` | 6 | Gralloc 2/3/4/5 |
| `packages_modules_Connectivity/` | `packages/modules/Connectivity` | 2 | |
| `packages_apps_SamsungServiceMode/` | | 1 | |
| `external_chromium-webview_*` | drei Prebuilt-Zweige | je 1 | |
| `device_google_cuttlefish_vmm/` | | 2 | |
| `vendor_samsung_smdk4412-common/` | kein Git-Repo — Dateikopien | | |

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


## Nachtrag 2. September: der EGL-Treiber wurde nie geladen

Beim Nachvollziehen der Grafik-Kette kam heraus, dass das ROM **gar keinen
ladbaren EGL-Treiber enthielt**.

`frameworks/native/opengl/libs/EGL/Loader.cpp` sucht Vendor-GL-Treiber
ausschliesslich unter:

    /vendor/${LIB}/egl/lib{GLES | [EGL|GLESv1_CM|GLESv2]}_${SUFFIX}.so

Mit `ro.hardware.egl=mali` (vendor_prop.mk:23) also `/vendor/lib/egl/libEGL_mali.so`.
Dieses Verzeichnis existierte im Build **nicht**. Die Blobs lagen in
`/system/lib/egl/` — dort schaut Android 14 fuer Vendor-Treiber nicht mehr hin.

Damit erklaert sich der beobachtete Ablauf: surfaceflinger stirbt viermal,
zygote geht mit, `sys.init.updatable_crashing=1` greift, Rueckfall nach TWRP.

### Ursache

`device/samsung/smdk4412-common/common.mk` hatte in PRODUCT_PACKAGES:

    # libMali (missing vendor blobs) \
    # libEGL_mali (missing vendor blobs) \

Stillgelegt, als die Blobs noch fehlten. Im Januar 2026 wurden sie extrahiert —
die Zeilen wurden nie wieder aktiviert. Stattdessen legt die bei der Extraktion
generierte `smdk4412-common-vendor.mk` alle Blobs per PRODUCT_COPY_FILES nach
`$(TARGET_COPY_OUT_SYSTEM)` (29 Eintraege nach SYSTEM, 3 nach VENDOR).

Der LineageOS-Shim `hardware/samsung/exynos4/hal/libEGL_mali/` (shim.S +
eglApi.cpp) wurde folglich in keinem Build kompiliert — obwohl
`TARGET_PROVIDES_LIBEGL_MALI := true` und
`TARGET_NEEDS_NATIVE_WINDOW_FORMAT_FIX := true` gesetzt sind.

### Aenderung

- `common.mk`: `libMali` und `libEGL_mali` in PRODUCT_PACKAGES aktiviert
- `smdk4412-common-vendor.mk`:
  - Kopie von `libEGL_mali.so` entfernt (der Shim belegt diesen Pfad)
  - Kopie von `libMali.so` entfernt (das Prebuilt-Modul installiert nach /vendor/lib)
  - `libGLESv1_CM_mali.so` und `libGLESv2_mali.so` von SYSTEM nach VENDOR

### Offen

`CONFIG_DMA_SHARED_BUFFER is not set` im neuen Defconfig. dma-buf existiert in
Kernel 3.4 (seit 3.3), ist hier aber abgeschaltet. `CONFIG_SYNC`, `CONFIG_SW_SYNC`
und `CONFIG_ION` sind an. Ob der Grafikstapel ohne dma-buf traegt, ist die naechste
offene Frage — unabhaengig von dieser Aenderung.
