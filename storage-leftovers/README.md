# storage-leftovers

Когда приложения удалены, их папки в общей памяти остаются: на этом планшете
после предыдущего владельца лежали `WhatsApp/` (559 МБ, 3.5 тыс. файлов),
`Telegram/`, `.estrongs/`, `ADM/`, пустые `Movies/Viber`, плюс в `Download/`
установочные APK.

```bash
export ADB_SERIAL=192.168.1.169:PORT
./show-leftovers.sh     # только показывает размеры и число файлов
```

Удаление — сознательно руками, после просмотра (необратимо):

```bash
adb -s $ADB_SERIAL shell 'cd /storage/emulated/0 && rm -rf WhatsApp Telegram .estrongs ADM Movies/Viber Movies/Telegram'
adb -s $ADB_SERIAL shell 'rm -f /storage/emulated/0/Download/*.apk'
```

Кэши приложений (`pm trim-caches`) здесь не чистятся: при 40 ГБ свободного
места это ничего не даёт.
