#!/bin/bash
# Подключение к планшету по беспроводной отладке (Android 11+).
#
# Две грабли этого планшета:
#   1) штатный mDNS-бэкенд adb (openscreen) его НЕ видит — нужен Bonjour-режим
#      ADB_MDNS_OPENSCREEN=0 (переменная должна быть у adb-сервера, поэтому скрипт
#      перезапускает сервер с ней);
#   2) после подключения устройство видно двумя транспортами (ip:port и mDNS-имя),
#      и `adb shell` без -s отказывает «more than one device». Скрипт печатает
#      готовую строку export ADB_SERIAL=... — её ждут все остальные скрипты.
#
#   ./connect.sh [ip]                  подключиться (по умолчанию 192.168.1.169)
#   ./connect.sh pair <ip:порт> <код>  разовое сопряжение: на планшете
#                                      «Отладка по Wi-Fi → Подключить устройство с помощью кода»
#   eval "$(./connect.sh [ip] | tail -1)"   — сразу экспортировать ADB_SERIAL
set -u
IP_DEFAULT="192.168.1.169"
export ADB_MDNS_OPENSCREEN=0
command -v adb >/dev/null 2>&1 || { echo "adb не найден. macOS: brew install --cask android-platform-tools" >&2; exit 1; }

# сервер должен быть запущен с ADB_MDNS_OPENSCREEN=0 (Bonjour), иначе mDNS пуст;
# openscreen-бэкенд выдаёт "[Openscreen discovery ...]", Bonjour — числовую версию
if adb mdns check 2>/dev/null | grep -qi openscreen; then
  adb kill-server >/dev/null 2>&1; adb start-server >/dev/null 2>&1
fi

if [ "${1:-}" = "pair" ]; then
  [ $# -eq 3 ] || { echo "Использование: $0 pair <ip:порт_сопряжения> <6-значный код>" >&2; exit 1; }
  adb pair "$2" "$3"; exit $?
fi

IP="${1:-$IP_DEFAULT}"
PORT=$(adb devices | awk -v ip="$IP" 'index($1, ip":")==1 && $2=="device" {split($1,a,":"); print a[2]; exit}')
if [ -z "$PORT" ]; then
  echo "Ищу порт подключения $IP через mDNS (планшет не должен спать глубоко)..." >&2
  for _ in 1 2 3 4 5; do
    PORT=$(adb mdns services 2>/dev/null | awk -v ip="$IP" '$2=="_adb-tls-connect._tcp." && index($3, ip":")==1 {split($3,a,":"); print a[2]; exit}')
    [ -n "$PORT" ] && break
    sleep 2
  done
  [ -n "$PORT" ] || { echo "Планшет не найден: включена ли «Отладка по Wi-Fi»? Сопряжение делалось? ($0 pair ...)" >&2; exit 1; }
  adb connect "$IP:$PORT" >&2 || exit 1
fi
adb -s "$IP:$PORT" get-state >/dev/null 2>&1 || { echo "Подключился, но устройство не в состоянии device" >&2; exit 1; }
echo "Подключено: $IP:$PORT ($(adb -s "$IP:$PORT" shell getprop ro.product.model | tr -d '\r'))" >&2
echo "export ADB_SERIAL=$IP:$PORT"
