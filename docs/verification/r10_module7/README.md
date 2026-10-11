# Проверка изображений остальных уроков R10

16 PNG-снимков восьми новых композиций: viewport 360 logical px,
светлая/тёмная AppTheme, `TextScaler.linear(1.3)`, отступы LessonScreen 20 px.
Снимки сделаны действующим `LessonBlockRenderer`, без production Dart edits.

[Локальная галерея полного набора](preview.html) объединяет эти 16 снимков
и 22 сохранённых [снимка пилота](../r10_pilot/README.md).
Длинные композиции целиком захвачены в RepaintBoundary; высота снимка
не означает одновременную видимость на экране телефона — нужна прокрутка.

Воспроизведение из корня worktree в PowerShell:

```powershell
$env:SAVE_R10_PREVIEWS = '1'
$env:R10_PREVIEW_FONT = 'F:/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
$env:R10_PREVIEW_SYMBOL_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/module_7_diagrams_test.dart
```

Roboto и optional Arial загружаются только тестовым harness, поскольку у
headless Flutter нет Android system font fallback. Файлы шрифтов не входят
в репозиторий или приложение. Обычный test run не записывает снимки.
PNG уже содержит Arial в пикселях: textScaler увеличивает подпись Flutter,
но не внутренние подписи изображения.

Все 16 снимков новых рисунков просмотрены: шкалы, контраст, подписи,
соединения и границы изображений читаемы, пересечений текста с линиями и
обрезки не обнаружено. Отдельно layout-тесты проверяют изображения при
320/360 px и текст/вопросы/расчёты всех десяти уроков при 360 px ×1,3.
Автоматическое отсутствие overflow не доказывает удобство для всех
пользователей. Проверка Android, TalkBack и обучение новичков не проведены.
