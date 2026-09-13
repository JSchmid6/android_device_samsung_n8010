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
| `packages_modules_adb/` | `packages/modules/adb` | 1 Patch (+Original) | `git diff` gegen LineageOS lineage-21.0, Build 32 |
| `bionic/` | `bionic` | 1 Patch (+Original) | gegen `c9fb1e864`, Build 32 |

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
  *(Stand 12. September: inzwischen Build 30 geflasht, siehe Nachtrag unten.)*
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

## Nachtrag 12. September: Builds 27–31, der Absturz sitzt hinter dem Mali-ioctl

Build 27 (EGL-Shim aktiv) wurde geflasht. Ergebnis: surfaceflinger stirbt nicht
mehr mit Signal 6 ("couldn't find an OpenGL ES implementation"), sondern mit
**Signal 11**. Der Treiber wird geladen und stuerzt darin ab. Seitdem geht es
nur noch darum, den Backtrace zu bekommen — das hat drei Builds gekostet.

### Was die Kernel-Logs hergaben

`/proc/last_kmsg` (Samsung sec_log, 1 MB) enthaelt immer nur die **letzten
~16 Sekunden** vor dem Reset, weil das Tablet stundenlang in der Dienst-
Neustartschleife haengt. Darin, pro 5-Sekunden-Zyklus:

    init: starting service 'surfaceflinger'...
    Mali: mem_usage before <pid> : 1048576        <- erster ioctl nach open(/dev/mali)
    init: starting service 'tombstoned'...
    init: Untracked pid <pid+25> received signal 11 <- das ist crash_dump32
    init: Service 'surfaceflinger' (pid <pid>) received signal 11
    init: Service 'tombstoned' (pid ...) exited with status 1

Erkenntnisse:

1. surfaceflinger kommt bis in den Mali-Kerneltreiber (`mali_ukk_core.c`,
   `get_api_version_wrapper`) und stirbt rund 200 ms danach.
2. **crash_dump32 stuerzt beim Dump selbst ab.** Fuer surfaceflinger und
   gpuservice gibt es deshalb keinen Tombstone; `/data/tombstones` ist leer.
   Fuer den einfaedigen mediaextractor funktioniert es (SIGABRT, DEBUG-Block
   im Log). Vermutung: Kernel 3.4 und ptrace ueber mehrere Threads.
3. mediaextractor stirbt an
   `Could not read base policy file '/apex/com.android.media/etc/seccomp_policy/mediaextractor.policy'`
   — Folgeproblem, nicht Ursache.
4. `audit=0` auf der Kernel-Kommandozeile (Build 28–30) war **wirkungslos**,
   und zwar aus zwei Gruenden:
   - **S-Boot (N8010XXBLK9) reicht den Cmdline aus dem boot.img-Header nicht
     durch.** Beweis: der TWRP-Header enthaelt `buildvariant=eng`, in
     `/proc/cmdline` unter TWRP fehlt es. Der Kernel sieht nur die ATAG-Zeile
     des Bootloaders plus `CONFIG_CMDLINE` (`CONFIG_CMDLINE_EXTEND=y`) — dort
     steht auch das wirklich wirksame `androidboot.selinux=permissive`.
     `BOARD_KERNEL_CMDLINE` ist auf diesem Geraet tot.
   - Die avc-Zeilen tragen das Praefix `<38>` = LOG_AUTH|LOG_INFO: das ist
     `logd/LogAudit.cpp`, das sie selbst nach /dev/kmsg schreibt.
     flags_health_check (`UPDATABLE_CRASHING`, alle 500 ms) erzeugt ~100
     Stueck pro Sekunde. Richtiger Schalter: `ro.logd.auditd.dmesg=false`.
   Die ATAG-Zeile enthaelt uebrigens `sec_log=0x200000@0x46000000` — die
   Bootloader-Reservierung fuer den Kernel-Log ist 2 MB, genau die Groesse, bei
   der Build 29 keinen Log mehr lieferte (Puffer + sec_log-Header passen dann
   nicht mehr hinein).
5. `CONFIG_LOG_BUF_SHIFT`: 22 verwirft kconfig still (Maximum 21 → Rueckfall
   auf 17 = 128 KB, Build 28); 21 lieferte gar keinen Log mehr (Build 29,
   nur S-Boot-Ausgabe); 20 ist der einzige Wert, der nachweislich geht.
