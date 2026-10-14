# megarohas_galaxy_tab_tweaks

**English** | [Русский](README.ru.md)

Tweaks for the Samsung **Galaxy Tab S6 Lite 2020** tablet (SM-P610 Wi-Fi, One UI 5.1 /
Android 13, 4 GB RAM) over **wireless ADB**, no root. Tailored to this particular
tablet, but the lists and commands are standard for any Samsung on One UI 5.

## Background

The tablet came from a previous owner and now lives on as a desk clock (Flip Clock)
and a Plex and Yandex Music player. A (read-only) audit showed that with 4 GB of RAM
the system sat at "status low" with almost 2 GB in ZRAM swap, ~750 MB of which were
background Samsung residents nobody uses (Daily Board, Samsung Cloud, Smart Suggestions,
Find My Mobile, the McAfee scanner, Quick Share/Continuity). "Nearby device scanning"
was scanning BLE 100% of the time, Customization Service woke the tablet 33 times a
day, and the nightly AOT compilation of apps never ran, because at night the tablet
isn't idle — it's showing the clock. After a conservative cleanup, memory went to
"status normal", with no crashes.

## Contents

| Folder | What's inside |
|---|---|
| [`connect-wireless-adb/`](connect-wireless-adb/) | Pairing and connecting over Wi-Fi. Knows the tablet's two gotchas: mDNS only works in adb's Bonjour mode, and the device shows up via two transports — prints a ready-to-use `export ADB_SERIAL=...` |
| [`inventory-audit/`](inventory-audit/) | A state snapshot (read-only): getprop, packages, settings, per-process memory, disk, battery, jobs/alarms, app usage + parsers |
| [`debloat-tab-s6-lite/`](debloat-tab-s6-lite/) | Conservative cleanup: system apps only via `pm disable-user`, third-party ones with an APK backup; a full rollback sits next to it |
| [`perf-dexopt/`](perf-dexopt/) | Forced AOT compilation of all apps (`speed-profile`), which the system never does on its own on a tablet that's never idle |
| [`storage-leftovers/`](storage-leftovers/) | Shows leftovers of uninstalled apps in shared storage (WhatsApp/Telegram/file managers/APKs in Download); deleting is manual, with a command from the README |

Each folder is self-contained: a README with the what and why + idempotent scripts;
the debloat and the compilation come with their own rollback. All scripts expect
`export ADB_SERIAL=<ip:port>` — `connect.sh` prints it. (The per-folder READMEs
are in Russian.)

To run everything at once, use **`apply-all.sh [ip]`** in the repo root: connect →
inventory → debloat → compilation.

## What the scripts DON'T touch

The launcher (`com.sec.android.app.launcher`), SystemUI, Settings, GMS/GSF/Play Store,
WebView, Samsung account (`osp`), `mobileservice`, `spp.push`, `scpm`, the whole
S Pen stack (`aircommand*`, `handwriting`, `livedrawing`, `pentastic`, `smartcapture`,
Samsung Notes), Gallery, My Files, both keyboards, Finder, Device care (`lool`),
update agents (`wssyncmldm`, `soagent`, `updatecenter`), Knox core, Dolby Atmos,
the Flip Clock app, Weather, Plex, Yandex Music, ReVanced + microG, Chrome, Gmail —
and **no VPN apps**: they are never removed or restricted in the background.

## Lessons learned on this tablet

- **mDNS.** The tablet isn't visible to adb's default openscreen backend; the adb
  server needs `ADB_MDNS_OPENSCREEN=0` (Bonjour). `connect.sh` takes care of this.
- **Two transports.** After `adb connect` the device is listed both as `ip:port` and
  as an mDNS name, and `adb shell` without `-s` refuses to run. Hence the mandatory
  `ADB_SERIAL`.
- **zsh and the `path` variable.** In ad-hoc zsh loops, a variable named `path`
  clobbers `PATH` — and `head`, `sed`, `tr` disappear. Don't name variables that.
- **Find My Mobile is protected.** `pm disable-user com.samsung.android.fmm` replies
  "Failed to change state". First turn off "Find My Mobile" in Settings →
  Biometrics and security, then disable the package.
- **`dumpsys diskstats` lies.** Per-app sizes come from the
  `/data/system/diskstats_cache.json` cache, which only refreshes when the device is
  idle; here it was a year old and still showed long-gone WhatsApp/TikTok. Trust `df`,
  `du` and the inventory instead.
- **A load average of ~19 is not a problem.** The Exynos kernel keeps D-state threads
  (`tz_worker_thread`, `simpleinteractive`) that always count toward load. Look at
  `dumpsys cpuinfo` / `top`, not `uptime`.
- **Dolby Atmos** runs in software and keeps ~0.4 of a core busy in audioserver during
  playback, but without it the tablet's speakers sound noticeably worse. Kept on
  purpose; it has no key in `settings`, GUI only.
- **Nightly dexopt doesn't run** if the tablet never sleeps on the charger
  (clock on screen): only 29 out of 362 packages had been compiled. Fixed by
  [`perf-dexopt/`](perf-dexopt/).

## Backups

Everything the scripts pull from the device (the inventory — which includes serial
numbers and the account name, APKs of removed apps, change logs) goes into `backups/`
in the repo root — the folder is in `.gitignore` and never ends up on GitHub.

---
*The package lists were checked against firmware `P610XXS7FYD1` (One UI 5.1, the last
update for this model). On another device, take an inventory first and review the
lists in `debloat.sh` before running it.*
