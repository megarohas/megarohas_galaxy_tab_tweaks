#!/bin/bash
# Чистка Samsung Galaxy Tab S6 Lite (SM-P610, One UI 5.1) через ADB. Всё обратимо:
#   - системные пакеты только `pm disable-user --user 0` (возврат: pm enable --user 0);
#   - сторонние (/data) пакеты: сначала бэкап всех split-APK в backups/apk-backups-<дата>/, потом
#     `pm uninstall --user 0` (возврат: adb install-multiple из бэкапа);
#   - фон RuStore: appops RUN_ANY_IN_BACKGROUND ignore (= «Ограничено» в настройках батареи).
# Откат всего разом — ./rollback.sh. Лог и APK — в backups/ репозитория.
# ВАЖНО: VPN-приложения сюда не вносить и в фоне не ограничивать.
set -u
: "${ADB_SERIAL:?Нужен export ADB_SERIAL=<ip:port> (планшет виден двумя транспортами)}"
ADB() { adb -s "$ADB_SERIAL" "$@"; }
command -v adb >/dev/null 2>&1 || { echo "adb не найден"; exit 1; }
ADB get-state >/dev/null 2>&1 || { echo "Устройство $ADB_SERIAL не в состоянии device"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; mkdir -p "$ROOT/backups"
TS=$(date +%Y%m%d-%H%M)
BK="$ROOT/backups/apk-backups-$TS"
LOG="$ROOT/backups/debloat-log-$TS.txt"

# ---------- A. Системные: только отключаем ----------
DISABLE=(
  # телеметрия / персонализация / промо
  com.samsung.android.rubin.app              # Customization Service: 33 пробуждения/сутки, keepalive-алармы
  com.sec.android.diagmonagent               # DiagMonAgent (отчёты об ошибках в Samsung)
  com.samsung.android.knox.analytics.uploader
  com.samsung.android.mapsagent              # «Рекомендуемые приложения»
  com.samsung.android.app.omcagent           # «Рекомендуемые приложения» (OMC/CSC-промо)
  com.google.android.gms.location.history    # выгрузка истории местоположений Google
  com.samsung.android.app.spage              # Samsung Free (промо-лента на рабочем столе)
  # Bixby
  com.samsung.android.bixby.agent
  com.samsung.android.bixby.wakeup
  com.samsung.android.bixbyvision.framework
  com.samsung.android.visionintelligence     # Bixby Vision
  com.samsung.android.app.settings.bixby
  # фоновые резиденты
  com.samsung.android.sm.devicesecurity      # Device security (McAfee), 71 МБ + 2 службы
  com.samsung.android.smartsuggestions       # Smart Suggestions, 133 МБ в двух процессах
  com.samsung.android.homemode               # Daily Board (дублирует Flip Clock), 83 МБ
  com.samsung.android.beaconmanager          # «Поиск устройств поблизости»: BLE-скан 100 % времени
  com.samsung.android.easysetup              # его же UI / SmartThings easy setup
  com.samsung.android.service.stplatform     # SmartThings Framework (SmartThings не установлен)
  # телефонное на Wi-Fi-планшете
  com.hiya.star                              # Hiya (антиспам звонков)
  com.samsung.android.smartcallprovider
  com.samsung.android.visualars              # Smart Touch Call
  # ANT+
  com.dsi.ant.server
  com.dsi.ant.sample.acquirechannels
  com.dsi.ant.plugins.antplus
  com.dsi.ant.service.socket
  # AR / заглушки других устройств / мелочь
  com.samsung.android.ardrawing              # AR Doodle
  com.samsung.android.app.watchmanagerstub   # установщик Galaxy Wearable
  com.samsung.android.inputshare             # Multi control (нужен Galaxy Book)
  com.samsung.android.da.daagent             # Dual Messenger
  com.samsung.android.svoiceime              # Samsung voice input (в ходу Gboard)
  com.samsung.android.game.gos               # Game Optimizing Service
  com.samsung.android.game.gametools
  com.samsung.android.kidsinstaller          # установщик Samsung Kids (сам Kids удаляется ниже)
  # ---------- B. По решению пользователя ----------
  com.samsung.android.mdx                    # Link to Windows Service
  com.microsoft.appmanager                   # Link to Windows
  com.samsung.android.app.sharelive          # Quick Share
  com.samsung.android.aware.service          # Quick Share Agent
  com.samsung.android.mdx.kit                # Quick Share Connectivity
  com.samsung.android.mcfds                  # Continuity Service
  com.samsung.android.mcfserver              # Multi Control Framework, 50 МБ резидент
  com.samsung.android.scloud                 # Samsung Cloud, 82 МБ резидент
  com.samsung.android.fmm                    # Find My Mobile, 70 МБ резидент
)

# ---------- Сторонние (/data): бэкап APK -> uninstall ----------
UNINSTALL_3RD=(
  com.samsung.android.visionarapps           # «AR-приложения» (AR Zone уже отключён)
  com.samsung.android.livestickers           # DECO PIC, 116 МБ
  com.samsung.android.icecone                # Keyboard Content Center (стикеры Samsung Keyboard)
  com.samsung.android.privateshare           # Private Share
  flipboard.boxer.app                        # Flipboard Briefing
  com.samsung.memorysaver                    # «Storage booster» (B)
  com.sec.android.app.kidshome               # Samsung Kids (B)
)

# ---------- Ограничить фон (appops ignore = «Ограничено») ----------
RESTRICT_BG=(
  ru.vk.store                                # RuStore (B): без фоновых проверок обновлений и push
)

# ---------- НЕ ТРОГАТЬ: лаунчер com.sec.android.app.launcher, SystemUI, Settings, GMS/GSF/Play,
# WebView/Trichrome, Samsung account (osp), mobileservice, spp.push, scpm, S Pen-стек
# (aircommand*, handwriting, livedrawing, pentastic, smartcapture, notes), Галерея, Мои файлы,
# honeyboard, Finder, Device care (lool), агенты обновлений (wssyncmldm, soagent, updatecenter),
# Knox core (kgclient, knox.* кроме analytics.uploader), Flip Clock, Погода, Plex, Яндекс Музыка,
# ReVanced + microG, Chrome, Gmail, Gboard — и любые VPN. ----------

installed() { ADB shell pm list packages --user 0 2>/dev/null | tr -d '\r' | grep -qx "package:$1"; }

echo "# debloat-tab $TS ($ADB_SERIAL)" | tee "$LOG"
echo "## disable-user" | tee -a "$LOG"
for p in "${DISABLE[@]}"; do
  if ! installed "$p"; then echo "skip (нет)             $p" | tee -a "$LOG"; continue; fi
  R=$(ADB shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')
  echo "disable-user           $p  => $R" | tee -a "$LOG"
done

echo "## uninstall 3rd-party (с бэкапом APK)" | tee -a "$LOG"
for p in "${UNINSTALL_3RD[@]}"; do
  if ! installed "$p"; then echo "skip (нет)             $p" | tee -a "$LOG"; continue; fi
  mkdir -p "$BK/$p"
  N=0
  while read -r apk; do
    [ -n "$apk" ] || continue
    ADB pull "$apk" "$BK/$p/" >/dev/null 2>&1 && N=$((N+1)) || echo "  ! не скачался $apk" | tee -a "$LOG"
  done < <(ADB shell pm path "$p" | tr -d '\r' | sed 's/^package://')
  echo "apk backup ($N файлов) -> $(basename "$BK")/$p" | tee -a "$LOG"
  if [ "$N" -eq 0 ]; then echo "  ! без бэкапа не удаляю $p" | tee -a "$LOG"; continue; fi
  R=$(ADB shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r')
  echo "uninstall --user 0     $p  => $R" | tee -a "$LOG"
done

echo "## appops RUN_ANY_IN_BACKGROUND ignore" | tee -a "$LOG"
for p in "${RESTRICT_BG[@]}"; do
  ADB shell cmd appops set --user 0 "$p" RUN_ANY_IN_BACKGROUND ignore
  ADB shell cmd appops set --user 0 "$p" RUN_IN_BACKGROUND ignore
  echo "restrict-bg            $p  => $(ADB shell cmd appops get --user 0 "$p" RUN_ANY_IN_BACKGROUND | tr -d '\r' | head -1)" | tee -a "$LOG"
done

echo ""
echo "Проверка критичных компонентов:"
for p in com.sec.android.app.launcher com.android.systemui com.android.settings com.google.android.gms \
         com.android.vending com.google.android.webview com.osp.app.signin com.samsung.android.mobileservice \
         com.sec.spp.push com.samsung.android.scpm com.samsung.android.honeyboard com.google.android.inputmethod.latin \
         com.sec.android.app.myfiles com.sec.android.gallery3d com.samsung.android.app.notes \
         com.samsung.android.service.aircommand com.samsung.android.lool com.wssyncmldm \
         com.wssc.simpleclock com.plexapp.android ru.yandex.music app.revanced.android.youtube com.android.chrome; do
  if installed "$p" && ! ADB shell pm list packages -d --user 0 2>/dev/null | tr -d '\r' | grep -qx "package:$p"; then
    echo "  OK      $p"
  else
    echo "  ПРОБЛЕМА $p — проверьте вручную!" | tee -a "$LOG"
  fi
done
echo "Лог: $LOG"
