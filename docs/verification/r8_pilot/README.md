# Просмотр графического пилота на 360 px

Это снимки **существующего Flutter LessonBlockRenderer**, а не HTML-макеты.
Ширина каждого PNG — 360 logical px при pixelRatio=1; отступы по 20 px как
в `LessonScreen`, ширина учебного изображения 320 px. Использованы `AppTheme`
и увеличенный текст ×1,3; Roboto загружен из локального Flutter SDK для
предварительного просмотра вместо тестового Ahem. Снимки охватывают один
image-блок с подписью; они не являются физическими Android screenshots.

Открывайте PNG в масштабе 100% или [галерею](preview.html) в браузере — она
задаёт ширину 360 CSS px без уменьшения на широком экране. Zoom браузера 100%.
SVG можно открыть напрямую в браузере или в редакторе векторной графики:
`assets/images/wiring/source/`. В README assets есть происхождение всех файлов.

| Урок | Кадр из renderer |
| --- | --- |
| 2, лампа/защита/выключатель | [2A](symbols_lamp_light_360.png) |
| 2, узел и пересечение | [2B](symbols_junction_light_360.png) |
| 4, реле без возбуждения | [4A](relay_off_light_360.png) |
| 4, реле с возбуждением | [4B, светлая тема](relay_on_light_360.png), [тёмная тема](relay_on_dark_360.png) |
| 5, питание и переходы листа | [5A](connector_page_1_light_360.png) |
| 5, потребитель и обратный путь | [5B](connector_page_2_light_360.png) |
| 5, противоположные виды X1 | [5C](connector_views_light_360.png) |

Воспроизведение (из корня worktree; путь SDK заменить своим):

```powershell
$env:SAVE_R8_PREVIEWS = '1'
$env:R8_PREVIEW_FONT = 'F:/sdk/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf'
flutter test test/widgets/wiring_pilot_test.dart --reporter expanded
```

Обычный полный suite не требует этих переменных и не пишет preview-файлы.
`SAVE_R8_PREVIEWS` включает запись только в этот каталог; это review-артефакты,
не golden baselines. Кадры созданы из авторских PNG через production renderer
2026-10-11 в рамках R8.2; сторонних изображений в них нет. Шрифт не копируется
в репозиторий. Ограничения и результат проверки: [отчёт](../R8_GRAPHIC_PILOT.md).
