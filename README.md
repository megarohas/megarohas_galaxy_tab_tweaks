# megarohas_galaxy_tab_tweaks

Твики для планшета Samsung **Galaxy Tab S6 Lite 2020** (SM-P610 Wi-Fi, One UI 5.1 /
Android 13, 4 ГБ RAM) через **ADB по Wi-Fi**, без root. Заточено под конкретный
планшет, но списки и команды стандартные для любого Samsung на One UI 5.

## Предыстория

Планшет достался от предыдущего владельца и живёт как настольные часы (Flip Clock),
плеер Plex и Яндекс Музыки. Аудит (только чтение) показал: при 4 ГБ RAM система
держала «status low» и почти 2 ГБ в ZRAM-свопе, из них ~750 МБ — фоновые резиденты
Samsung, которыми никто не пользуется (Daily Board, Samsung Cloud, Smart Suggestions,
Find My Mobile, McAfee-сканер, Quick Share/Continuity); «Поиск устройств поблизости»
сканировал BLE 100 % времени; Customization Service будил планшет 33 раза в сутки; а
ночная AOT-компиляция приложений никогда не запускалась, потому что планшет ночью не
простаивает, а показывает часы. После консервативной чистки память ушла в «status
normal», крашей нет.

## Состав

| Папка | Что внутри |
|---|---|
| [`connect-wireless-adb/`](connect-wireless-adb/) | Сопряжение и подключение по Wi-Fi. Знает две грабли планшета: mDNS работает только в Bonjour-режиме adb, а устройство видно двумя транспортами — печатает готовый `export ADB_SERIAL=...` |
| [`inventory-audit/`](inventory-audit/) | Снимок состояния (только чтение): getprop, пакеты, настройки, память по процессам, диск, батарея, джобы/алармы, использование приложений + парсеры |
| [`debloat-tab-s6-lite/`](debloat-tab-s6-lite/) | Консервативная чистка: системное только `pm disable-user`, стороннее — с бэкапом APK; полный откат рядом |
| [`perf-dexopt/`](perf-dexopt/) | Принудительная AOT-компиляция всех приложений (`speed-profile`), которую система сама не делает на никогда не простаивающем планшете |
| [`storage-leftovers/`](storage-leftovers/) | Показ «хвостов» удалённых приложений в общей памяти (WhatsApp/Telegram/файловые менеджеры/APK в Download); удаление — руками, командой из README |

Папки самодостаточны: README «что и почему» + идемпотентные скрипты; у чистки и
компиляции есть свой откат. Все скрипты ждут `export ADB_SERIAL=<ip:port>` —
его печатает `connect.sh`.

Всё разом — **`apply-all.sh [ip]`** в корне: подключение → инвентарь → чистка →
компиляция.

## Что скрипты НЕ трогают

Лаунчер (`com.sec.android.app.launcher`), SystemUI, Settings, GMS/GSF/Play Store,
WebView, Samsung account (`osp`), `mobileservice`, `spp.push`, `scpm`, весь стек
S Pen (`aircommand*`, `handwriting`, `livedrawing`, `pentastic`, `smartcapture`,
Samsung Notes), Галерею, Мои файлы, обе клавиатуры, Finder, Device care (`lool`),
агенты обновлений (`wssyncmldm`, `soagent`, `updatecenter`), Knox core, Dolby Atmos,
часы Flip Clock, Погоду, Plex, Яндекс Музыку, ReVanced + microG, Chrome, Gmail —
и **никакие VPN-приложения**: не удаляют и не ограничивают в фоне.

## Грабли, выученные на этом планшете

- **mDNS.** Штатный openscreen-бэкенд adb планшет не видит; нужен
  `ADB_MDNS_OPENSCREEN=0` у adb-сервера (Bonjour). `connect.sh` делает это сам.
- **Два транспорта.** После `adb connect` устройство числится и как `ip:port`, и как
  mDNS-имя; `adb shell` без `-s` отказывает. Отсюда обязательный `ADB_SERIAL`.
- **zsh и переменная `path`.** В ad-hoc циклах в zsh переменная с именем `path`
  перебивает `PATH` — пропадают `head`, `sed`, `tr`. Не называть так переменные.
- **Find My Mobile защищён.** `pm disable-user com.samsung.android.fmm` отвечает
  «Failed to change state». Сначала выключить «Поиск устройства» в Настройках →
  Биометрия и безопасность, потом отключать.
- **`dumpsys diskstats` врёт.** Размеры по приложениям берутся из кэша
  `/data/system/diskstats_cache.json`, который обновляется только в простое; здесь он
  был годовалой давности и показывал давно удалённые WhatsApp/TikTok. Верить `df`,
  `du` и инвентарю.
- **Load average ~19 — не проблема.** Ядро Exynos держит D-state потоки
  (`tz_worker_thread`, `simpleinteractive`), они всегда считаются в load. Смотреть
  `dumpsys cpuinfo` / `top`, а не `uptime`.
- **Dolby Atmos** работает в софте и держит ~0.4 ядра в audioserver во время
  воспроизведения, но на динамиках планшета звук без него заметно хуже. Оставлен
  сознательно; ключа в `settings` у него нет, только GUI.
- **Ночной dexopt не работает**, если планшет никогда не спит на зарядке
  (часы на экране): из 362 пакетов скомпилировано было 29. Лечится
  [`perf-dexopt/`](perf-dexopt/).

## Бэкапы

Всё, что скрипты снимают с устройства (инвентарь — в нём серийники и имя аккаунта,
APK удаляемых приложений, логи изменений), складывается в `backups/` в корне
репозитория — папка в `.gitignore` и в GitHub не попадает.

---
*Списки пакетов сверены с прошивкой `P610XXS7FYD1` (One UI 5.1, последнее
обновление для этой модели). На другом устройстве сначала снимите инвентарь и
просмотрите списки в `debloat.sh` перед запуском.*
