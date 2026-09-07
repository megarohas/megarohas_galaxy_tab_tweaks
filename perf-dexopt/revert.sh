#!/bin/bash
# Откат: сброс состояния компиляции к дефолту (система перекомпилирует сама,
# когда/если доберётся до ночного обслуживания).
set -u
: "${ADB_SERIAL:?Нужен export ADB_SERIAL=<ip:port>}"
adb -s "$ADB_SERIAL" shell cmd package compile --reset -a 2>&1 | tail -2
echo "Готово."