6. Nach 9 Tagen im Loop zeigt der sec_log-Bereich Bit-Kipper (`<18>` statt
   `<38>`). Log innerhalb weniger Minuten nach dem Boot ziehen.
7. adbd startet nie, obwohl `persist.sys.usb.config=adb`, `ro.adb.secure=0`
   und der FunctionFS-Mount in `init.smdk4x12.rc` vorhanden sind. Das Geraet
   erscheint am Host nicht (`lsusb`). Ursache unbekannt — der Boot-Anfang steht
   in keinem Log.

### Build 31: reiner Debug-Build

Keine Aenderung an der Grafikkette, nur Instrumentierung
(`device/samsung/n8010`, siehe `run-build31.sh`):

- `lineageos_n8010_defconfig` (Kernel-Fork, `5377329c09e`): `user_debug=31`
  in `CONFIG_CMDLINE`. Mit `CONFIG_DEBUG_USER=y` schreibt der Kernel bei jedem
  User-SIGSEGV/SIGBUS/SIGILL pc, lr, sp, r0–r12 und die Fault-Adresse nach
  dmesg — unabhaengig von crash_dump. `BoardConfig.mk`: `audit=0` entfernt,
  Hinweis auf den toten `BOARD_KERNEL_CMDLINE` hinterlassen.
- `vendor_prop.mk`: `ro.logd.auditd.dmesg=false`,
  `persist.logd.logpersistd=logcatd`, `persist.logd.logpersistd.size=32`
  (logcatd sichert alle Puffer inkl. kernel nach `/data/misc/logd/logcat*`).
- `rootdir/init.target.rc` + `rootdir/sf_maps_snapshot.sh` (→ /vendor/bin):
  `on property:init.svc.surfaceflinger=running` startet ein Skript, das
  `/proc/<pid>/maps` alle 100 ms nach `/data/local/tmp/sf_maps.txt` kopiert,
  bis der Prozess weg ist. Ohne maps laesst sich der pc keiner Bibliothek
  zuordnen.

Nach dem Flash: booten, zurueck nach TWRP, dann `/proc/last_kmsg`,
`/data/misc/logd/logcat*` und `/data/local/tmp/sf_maps.*` ziehen.

### Dazu eine funktionale Aenderung: komprimierte APEXe wurden nie aktiviert

Beim Nachforschen, warum adbd nie startet, fiel auf: adbd gibt es im ROM nur
in `/system/apex/com.android.adbd.capex` — einem **komprimierten** APEX.
Ebenso `com.android.art.capex` (ohne ART kein zygote → "exited with status 1")
und `com.android.media.capex` (dort liegt die seccomp-Policy, die
mediaextractor nicht findet). Bionic dagegen kommt laut Backtrace aus
`/apex/com.android.runtime/` — einem *unkomprimierten* APEX.

Auf dem Geraet (TWRP, /data gemountet):

- `/data/apex/decompressed/` enthaelt alle dekomprimierten APEXe (Dekompression
  funktioniert).
- `/data/misc/apexdata/` enthaelt **genau die unkomprimierten** APEXe (runtime,
  i18n, tzdata, statsd, vndk, …) und **keinen** dekomprimierten. init legt diese
  Verzeichnisse nur fuer aktivierte APEXe an.

`system/apex/apexd/apexd.cpp` (`MountPackageImpl`, Zeile 546): vorinstallierte
APEXe aus /system werden **ohne dm-verity** gemountet (nur Loop-Device),
dekomprimierte aus /data **mit dm-verity**. dm-verity auf Kernel 3.4 ist genau
die Baustelle, an der der `argc >= 10`-Patch vom 2. September ansetzte — und
offenbar nicht der einzige Stolperstein.

Aenderung: `PRODUCT_COMPRESSED_APEX := false` in `lineage_n8010.mk` (muss dort
stehen, nicht in `n8010.mk`: bei Single-Value-Variablen gewinnt der eigene Wert
ueber alle geerbten, und `aosp_base_telephony.mk` sortiert vor `device/…`).
Kostet ~115 MB im System-Image (1,26 GB von 1,47 GB Limit; die Partition
selbst ist 3 GB). `OVERRIDE_TARGET_FLATTEN_APEX := true` in
`BoardCommonConfig.mk` ist in Android 14 wirkungslos (flattened APEX gibt es
nicht mehr), bleibt vorerst stehen.

