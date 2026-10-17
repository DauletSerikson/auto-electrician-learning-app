# Визуальная проверка R12

[Галерея](preview.html): 15 композиций × light/dark = 30 captures реального
`LessonBlockRenderer` и `AppTheme`, viewport 360 logical px, padding 20,
ширина изображения 320, Flutter textScaler ×1,3. PNG не масштабирует внутренний
шрифт вслед за textScaler: обязательные числа продублированы Flutter-текстом.

Все 30 кадров просмотрены в контактных листах: проверены подписи, соединения,
оси, точки, читаемость, белое внутреннее поле и контраст captions в обеих темах.
Отдельные исходные PNG starter_control/charging_power также просмотрены.
Автотесты дополнительно проверяют 320 logical px, размеры декодированных PNG,
геометрию картинки, положение caption и отсутствие Flutter exceptions.
Текст и задания всех десяти уроков проверены отдельным widget test на 360 ×1,3
в обеих темах. Это headless проверка, не физический Android QA.

Воспроизведение из корня worktree R12:

```powershell
$env:SAVE_R12_MODULE9_PREVIEWS = '1'
$env:R12_PREVIEW_FONT = 'F:/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
$env:R12_PREVIEW_SYMBOL_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/module_9_diagrams_test.dart --reporter expanded
```

Пути шрифтов локальны и нужны только для captures headless engine.
Обычный тестовый запуск не пишет изображения. Production fonts не менялись.
PNG/SVG создаются `tools/render_starting_charging_assets.py` с существующим
resvg-py 0.2.0, авторство и допущения — в
[README графики](../../../assets/images/starting_charging/README.md).
