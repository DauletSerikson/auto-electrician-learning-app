# Просмотр R11.2A

[Галерея](preview.html): девять image-блоков × две темы, 18 кадров actual
`LessonBlockRenderer`/`AppTheme` из пилотных JSON. Viewport 360 logical px,
padding 20, ширина изображения 320, Flutter textScaler ×1,3. Не HTML-макет
приложения и не golden baseline. Повторно используемый FF-A снят с первой
подписью урока 6; условия кейса также продублированы текстом в уроке 9.

Все 18 кадров просмотрены при подготовке пилота. Для PNG textScaler
не увеличивает внутренние подписи; исходный размер минимум 18 logical px.
Данные повторяются обычным Flutter-текстом. Android smoke не выполнялся.

Воспроизведение из `electrician-r11` в PowerShell:

```powershell
$env:SAVE_R11_PREVIEWS = '1'
$env:R11_PREVIEW_FONT = 'F:/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
$env:R11_PREVIEW_SYMBOL_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/obd_pilot_diagrams_test.dart --reporter expanded
```

Пути локальные; на другой машине укажите доступные шрифты. Они загружаются
только в headless tests. App fonts/theme и зависимости не менялись.
Генерация SVG/PNG: `python tools/render_obd_assets.py` с существующим
resvg-py 0.2.0 в PYTHONPATH. Read-only аудит: `python tools/audit_obd_pilot.py`.
Подробности и таблицы — [отчёт](../R11_OBD_PILOT.md).