Wenn das greift: zygote, adbd und mediaextractor sollten laufen — und mit adbd
im Crash-Loop ist die surfaceflinger-Fehlersuche endlich interaktiv moeglich.
`/data/apex/decompressed/` kann danach geleert werden (apexd ignoriert
dekomprimierte APEXe ohne komprimiertes Gegenstueck).

## Nachtrag 12. September (abends): Boot 31 — drei Ursachen, ein Fork-Netz

Build 31 wurde geflasht und bootete wie erwartet in die Neustartschleife. Nach
~10 Minuten zurueck nach TWRP, Logs gezogen (`~/n8010-logs/b31/collect_b31.sh`).
Der persistente logcatd hat funktioniert: `/data/misc/logd/logcat` mit 989 MB,
6,3 Mio Zeilen, alle Puffer inkl. kernel (`grep -a` noetig). `/proc/last_kmsg`
enthielt nur S-Boot-Text — der Reset ueber Power+Lauter ist ein Kaltstart.

### APEX-Fix wirkt

`/data/misc/apexdata/` hat jetzt alle 32 APEXe (adbd, art, media, …). Die
Dekompressions-Reste in `/data/apex/decompressed/` (20 Dateien) sind harmlos
und koennen irgendwann geloescht werden.

### surfaceflinger: Register, aber keine Bibliothek

`user_debug=31` liefert bei jedem SIGSEGV die Register nach dmesg. 1055
Abstuerze, immer gleich:

    unhandled page fault (11) at 0x66203a6b, code 0x005
    r0=0x66203a6b r1=0x45 r3=0x8 r7=0x78, pc ...922 (Thumb), lr ...489

`0x66203a6b` ist little-endian der ASCII-Text `"k: f"` — ein Zeiger (r0)
wurde mit String-Daten ueberschrieben, r1 = `'E'`. Klassischer Heap-/
Puffer-Ueberlauf. pc und lr liegen ~0x1BB67 auseinander, also in derselben
Bibliothek; ASLR verschiebt die Basis, die Seiten-Offsets bleiben. Ohne
`/proc/<pid>/maps` bleibt die Bibliothek unbekannt: `sf_maps_snapshot.sh` hat
nie eine maps-Datei geschrieben (init meldet 65x fehlende Domain-Transition
fuer `/vendor/bin/sf_maps_snapshot.sh`, `sf_maps.tmp` bleibt 0 Byte).
crash_dump32 stirbt selbst mit Fault-Adresse 0x10 (NULL+0x10). Wird
zurueckgestellt — mit adb ist das ein Einzeiler.

### Ursache 1: adbd — Android 14 kann nur noch AIO, Kernel 3.4 kann kein AIO auf FunctionFS

Das Geraet erscheint sehr wohl am Host (04e8:6860, Interface-Klasse ff,
iSerial RF2D10DVL0J), aber `adb devices` pendelt zwischen `offline` und weg.
Im Log alle paar Sekunden:

    UsbFfs: connection terminated: failed to submit read: Invalid argument

adbd (`packages/modules/adb/daemon/usb.cpp`) benutzt seit 2020 (Commit
6b55e755) ausschliesslich `io_submit` auf den ep-Dateien von FunctionFS.
`drivers/usb/gadget/f_fs.c:966` im 3.4-Kernel hat in `ffs_epfile_operations`
kein `aio_read/aio_write` → `fs/aio.c aio_setup_iocb` gibt -EINVAL. adbd
schliesst die Verbindung, bevor die CNXN-Antwort rausgeht. Die Properties im
Device-Tree (`ro.adb.nonblocking_ffs=false`, `sys.usb.ffs.aio_compat=1`,
`persist.adb.nonblocking_ffs=0`) sind fuer den alten Sync-Backend gedacht,
den es nicht mehr gibt.

Fix (Build 32): html6405s Commit `ba39fe821` "adb: Bring back support for
legacy FunctionFS" (Arne Coucheron, LOS 20) auf Android 14 portiert:
`daemon/usb_legacy.cpp` (Sync-Backend mit read/write), `transport_legacy.cpp`
(altes USB-Transport, komplett in `#if LEGACY_FFS`), Fallback in `usb.cpp`
bei EINVAL, `-DLEGACY_FFS=1` in `adbd_defaults`. Zwei Handanpassungen:
`transport.cpp/.h` (`#if ADB_HOST || LEGACY_FFS` um die USB-Transport-Teile)
und `is_adb_interface` von `int` auf `bool` (Prototyp in `client/usb.h`).
Patch liegt in `patches/2026-09-02/packages_modules_adb/`.

