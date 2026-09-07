# inventory-audit

Снимок состояния планшета перед любыми изменениями. **Только чтение.**

```bash
export ADB_SERIAL=192.168.1.169:PORT
./audit.sh                      # -> backups/inventory-<дата>/ + SUMMARY.txt
python3 parse_packages.py backups/inventory-<дата>/dumpsys-package.txt out.tsv   # таблица пакетов: система/сторонние, установщик, даты, состояние
python3 parse_diskstats.py backups/inventory-<дата>/diskstats.txt                # размеры по приложениям (см. про врущий кэш в корневом README)
python3 parse_usage.py backups/inventory-<дата>/usagestats-plain.txt             # что реально запускалось
```

Что снимается: `getprop`, все списки пакетов, `dumpsys package/appops/deviceidle`,
settings (global/system/secure), `/proc/meminfo` + `dumpsys meminfo`, `ps`,
`dumpsys activity processes/services`, `jobscheduler`, `alarm`, `df` + `diskstats` +
`du` общей памяти, `dumpsys battery/batterystats/power`, sysfs батареи (циклы,
здоровье), `usagestats`, краткие `wifi/connectivity/netstats`.

`usagestats-plain.txt` скрипт не снимает — это `adb shell dumpsys usagestats`
без `--checkin`, снимите отдельно, если нужен парсер использования.

В SUMMARY.txt — модель, билд и патч, CSC, пакеты, RAM/своп, диск, батарея,
анимации, экран, режимы питания и сканирования, IME, accessibility.
