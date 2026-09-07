# debloat-tab-s6-lite

Консервативная чистка Galaxy Tab S6 Lite (One UI 5.1). Root не нужен, **всё обратимо**.

```bash
export ADB_SERIAL=192.168.1.169:PORT
./debloat.sh      # чистка (сначала снимите инвентарь: ../inventory-audit/)
./rollback.sh     # полный откат
```

## Принципы

- Системные пакеты только **`pm disable-user --user 0`** — откат `pm enable --user 0`.
- Сторонние (живут в `/data/app`) — скрипт **сначала скачивает все split-APK в
  `backups/apk-backups-<дата>/`** и только потом `pm uninstall --user 0`; откат ставит
  их обратно `adb install(-multiple)`.
- RuStore не удаляется, а переводится в «Ограничено» для фона
  (`appops RUN_ANY_IN_BACKGROUND ignore`) — обновления в нём при открытом приложении.
- В конце скрипт сам проверяет, что критичные компоненты на месте и включены.

## Что отключается

| Категория | Пакеты |
|---|---|
| Телеметрия и персонализация | `rubin.app` (Customization Service: 33 пробуждения/сутки), `diagmonagent`, `knox.analytics.uploader`, `mapsagent` и `app.omcagent` («Рекомендуемые приложения»), `gms.location.history` |
| Промо | `app.spage` (Samsung Free) |
| Bixby | `bixby.agent`, `bixby.wakeup`, `bixbyvision.framework`, `visionintelligence`, `app.settings.bixby` |
| Фоновые резиденты | `sm.devicesecurity` (McAfee, 71 МБ), `smartsuggestions` (133 МБ), `homemode` (Daily Board, 83 МБ), `beaconmanager` + `easysetup` (BLE-скан 24/7) + `service.stplatform` |
| Телефонное на Wi-Fi-планшете | `hiya.star`, `smartcallprovider`, `visualars` |
| ANT+ | `com.dsi.ant.*` ×4 |
| AR / заглушки | `ardrawing`, `watchmanagerstub`, `inputshare`, `da.daagent`, `svoiceime`, `game.gos`, `game.gametools`, `kidsinstaller` |
| По решению владельца | Link to Windows (`mdx`, `microsoft.appmanager`), Quick Share/Continuity (`app.sharelive`, `aware.service`, `mdx.kit`, `mcfds`, `mcfserver`), Samsung Cloud (`scloud`) |

Удаляется с бэкапом APK: `visionarapps`, `livestickers` (DECO PIC), `icecone`
(Keyboard Content Center), `privateshare`, `flipboard.boxer.app`,
`com.samsung.memorysaver`, `com.sec.android.app.kidshome` (Samsung Kids).

`com.samsung.android.fmm` (Find My Mobile) в списке есть, но Samsung его защищает:
`disable-user` отвечает «Failed to change state» — сначала выключите «Поиск
устройства» в Настройках → Биометрия и безопасность, потом перезапустите скрипт.

## Что НЕ трогаем (не вносить в списки!)

Лаунчер, SystemUI, Settings, GMS/GSF/Play, WebView, Samsung account (`osp`),
`mobileservice`, `spp.push`, `scpm`, S Pen-стек, Галерея, Мои файлы, клавиатуры,
Finder, Device care (`lool`), агенты обновлений, Knox core, Dolby Atmos, часы
Flip Clock, Погода, Plex, Яндекс Музыка, ReVanced + microG, Chrome, Gmail —
и **никакие VPN**.

## Результат на SM-P610 (4 ГБ RAM), 2026-09-07

Отключено 41 системный пакет, удалено 7 сторонних. Память при том же играющем
Plex: `status low` → `normal`, Free RAM 594 → 899 МБ, used PSS 3.72 → 3.39 ГБ,
своп 1.94 → 1.72 ГБ. Крашей и ANR после чистки нет.
