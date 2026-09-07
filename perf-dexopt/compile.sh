#!/bin/bash
# Принудительная AOT-компиляция всех приложений (speed-profile) — то, что система
# должна делать сама ночью, но не делает, если планшет никогда не простаивает
# (например, круглосуточно показывает часы). Запускается на самом планшете через
# nohup и переживает обрыв adb; скрипт ждёт завершения и показывает прогресс.
# 10–20 минут, планшет греется и подтормаживает — лучше на зарядке и не во время кино.
# Откат: ./revert.sh
# Нюанс: pgrep -f с шаблоном "packag[e]" — иначе он находит собственную оболочку adb shell.
set -u
: "${ADB_SERIAL:?Нужен export ADB_SERIAL=<ip:port> (см. connect-wireless-adb/connect.sh)}"
ADB() { adb -s "$ADB_SERIAL" "$@"; }
LOG=/data/local/tmp/dexopt.log

echo "Состояние до:"; ADB shell dumpsys package 2>/dev/null | tr -d '\r' | grep -oE "status=[a-z-]+\]" | sort | uniq -c | sort -rn
if [ "$(ADB shell "pgrep -f 'cmd packag[e] compile' | wc -l" 2>/dev/null | tr -d "\r ")" != "0" ]; then echo "Компиляция уже идёт"; else
  ADB shell "nohup sh -c 'cmd package compile -m speed-profile -a > $LOG 2>&1; echo EXIT=\$? >> $LOG' >/dev/null 2>&1 &"
  echo "Запущено на планшете ($(date '+%H:%M')), лог $LOG"
fi
i=0
while ! ADB shell "grep -q '^EXIT=' $LOG 2>/dev/null"; do
  sleep 30; i=$((i+1))
  [ $((i % 4)) -eq 0 ] && echo "  ...$((i/2)) мин, dex2oat: $(ADB shell 'pgrep -c dex2oat' 2>/dev/null | tr -d '\r')"
  [ $i -gt 120 ] && { echo "Час прошёл, а компиляция не закончилась — проверьте $LOG на планшете"; exit 1; }
done
echo "Результат: $(ADB shell "tail -2 $LOG" | tr -d '\r' | tr '\n' ' ')"
echo "Состояние после:"; ADB shell dumpsys package 2>/dev/null | tr -d '\r' | grep -oE "status=[a-z-]+\]" | sort | uniq -c | sort -rn
