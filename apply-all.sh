#!/bin/bash
# Всё разом: подключение -> инвентарь -> чистка -> компиляция.
#   ./apply-all.sh [ip]     (по умолчанию 192.168.1.169)
# Компиляция в конце занимает 10–20 минут — запускать, когда планшет не занят видео.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
IP="${1:-192.168.1.169}"
step() { echo ""; echo "==================== $1 ===================="; }

step "1/4 Подключение"
eval "$("$DIR/connect-wireless-adb/connect.sh" "$IP" | tail -1)" || exit 1
[ -n "${ADB_SERIAL:-}" ] || { echo "Не удалось получить ADB_SERIAL"; exit 1; }
export ADB_SERIAL

step "2/4 Инвентарь (снимок состояния в backups/)"
"$DIR/inventory-audit/audit.sh" || exit 1

step "3/4 Чистка"
"$DIR/debloat-tab-s6-lite/debloat.sh" || exit 1

step "4/4 Компиляция speed-profile (10–20 минут)"
"$DIR/perf-dexopt/compile.sh" || exit 1

echo ""
echo "Готово."
echo "Откат чистки       -> debloat-tab-s6-lite/rollback.sh"
echo "Откат компиляции   -> perf-dexopt/revert.sh"
echo "Хвосты на диске    -> storage-leftovers/show-leftovers.sh (только показывает)"
