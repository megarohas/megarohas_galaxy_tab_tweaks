#!/bin/bash
# Только чтение: показывает типичные «хвосты» удалённых приложений в общей памяти
# (папки мессенджеров, файловых менеджеров, установочные APK в Download).
# Удалять — руками, командой из README, после того как посмотрели, что внутри.
set -u
: "${ADB_SERIAL:?Нужен export ADB_SERIAL=<ip:port>}"
adb -s "$ADB_SERIAL" shell 'cd /storage/emulated/0 && for d in WhatsApp Telegram Viber .estrongs ADM Movies/Viber Movies/Telegram Android/media/com.whatsapp Pictures/Telegram; do [ -e "$d" ] && echo "$(du -sk "$d" | cut -f1) КБ  $(find "$d" -type f | wc -l) файлов  $d"; done; echo; echo "Download:"; ls -la Download 2>/dev/null | grep -iE "\.apk|\.zip" ; echo; df -h /storage/emulated/0 | tail -1' | tr -d '\r'
