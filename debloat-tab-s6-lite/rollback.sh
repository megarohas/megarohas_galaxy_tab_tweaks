#!/bin/bash
# Полный откат debloat.sh: включает отключённое, ставит обратно удалённые сторонние
# пакеты из свежайшего apk-backups-*, снимает ограничение фона с RuStore.
# Удалённые папки предыдущего владельца (группа E) не восстанавливаются.
set -u
: "${ADB_SERIAL:?Нужен export ADB_SERIAL=<ip:port>}"
ADB() { adb -s "$ADB_SERIAL" "$@"; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== 1. Включаю отключённое =="
for p in com.samsung.android.rubin.app com.sec.android.diagmonagent com.samsung.android.knox.analytics.uploader \
  com.samsung.android.mapsagent com.samsung.android.app.omcagent com.google.android.gms.location.history \
  com.samsung.android.app.spage com.samsung.android.bixby.agent com.samsung.android.bixby.wakeup \
  com.samsung.android.bixbyvision.framework com.samsung.android.visionintelligence com.samsung.android.app.settings.bixby \
  com.samsung.android.sm.devicesecurity com.samsung.android.smartsuggestions com.samsung.android.homemode \
  com.samsung.android.beaconmanager com.samsung.android.easysetup com.samsung.android.service.stplatform \
  com.hiya.star com.samsung.android.smartcallprovider com.samsung.android.visualars \
  com.dsi.ant.server com.dsi.ant.sample.acquirechannels com.dsi.ant.plugins.antplus com.dsi.ant.service.socket \
  com.samsung.android.ardrawing com.samsung.android.app.watchmanagerstub com.samsung.android.inputshare \
  com.samsung.android.da.daagent com.samsung.android.svoiceime com.samsung.android.game.gos com.samsung.android.game.gametools \
  com.samsung.android.kidsinstaller com.samsung.android.mdx com.microsoft.appmanager com.samsung.android.app.sharelive \
  com.samsung.android.aware.service com.samsung.android.mdx.kit com.samsung.android.mcfds com.samsung.android.mcfserver \
  com.samsung.android.scloud com.samsung.android.fmm; do
  echo "  $p: $(ADB shell pm enable --user 0 "$p" 2>&1 | tr -d '\r')"
done

echo "== 2. Сторонние пакеты из последнего APK-бэкапа =="
BK=$(ls -d "$ROOT"/backups/apk-backups-* 2>/dev/null | sort | tail -1)
if [ -z "$BK" ]; then
  echo "Бэкапов нет ($ROOT/backups/apk-backups-*). Samsung-приложения можно поставить из Galaxy Store, Flipboard из Play."
else
  echo "Использую $BK"
  for d in "$BK"/*/; do
    [ -d "$d" ] || continue
    p=$(basename "$d"); N=$(ls "$d"/*.apk 2>/dev/null | wc -l | tr -d ' ')
    if [ "$N" = "0" ]; then echo "  ! в $p нет APK"
    elif [ "$N" = "1" ]; then ADB install -r "$d"/*.apk >/dev/null 2>&1 && echo "  OK $p" || echo "  ! не встал $p"
    else ADB install-multiple -r "$d"/*.apk >/dev/null 2>&1 && echo "  OK $p (split)" || echo "  ! не встал $p"; fi
  done
fi

echo "== 3. Фон RuStore обратно =="
ADB shell cmd appops set --user 0 ru.vk.store RUN_ANY_IN_BACKGROUND allow
ADB shell cmd appops set --user 0 ru.vk.store RUN_IN_BACKGROUND allow
echo "Откат завершён. Сверьте: adb shell pm list packages -d --user 0"