### Ursache 2: rename() ist systemweit kaputt — zygote kann deshalb nicht starten

    derive_classpath: Failed to write /data/system/environ/classpath: Function not implemented
    zygote: BOOTCLASSPATH and DEX2OATBOOTCLASSPATH must not be empty

Android 14s bionic setzt `rename()` und `renameat()` ueber den Syscall
`renameat2` um (Linux >= 3.15). In `arch/arm/kernel/calls.S` unseres 3.4-Kernels
sind die Slots 380–382 `sys_ni_syscall` (nur kcmp, finit_module, seccomp,
getrandom, memfd_create wurden zurueckportiert) → ENOSYS. derive_classpath
schreibt erst `.tmp`, dann `rename()` — das scheitert, `load_exports` liefert
nichts, zygote bricht ab. Gleiche Ursache: logcatd rotiert nie (eine
989-MB-Datei), odrefresh meldet "BOOTCLASSPATH is not defined".

Fix (Build 32): html6405/android_bionic `777991efe` Revert "Rewrite
renameat()." von Hand uebernommen — `renameat` zurueck in `SYSCALLS.TXT`,
`rename()` ruft `renameat()`. Einziger direkter `renameat2()`-Aufrufer im
Baum ist `netbpfload/loader.cpp`, der auf diesem Kernel ohnehin nichts tun
kann. Patch in `patches/2026-09-02/bionic/`.

### Ursache 3: netd stirbt alle 5 s — kein eBPF im Kernel

    libnetd_updatable_init: Failed: (38) [Function not implemented] :
      Failed to get program from /sys/fs/bpf/netd_shared/prog_netd_skfilter_allowlist_xtbpf

`libnetd_updatable.so` (com.android.tethering-APEX) verlangt BPF-Programme,
Kernel 3.4 hat kein eBPF. Genauso `GpuMem: Failed to retrieve pinned program`.
Noch nicht gefixt — siehe Fork-Netz.

### Das eigentliche Problem: html6405s Port haengt an ~20 stillen Forks

Unser Manifest (`.repo/local_manifests/roomservice.xml`) holt von html6405
nur n8010, n80xx-common, smdk4412-common, den Kernel, SamsungServiceMode und
hardware/samsung — alles andere ist Stock-LineageOS 21. html6405 hat aber
`lineage-21.0`-Branches fuer bionic, system_core, system_vold, system_libhidl,
frameworks_native (`lineage-21.0-r08`), frameworks_av, frameworks_base,
hardware_interfaces, hardware_lineage_interfaces, build, build_soong,
vendor_lineage, packages_modules_Connectivity_UL, frameworks_ex,
frameworks_opt_net_wifi, frameworks_opt_telephony, packages_services_Telephony,
packages_apps_SetupWizard, system_nfc — ohne Manifest-Repo, ohne Bauanleitung.
Die Forks sind klein (bionic 10, system_core 8, frameworks_native 16 eigene
Commits), aber genau die Stellen, an denen Android 14 mit Kernel 3.4 und
2012er-Blobs bricht:

- bionic: renameat-Revert, jemalloc statt Scudo, pre-P-Mutex-Verhalten,
  `TARGET_PROCESS_SDK_VERSION_OVERRIDE` im Linker (der Device-Tree setzt das
  in `BoardCommonConfig.mk` fuer rild/GPS/libsec-ril — Stock-Build ignoriert
  die Variable), `LD_SHIM_LIBS`.
- system_core: Revert "libprocessgroup: switch freezer to cgroup v2", "Fix
  support for devices without cgroupv2", Revert "remove inprocess tethering".
- frameworks_native: **Revert "Delete GLESRenderEngine"** samt vier
  Folge-Reverts (Android 14 rendert nur noch ueber Skia — Mali-400 kann GLES
  2.0), "Disable gpuservice on old BPF-less kernel", "SurfaceFlinger: Don't
  cleanup resources from previous frame", "Disable SF HWC backpressure",
  "libbinder: make threadpool shrinking non-fatal". Das ist der heisseste
  Kandidat fuer den surfaceflinger-SIGSEGV.
