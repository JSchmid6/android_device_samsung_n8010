# Build 34 — Mali-Blobs auf UK-API 29, adbd-Transport, tombstoned

Stand 13.09.2026 nachmittags, nach dem ersten Boot von Build 33.
Hintergrund und Log-Auswertung: `../2026-09-02/README.md`, Abschnitt
"Nachtrag 13. September (nachmittags): Boot 33 — der Mali-Blob passt nicht
zum Kernel".

## Was hier liegt

| Verzeichnis | Inhalt |
|---|---|
| `vendor_blobs/MD5SUMS.txt` | alte und neue Pruefsummen der drei Mali-Dateien (`libMali.so`, `egl/libGLESv1_CM_mali.so`, `egl/libGLESv2_mali.so`), Quelle, Pruefbefehl fuer die API-Nummer. Die Binaries selbst liegen nicht im Git. |
| `packages_modules_adb/` | 1 Patch auf `transport.cpp` (zusaetzlich zur Legacy-FFS-Serie aus Build 32): Detached-Start nur unter `ADB_HOST`. |
| `system_core/` | `git revert aa1d18a59` als format-patch (tombstoned: Fallback ohne `O_TMPFILE`), `BASIS.txt` = Spitze von `n8010-b33`. |
| `frameworks_native/` | libEGL: `queryString` nullinitialisiert, `initialize()` bricht nach fehlgeschlagenem `eglInitialize` mit `EGL_NOT_INITIALIZED` ab (Refcount wird zurueckgenommen). Auf `n8010-b33` als lokale Aenderung, `BASIS.txt`. |
| `device_smdk4412-common/` | `init.smdk4x12.usb.rc`: `sys.usb.config=adb` meldet sich als `18d1:4ee7`. |
| `werkzeug/` | `run-build34.sh`; `catch_boot.sh` (wartet am Host auf das Verlassen von TWRP, sammelt lsusb/adb-Status/logcat/dmesg); `twrp_pull.sh` (zieht aus TWRP `/proc/last_kmsg`, `/data/misc/logd/*`, Tombstones, Dropbox, installiert den Host-adb-Key nach `/data/misc/adb/adb_keys`). |
| `logs/b33-boot1-auszug.txt` | die entscheidenden Zeilen aus dem persistierten logcat des ersten Boots von Build 33 (Mali-API-Mismatch, Backtrace, tombstoned, adbd, Neustart-Zaehler). Die vollen Logs (44 MB) liegen lokal unter `~/n8010-logs/b33-boot1/`. |

## Anwenden

Build-Baum auf dem Stand von Build 33 (`../2026-09-12-b33/`):

```
cd vendor/samsung/smdk4412-common/proprietary
#   libMali.so, egl/libGLESv1_CM_mali.so, egl/libGLESv2_mali.so aus
#   github.com/html6405/android_vendor_samsung_smdk4412-common (main) holen,
#   md5 gegen vendor_blobs/MD5SUMS.txt pruefen
cd packages/modules/adb           && patch -p1 < .../packages_modules_adb/0001-*.patch
cd system/core                    && git am .../system_core/0001-*.patch
cd frameworks/native              && patch -p1 < .../frameworks_native/0001-*.patch
cd device/samsung/smdk4412-common && patch -p1 < .../device_smdk4412-common/0001-*.patch
./run-build34.sh   # im Container lineageos-pathmatch
```
