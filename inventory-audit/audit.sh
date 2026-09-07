#!/bin/bash
# Аудит Samsung Galaxy Tab S6 Lite (One UI) через ADB. ТОЛЬКО ЧТЕНИЕ — на планшете
# ничего не меняется. Складывает всё в inventory-<дата>/ рядом со скриптом и печатает
# короткую сводку. Аналог inventory-backup/make-inventory.sh из megarohas_android_tv_tweaks,
# расширенный под планшет: батарея, память по процессам, диск по приложениям, джобы/алармы.
set -u

if [ -n "${ADB_SERIAL:-}" ]; then ADB() { adb -s "$ADB_SERIAL" "$@"; }; else ADB() { adb "$@"; }; fi
command -v adb >/dev/null 2>&1 || { echo "adb не найден. macOS: brew install --cask android-platform-tools"; exit 1; }
CNT=$(adb devices | awk '$2=="device"{c++} END{print c+0}')
if [ -z "${ADB_SERIAL:-}" ] && [ "$CNT" -ne 1 ]; then
  echo "Нужно ровно одно adb-устройство в состоянии device (сейчас: $CNT), либо export ADB_SERIAL=..."; exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"; OUT="$ROOT/backups/inventory-$(date +%Y%m%d-%H%M)"
mkdir -p "$OUT"
S() { ADB shell "$@" 2>/dev/null | tr -d '\r'; }
dump() { # dump <файл> <команда...>
  local f="$1"; shift
  printf '  %-34s' "$f"
  S "$@" > "$OUT/$f"
  echo "$(wc -l < "$OUT/$f" | tr -d ' ') строк"
}

echo "Снимаю инвентарь в $OUT ..."
echo "== Система =="
dump getprop-full.txt            getprop
dump uptime.txt                  uptime
dump cpuinfo.txt                 cat /proc/cpuinfo
dump cpufreq.txt                 'for c in /sys/devices/system/cpu/cpu[0-9]*; do echo "$c gov=$(cat $c/cpufreq/scaling_governor 2>/dev/null) max=$(cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null) cur=$(cat $c/cpufreq/scaling_cur_freq 2>/dev/null)"; done'
dump features.txt                pm list features
dump users.txt                   pm list users
dump wm.txt                      'wm size; wm density'
dump display.txt                 dumpsys display
dump thermal.txt                 dumpsys thermalservice

echo "== Пакеты =="
dump packages-all-paths.txt      pm list packages -f
dump packages-enabled.txt        pm list packages
dump packages-system.txt         pm list packages -s
dump packages-third-party.txt    pm list packages -3
dump packages-disabled.txt       pm list packages -d
dump packages-incl-uninstalled.txt pm list packages -u
dump packages-with-uid.txt       pm list packages -U
dump packages-with-versions.txt  'pm list packages --show-versioncode'
dump dumpsys-package.txt         dumpsys package
dump appops.txt                  dumpsys appops
dump deviceidle.txt              dumpsys deviceidle

echo "== Настройки =="
dump settings-global.txt         settings list global
dump settings-system.txt         settings list system
dump settings-secure.txt         settings list secure
dump accessibility.txt           dumpsys accessibility
dump notification-listeners.txt  'settings get secure enabled_notification_listeners'

echo "== Память и процессы =="
dump meminfo-proc.txt            cat /proc/meminfo
dump dumpsys-meminfo.txt         dumpsys meminfo
dump ps.txt                      'ps -A -o USER,PID,PPID,RSS,VSZ,NAME'
dump ps-by-rss.txt               'ps -A -o RSS,USER,PID,NAME | sort -rn | head -60'
dump activity-processes.txt      dumpsys activity processes
dump activity-services.txt       dumpsys activity services
dump activity-broadcasts.txt     dumpsys activity broadcasts
dump jobscheduler.txt            dumpsys jobscheduler
dump alarm.txt                   dumpsys alarm

echo "== Диск =="
dump df.txt                      df -h
dump diskstats.txt               dumpsys diskstats
dump sdcard-top.txt              'du -d1 /sdcard 2>/dev/null | sort -rn'
dump sdcard-android-data.txt     'du -d1 /sdcard/Android/data 2>/dev/null | sort -rn | head -60'
dump sdcard-android-media.txt    'du -d1 /sdcard/Android/media 2>/dev/null | sort -rn | head -30'
dump sdcard-android-obb.txt      'du -d1 /sdcard/Android/obb 2>/dev/null | sort -rn | head -30'
dump sdcard-download.txt         'ls -la /sdcard/Download 2>/dev/null'
dump storage-volumes.txt         'sm list-volumes all'

