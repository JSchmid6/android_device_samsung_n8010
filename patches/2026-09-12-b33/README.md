# Build 33 — html6405-Forks als Cherry-Picks, Kernel lineage-21.0-BPF

Stand 12.09.2026 abends, vorbereitet waehrend Build 32 noch lief.
Hintergrund: siehe `../2026-09-02/README.md`, Abschnitt "Das eigentliche
Problem: html6405s Port haengt an ~20 stillen Forks".

## Was hier liegt

Pro Repo ein Verzeichnis mit `git format-patch`-Serie (Branch `n8010-b33`,
Basis = Stand des Build-Baums = LineageOS-21-Upstream mit Security-Merges
2024/25) und `BASIS.txt` (Basis-Commit, Spitze, Commit-Liste). Die erste
Patch-Nummer ist jeweils "n8010: lokale Aenderungen aus dem Build-Baum
(Stand Build 32)", also unsere bisherigen Hacks als Commit; danach die
Fork-Commits von html6405 in Original-Reihenfolge (`-x`, "cherry picked
from" im Text).

| Repo | Patches | Inhalt |
|---|---|---|
| `kernel_samsung_smdk4412` | 1 | Basis ist **html6405 `lineage-21.0-BPF` @ f29c7c3c576** (nicht mehr `lineage-21.0`). Einziger eigener Commit: `lineageos_n8010_defconfig` = Kopie von `lineageos_n8000_defconfig` (html6405 baut n8010 selbst damit, Commit e1256d1 im Device-Tree) + `user_debug=31` in `CONFIG_CMDLINE` + `CONFIG_LOG_BUF_SHIFT=20`; dm-verity `argc >= 10`. Keine gator-Dateien mehr. |
| `frameworks_native` | 1+16 | alle 16 Fork-Commits, u.a. Revert "Delete GLESRenderEngine" (+4 Folge-Reverts), "Disable gpuservice on old BPF-less kernel", "Don't cleanup resources from previous frame", "renderengine: gles: unconditionally skip PostRenderCleanup", HWC-Backpressure aus, libbinder Threadpool non-fatal. `RenderEngine::create()` hat wieder `case GLES` — erst damit greift unser `debug.renderengine.backend=gles`. |
| `system_core` | 1+6 | Camera feature extensions, reboot fast on legacy, **Revert "libprocessgroup: switch freezer to cgroup v2"** (schedtune `/dev/stune` + freezer `/dev/freezer` als cgroup v1 in `cgroups.json`/`task_profiles.json`), Revert "remove inprocess tethering", init reboot to recovery on fatal errors, healthd charger keys. Uebersprungen: phh `3747b8ce6c` (createProcessGroup-Fehler per `#if 0`) — unsere lokale Variante (ENOENT/EPERM/EROFS tolerieren) bleibt. |
| `bionic` | 1+7 | per-process SDK override im Linker (`process_sdk_version_overrides_defaults` → braucht vendor_lineage-Patch), hosts-Cache (2), pre-P-Mutex, `inaddr.h`, SDK-Override auf dlopen, "Ignore invalid pthread_t". Uebersprungen: `92b1ad452` jemalloc (redundant, `MALLOC_SVELTE` liefert schon jemalloc); `777991efe` renameat (schon von Hand in Build 32, im lokalen Commit). |
| `system_libhidl` | 2 | beide Fork-Commits |
| `system_vold` | 1 | der eine Fork-Commit |
| `hardware_interfaces` | 4 | Revert der wifi-HIDL-Entfernung (wifi 1.x + `wifi_hal_cc_defaults`), dynamische Interfaces, Audio-BT-AIDL-Revert, Audio-Binder-Threadpool-Revert |
| `packages_modules_Connectivity` | 1+13+1 | 13 Connectivity_UL-Commits: no-bpf usecase fuer netbpfload/clatcoordinator/dnsresolver, "Allow failing to load bpf programs", "Support non-working BPF maps on old BPF-less kernel", "BpfHandler.cpp: we must not wait until the BPF programs are loaded", Traffic-Indikatoren fuer Legacy, mdns SocketNetlinkMonitor aus, inprocess-tethering-Reverts. Uebersprungen: `dc76351e44` (reboot_on_failure) — steckt schon im lokalen Commit. Letzter Patch: `on load_bpf_programs` → `start bpfloader` (nicht-blockierend; vorher komplett aus, Upstream/html6405 `exec_start`). |
| `frameworks_base` | 10 | Auswahl (`forks/frameworks_base.select`): CachedAppOptimizer Freezer zurueck auf cgroup v1 (4), "Ignore cgroup creation errors", Revert-Revert process-group-failure non-fatal, GPS-Rollover, ColorFade-EGL-Crash-Fix (exynos4), Ripple/Stretch-Defaults. Uebersprungen: `00ee326453` colorfade-Overlay (LOS 21 hat dafuer schon `config_displayColorFadeDisabled` → Device-Overlay umgestellt), `436e2369a6` LocationResult (nicht boot-relevant, spaeter). Nicht angefasst: Camera-Reverts und der Rest der 60. |
| `vendor_lineage` | 2 | Revert "config: Remove TARGET_PROCESS_SDK_VERSION_OVERRIDE" und Revert "config: Remove TARGET_DISABLE_POSTRENDER_CLEANUP" — liefern die Soong-Defaults, die bionic/linker und surfaceflinger nach den Cherry-Picks referenzieren. |

Nicht in Build 33 (bewusst): frameworks_av (41, Camera-HAL1/Audio), build,
build_soong (unser Stand hat die scudo-freie 32-bit-libc schon),
hardware_lineage_interfaces (legacy wifi HIDL-Service, power 1.0),
hardware_samsung `lineage-21.0-exynos4`, opt/net/wifi, opt/telephony,
Telephony, SetupWizard, system_nfc, frameworks_ex. Erst booten, dann WLAN/Kamera.

## Werkzeug (`werkzeug/`)

- `fetch_forks.sh`, `filter_forks.sh`: Fork-Branches als `refs/html6405/<branch>`
  in die Build-Baum-Repos holen, Commits per Subject gegen unseren Stand
  filtern → `forks/*.unique.txt`, `forks/forks_unique.log`.
- `wt_setup.sh` (+ `wt_setup2.sh`/`wt_setup_base.sh` fuer frameworks/base,
  `wt_kernel.sh`): pro Repo `git worktree add -b n8010-b33 ~/n8010-wt/<repo>`,
  lokale Aenderungen committen, Cherry-Picks in Original-Reihenfolge,
  Konflikte abbrechen und als `forks/<repo>.<hash>.conflict.diff` ablegen.
  Wiederaufnehmbar. Worktrees liegen auf der Home-Platte, weil das RAID
  (ntfs-3g) waehrend eines laufenden ninja fuer git zu langsam ist.
- `apply_b33.sh`: nach Build 32 im Build-Baum pro Repo `git stash` +
  `git checkout --detach n8010-b33`.
- `run-build33.sh`: erst `mka bootimage` (Kernel-Compile-Test), dann `mka bacon`.

## Kernel-Defconfig: was sich mit dem BPF-Branch aendert (n8000-Basis)

`CONFIG_BPF/BPF_SYSCALL/CGROUP_BPF=y`, ARM-eBPF-JIT,
`CONFIG_ANDROID_TREBLE_SPOOF_KERNEL_VERSION_PREFIX="4.9.337"` (uname sagt
4.9 → VINTF/netd/netbpfload nehmen "moderner Kernel" an, die Connectivity_UL-
Patches fangen die Luecken ab), `CONFIG_DEBUG_USER=y`, `CONFIG_DM_VERITY=y`
ohne FEC/ANDROID_VERITY, `CONFIG_MODULES=y` (nur scsi_wait_scan),
`CGROUP_FREEZER/CPUSETS/MEM_RES_CTLR/BLK_CGROUP=y`, `HZ=200`, `IKCONFIG=y`,
kein SEC_DEBUG, kein ANDROID_LOGGER, `SEC_MODEM=y` (n8000 hat 3G; html6405
baut n8010 trotzdem damit). Revert "cgroup: Add compat cgroup2 fs" — der
falsche cgroup2-Mount verschwindet, passend zum system_core-Freezer-Revert.
Achtung: `lineageos_n8013_defconfig` auf dem BPF-Branch ist von 2022 und
ohne BPF — nicht verwenden.