- frameworks_av: 44 Commits, im Kern Camera-HAL1-Wiederherstellung und
  Audio-HAL-2.0.
- Kernel: unser Manifest zeigt auf `lineage-21.0` (letzter Commit 29.06.2024).
  Der Branch **`lineage-21.0-BPF`** ist die Fortsetzung (bis 19.01.2025, 991
  Commits ueber der gemeinsamen Basis, enthaelt die 416 von lineage-21.0 fast
  komplett) mit eBPF-Backport, **renameat2-Backport** (Miklos Szeredi,
  "ARM: add renameat2 syscall"), cgroup-Kompatibilitaet, und den aktuellen
  Defconfigs (`lineageos_n8000_defconfig`, 385 Zeilen Unterschied). Die
  n80xx-Device-Trees (Commits bis 04/2025) sind gegen diesen Branch entwickelt
  (Kernel-Commit "sec_keyboard.c: … wakelock bug workaround made in
  n80xx-common"). Wir haben bis Build 32 den falschen Kernel-Branch gebaut.

Plan fuer Build 33: Kernel auf `lineage-21.0-BPF` (n8010-Defconfig neu aus
`lineageos_n8000_defconfig` ableiten, dm-verity-argc-Patch und `user_debug=31`
nachziehen), dazu die Fork-Commits von bionic, system_core, frameworks_native,
libhidl, vold als Cherry-Picks auf unsere neueren Upstream-Staende; frameworks_av/
base nach Sichtung. Stock-Upstream bleibt Basis, damit die Sicherheits-Merges
von 2024/25 erhalten bleiben.

## Nachtrag 12. September (spaet): Build 33 vorbereitet, waehrend Build 32 lief

Details und die kompletten Patch-Serien: `../2026-09-12-b33/README.md`.

### Kernel-Branch-Entscheidung ist belastbar

GitHub-API: das Kernel-Repo hat `lineage-21.0`, `lineage-21.0-3.0` und
`lineage-21.0-BPF` (Default-Branch `lineage-20.0-3.4`). Die Device-Trees
n8010 (Push 19.01.2025) und n80xx-common (Commits bis 04/2025) passen zur
Spitze von `lineage-21.0-BPF` (f29c7c3c576, 19.01.2025, "sec_keyboard.c: …
wakelock bug workaround made in n80xx-common"). Auf dem BPF-Branch ist nur
`lineageos_n8000_defconfig` gepflegt (11.01.2025) — `lineageos_n8013_defconfig`
ist von 2022 und ohne BPF, obwohl `n80xx-common/BoardConfigCommon.mk` es als
Default nennt; html6405s n8010-Tree ueberschreibt das seit 2023 mit
`lineageos_n8000_defconfig` (Commit e1256d1). Unsere `lineageos_n8010_defconfig`
ist jetzt genau das plus `user_debug=31` und `LOG_BUF_SHIFT=20`.

Was der Branch mitbringt (991 Commits ueber der gemeinsamen Basis): ARM-eBPF-
JIT, bpf-Syscall, `CONFIG_ANDROID_TREBLE_SPOOF_KERNEL_VERSION_PREFIX="4.9.337"`,
renameat2-Backport, Revert "cgroup: Add compat cgroup2 fs", USB-Host-Merges
aus dem KK-Kernel, SCHED_RR/HZ konfigurierbar. `drivers/md/dm-verity.c` hat
weiter `argc != 10` — unser Patch ist nachgezogen.

### Cherry-Pick-Runde (Worktrees unter `~/n8010-wt/`, Branch `n8010-b33`)

| Repo | uebernommen | Konflikte / uebersprungen |
|---|---|---|
| frameworks/native | 16/16 | — |
| system/core | 6/7 | phh `3747b8ce6c` (createProcessGroup `#if 0`): unsere Variante bleibt |
| bionic | 7/9 | `92b1ad452` jemalloc (redundant), `777991efe` renameat (schon drin) |
| system/libhidl | 2/2 | — |
| system/vold | 1/1 | — |
| hardware/interfaces | 4/4 | — |
| packages/modules/Connectivity | 13/14 | `dc76351e44` reboot_on_failure (schon drin) |
| frameworks/base (Auswahl 12) | 10/12 | `00ee326453` colorfade-Overlay (LOS 21 hat `config_displayColorFadeDisabled`), `436e2369a6` LocationResult (spaeter) |
| vendor/lineage | 2 | Soong-Defaults `process_sdk_version_overrides_defaults`, `disable_postrender_cleanup_defaults` — ohne die baut der Linker bzw. surfaceflinger nach den Cherry-Picks nicht |

Beim Durchsehen der Build-Dateien fiel auf, dass zwei Fork-Commits Soong-
Defaults aus html6405s vendor_lineage-Fork referenzieren (bionic: linker,
frameworks_native: surfaceflinger) — deshalb die zwei vendor_lineage-Reverts.
`gralloc_10_usage_bits_defaults` gibt es in Stock-vendor_lineage noch; unser
Gralloc-Hack in frameworks_native bleibt vorerst wie in Build 32.

### bpfloader in Build 33: `start` statt aus

Bisher war `on load_bpf_programs` komplett leer (netbpfload konnte auf dem
alten Kernel nur scheitern und `reboot_on_failure` warf das Geraet in den
Neustart). Mit BPF-Kernel und den Connectivity_UL-Patches darf netbpfload
scheitern, ohne dass netd oder init haengen. Trotzdem `start` statt
html6405s `exec_start`: sollte netbpfload doch haengen (Verifier/JIT auf
ARM32), blockiert das sonst die Trigger-Kette bis `on boot` — und damit
zygote und adbd, das wir gerade erst zum Laufen bringen. Sobald bpfloader
nachweislich durchlaeuft, zurueck auf `exec_start`.

### Fuer den Build-Baum (nach Build 32)

`werkzeug/apply_b33.sh`: pro Repo `git stash` (lokale Aenderungen bleiben als
Stash), `git checkout --detach n8010-b33`. Device-Overlay
`smdk4412-common/overlay/.../config.xml`: `config_colorFade_enabled` →
`config_displayColorFadeDisabled=true`. Dann `run-build33.sh` (erst
`mka bootimage` als Kernel-Compile-Test, dann `mka bacon`).

## Nachtrag 13. September: Build 32 und Build 33 sind gebaut, noch nicht geflasht

Beide Builds sind mit `BUILD_EXIT=0` durch. Zips liegen als echte Kopien
(kein Hardlink — `mka bacon` ueberschreibt das Zip in `out/` in-place, ein
Hardlink waere mit ueberschrieben worden) unter
`/media/RAID/lineageos-build/builds/`:

| Build | Datei | Groesse | sha256 (Anfang) | Bauzeit |
|---|---|---|---|---|
| 32 | `build32-lineage-21.0-20260912-n8010.zip` + `build32-boot.img` | 620.693.325 B | `4506f70b0b6f6534` | 1 h 13 min |
| 33 | `build33-lineage-21.0-20260912-n8010.zip` + `build33-boot.img` | 620.775.856 B | `96fc9c7a989ca76b` | 58 min bootimage + 7 h 39 min bacon (Kernel- und Framework-Neubau) |

Im Build-33-Image geprueft (Staging `out/target/product/n8010/`):

- Kernel `.config`: `BPF_SYSCALL=y`, `BPF_JIT=y`, `CGROUP_BPF=y`,
  `LOG_BUF_SHIFT=20`, Spoof-Prefix `4.9.337`, `CMDLINE` mit `user_debug=31`,
  `DM_VERITY=y` (argc>=10-Patch), `MODULES=y` — nur `scsi_wait_scan.ko`,
  kernel.mk baut und installiert es anstandslos.
- `system/bin/surfaceflinger` enthaelt `GLESRenderEngine` (Fork-Commits
  drin) — erst damit ist `debug.renderengine.backend=gles` mehr als ein
  ignoriertes Property.
- `system/etc/init/netbpfload.rc`: `start bpfloader`, `reboot_on_failure`
  auskommentiert.
- `system/apex/com.android.adbd.apex` (unkomprimiert): Strings
  „usb_init - using legacy FunctionFS“, `sys.usb.ffs.aio_compat`.
- `system/lib/bootstrap/libc.so`: `renameat` exportiert (rename()-Fix).
- bionic-Fork-Commits kompilieren (libc wurde schon fuers bootimage-Ziel
  gebaut, u. a. `pthread_mutex.cpp`).

Flash-Reihenfolge, sobald jemand am Geraet ist: zuerst Build 33 (der
eigentliche Fix-Versuch: GLES-RenderEngine + BPF-Kernel + adbd). Bootet er
nicht bis zu adb, Build 32 als Rueckfall (nur adbd + rename(), sonst wie
Build 31) — damit man wenigstens `adb shell`, `/proc/<sf-pid>/maps` und
`logcat -b crash` bekommt. Beides via TWRP, MTP vorher aus.

Erwartung fuer Build 33: (a) adb ueber USB muss jetzt gehen, (b) netd darf
nicht mehr alle 5 s sterben (BPF im Kernel), (c) surfaceflinger — offen;
wenn er weiter mit Fault-Adresse ASCII „k: f“ stirbt, liegt es nicht am
Skia-Backend, sondern tiefer (Gralloc/Mali-Blobs), dann hilft erst die
maps-Ausgabe.

## Nachtrag 13. September (nachmittags): Boot 33 — der Mali-Blob passt nicht zum Kernel

Build 33 wurde per TWRP mit Factory-Reset installiert. Er bootet bis
zum Bootscreen und bleibt dort (Bootanimation ohne Bild, dann nach ~20 min
zurueck nach TWRP durch den Nutzer). Weil adb weiter nicht antwortete,
kam die Diagnose ueber den persistierten logcat: `persist.logd.logpersistd=
logcatd` (vendor/build.prop) schreibt seit Build 33 nach
`/data/misc/logd/`, und das laesst sich aus TWRP heraus ziehen
(`2026-09-13-b34/werkzeug/twrp_pull.sh`). `/proc/last_kmsg` war nach dem
Kaltstart leer (3,5 KB) — der Ring ueberlebt nur Warmstarts. Auszug:
`2026-09-13-b34/logs/b33-boot1-auszug.txt`.

Was funktioniert (zum ersten Mal komplett zu sehen): Kernel
`lineage-21.0-BPF`, init bis `zygote-start`, apexd, vold, bpfloader,
netd bleibt am Leben, USB-Gadget wird konfiguriert, adbd startet mit
Legacy-FunctionFS („functionfs successfully initialized“, „registering usb
transport“). Alle ~87–89 Neustarts von zygote, netd, audioserver usw.
sind Folge der `onrestart`-Ketten hinter surfaceflinger, nicht eigene
Fehler.

### 1. surfaceflinger: „Device driver API mismatch“

Direkt vor jedem der 89 SIGSEGV steht:

```
E         : ERROR in Mali driver:
E         :  * Device driver API mismatch
E         :  * Device driver API version: 29
E         :  * User space API version: 23
E         : mali: REVISION=Linux-r3p2-01rel3 BUILD_DATE=Fri Mar 21 13:52:50 KST 2014
W libEGL  : eglInitialize(0x1) failed (EGL_BAD_ALLOC)
F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x200
    #00 libc.so (__strchr_chk+6)
    #01 libc.so (strstr+8)
    #02 libEGL.so (android::egl_display_t::initialize(int*, int*)+742)
    #03 surfaceflinger (GLESRenderEngine::create+32)
```

Unser `libMali.so` stammt aus der KitKat-Stock-Firmware N8010XXUDNE4
(Maerz 2014) und spricht Mali-UK-API **23**. Der Mali-Kerneltreiber in
html6405s Kernel (r3p2, Commit `bea61001a38` „Mali r3p2-01rel3 API
version 29 from T311XXUBNH6 update“, seit 2014 in beiden Branches)
verlangt API **29**. `eglInitialize` schlaegt fehl, libEGL loggt das nur
als Warnung, macht weiter und liest in `findExtension()` das nie
beschriebene `disp.queryString.extensions` — das ist die Fault-Adresse
0x200 (in Build 31 stand dort ein anderer Muell, „k: f“). Der
Linker-SDK-Override, die RenderEngine-Wahl und Gralloc waren nie das
Problem; der Absturz war von Anfang an der Blob.

html6405s Vendor-Repo (`android_vendor_samsung_smdk4412-common`, main)
hat die passenden Blobs: `libMali.so` mit `BUILD_DATE=Tue Jul 22 2014`
(T311XXUBNH6, Galaxy Tab 3 8.0), gleiche Groesse 981.272 B, aber
`mov r1, #29` statt `mov r1, #23` vor dem `bfi r1, r1, #16, #16`, mit
dem die Bibliothek ihre Versionsnummer an den Treiber meldet. Dazu die
zwei EGL-Shims `egl/libGLESv1_CM_mali.so` und `egl/libGLESv2_mali.so`.
Ansonsten unterscheiden sich unsere und html6405s `proprietary/` nur bei
WLAN-/Kamera-Firmware (unsere aus der eigenen N8010-Firmware, bleiben).
Pruefsummen: `2026-09-13-b34/vendor_blobs/MD5SUMS.txt`; die alten Dateien
liegen in `/media/RAID/lineageos-build/backup/mali-api23-from-N8010XXUDNE4/`.

### 2. adb „offline“: der Transport wird registriert, aber nie gestartet

adbd laeuft, das Gadget ist enumeriert, der Host sieht das Geraet aber
als `offline`. Nach „registering usb transport“ kommt nichts mehr — keine
Read/Write-Threads. Ursache ist AOSP-Commit `36c8520873d5` („Add
attach/detach support to libusb backend“): `fdevent_register_transport()`
setzt jeden `kTransportUsb`-Transport auf `kCsDetached`, nur der Teil
`usb_devices_start_detached()` steht unter `#if ADB_HOST`. Upstreams
Daemon-Transport (aio) laesst `type` auf `kTransportAny` und merkt davon
nichts; html6405s Legacy-Transport setzt `kTransportUsb` und bleibt
haengen. Patch: die ganze Detached-Abzweigung unter `ADB_HOST`, das
Geraet startet jeden Transport
(`2026-09-13-b34/packages_modules_adb/`).

### 3. tombstoned stirbt beim Start (deshalb nie ein Tombstone)

```
F tombstoned: failed to create temporary tombstone in /data/tombstones: Is a directory
```

`O_TMPFILE` gibt es erst ab Linux 3.11; auf 3.4 wird das Flag als
`O_DIRECTORY` gelesen und `openat(dir, ".", O_WRONLY|...)` liefert
EISDIR. AOSP `aa1d18a59` („Remove support for Linux before 3.11“) hat
den Fallback auf `.temporaryN` entfernt — html6405s aelterer Stand hat
ihn noch. Revert auf `n8010-b33` in system/core
(`2026-09-13-b34/system_core/`). Damit gibt es ab Build 34 echte
Tombstones in `/data/tombstones` (aus TWRP holbar).

### 4. USB-Flackern kommt vom Host

Die Bus-Resets alle 20–45 s stehen nicht im Geraete-Log; das Gadget wird
sauber konfiguriert. `sys.usb.config=adb` meldet sich als `04e8:6860`, und
das ist in libmtp als MTP-Geraet gelistet — gvfs-mtp am Linux-Host probt,
scheitert (kein MTP-Interface) und resettet. Der adb-only-Fall meldet
sich ab Build 34 als Googles `18d1:4ee7`
(`2026-09-13-b34/device_smdk4412-common/`). Zur Not auf dem Host
`gvfs-mtp-volume-monitor` beenden.

### Build 34

Aenderungen gegenueber Build 33: die drei Mali-Blobs (html6405, API 29),
adb-Transport-Patch, system/core-Revert, libEGL-Absicherung (Null-Init
von `queryString`, `initialize()` gibt `EGL_NOT_INITIALIZED` zurueck
statt weiterzulaufen — ein kuenftiges Blob-Problem endet dann mit einer
klaren Meldung statt SIGSEGV), USB-ID. Gestartet 13.09. 16:24 CEST mit
`run-build34.sh` (bootimage, dann bacon). Erwartung: surfaceflinger
initialisiert EGL auf Mali-400, Bootanimation wird sichtbar, adb
antwortet (Host-Key liegt seit dem TWRP-Pull in `/data/misc/adb/adb_keys`,
`ro.adb.secure=1` aus system/build.prop gewinnt gegen vendor). Bleibt
offen: `flags_health_check`-SELinux-Spam (56k Zeilen, permissive, nur
Laerm), `init.boringssl.zygote32.rc` „Too many symbolic links“, das
`sf_maps_snapshot.sh`-Exec aus Build 31 (Label-Fehler, kann raus).