echo "== Батарея и питание =="
dump battery.txt                 dumpsys battery
dump battery-sysfs.txt           'for f in /sys/class/power_supply/battery/*; do [ -f "$f" ] && echo "$(basename $f)=$(cat $f 2>/dev/null | head -1)"; done'
dump batterystats.txt            dumpsys batterystats
dump power.txt                   dumpsys power
dump usagestats-checkin.txt      'dumpsys usagestats --checkin'

echo "== Сеть =="
dump wifi-summary.txt            'dumpsys wifi | head -80'
dump connectivity.txt            'dumpsys connectivity | head -120'
dump netstats-summary.txt        'dumpsys netstats | head -120'

# ---------- Сводка ----------
G() { grep -F "[$1]" "$OUT/getprop-full.txt" | sed 's/.*: \[\(.*\)\]/\1/' | head -1; }
SG() { grep -E "^$1=" "$OUT/settings-global.txt" | cut -d= -f2-; }
SS() { grep -E "^$1=" "$OUT/settings-system.txt" | cut -d= -f2-; }
SE() { grep -E "^$1=" "$OUT/settings-secure.txt" | cut -d= -f2-; }
{
  echo "# Сводка $(date '+%Y-%m-%d %H:%M')"
  echo "Модель:            $(G ro.product.model) ($(G ro.product.device), $(G ro.product.name))"
  echo "Android:           $(G ro.build.version.release) / One UI $(G ro.build.version.oneui) / SDK $(G ro.build.version.sdk)"
  echo "Билд:              $(G ro.build.display.id)"
  echo "Патч безопасности: $(G ro.build.version.security_patch)"
  echo "CSC/регион:        sales=$(G ro.csc.sales_code) country=$(G ro.csc.country_code) omc=$(G persist.sys.omc_path)"
  echo "SoC:               $(G ro.hardware) $(G ro.board.platform), ABI $(G ro.product.cpu.abilist)"
  echo "Knox/warranty:     warranty_bit=$(G ro.boot.warranty_bit) knox=$(G ro.config.knox)"
  echo "Uptime:            $(cat "$OUT/uptime.txt")"
  echo ""
  echo "Пакеты: всего $(wc -l < "$OUT/packages-enabled.txt" | tr -d ' ') включённых, системных $(wc -l < "$OUT/packages-system.txt" | tr -d ' '), сторонних $(wc -l < "$OUT/packages-third-party.txt" | tr -d ' '), отключённых $(wc -l < "$OUT/packages-disabled.txt" | tr -d ' ')"
  echo ""
  echo "RAM:  $(grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' "$OUT/meminfo-proc.txt" | tr -s ' ' | tr '\n' ';')"
  echo "Диск: $(grep -E '/data$' "$OUT/df.txt" | tr -s ' ')"
  echo ""
  echo "Батарея: $(grep -E 'level|health|status|temperature|Charge counter' "$OUT/battery.txt" | tr -s ' ' | tr '\n' ';')"
  echo "sysfs:   $(grep -E '^(cycle|batt_cycle|charge_full|batt_full|health|capacity|temp)' "$OUT/battery-sysfs.txt" | tr '\n' ' ')"
  echo ""
  echo "Анимации: window=$(SG window_animation_scale) transition=$(SG transition_animation_scale) animator=$(SG animator_duration_scale)"
  echo "Экран:    $(cat "$OUT/wm.txt" | tr '\n' ' ') | refresh peak=$(SS peak_refresh_rate) min=$(SS min_refresh_rate) | timeout=$(SS screen_off_timeout)ms | auto-brightness=$(SS screen_brightness_mode)"
  echo "Питание:  protect_battery=$(SG protect_battery) adaptive_fast_charging=$(SG adaptive_fast_charging) adaptive_battery=$(SG adaptive_battery_management_enabled) app_standby=$(SG app_standby_enabled) low_power=$(SG low_power)"
  echo "Скан:     wifi_scan_always=$(SG wifi_scan_always_enabled) ble_scan_always=$(SG ble_scan_always_enabled) location_mode=$(SE location_mode)"
  echo "Dev:      development_settings=$(SG development_settings_enabled) adb=$(SG adb_enabled) stay_awake=$(SG stay_on_while_plugged_in)"
  echo "Ввод:     default_ime=$(SE default_input_method)"
  echo "Accessibility: $(SE enabled_accessibility_services)"
  echo "Notif listeners: $(SE enabled_notification_listeners)"
} | tee "$OUT/SUMMARY.txt"
echo ""
echo "Готово: $OUT"
