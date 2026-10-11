# Просмотр иллюстраций R10.2A

[Локальная галерея](preview.html): 11 image-блоков × 2 темы, 22 PNG-снимка.
Это реальные captures `LessonBlockRenderer`/`AppTheme` из пилотных JSON,
а не HTML-имитация приложения. Viewport 360, padding 20, textScaler 1,3.
Одна используемая дважды схема R/S/G показана с первой подписью урока 3;
условия нормального и дефектного измерения также доступны в тексте урока 6.

Снимки получены опциональной ветвью нового diagram test. В обычном suite
они не перезаписываются и не выступают golden baselines.

Воспроизведение в PowerShell из `electrician-r10`:

```powershell
$env:SAVE_R10_PREVIEWS = '1'
$env:R10_PREVIEW_FONT = 'F:/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
$env:R10_PREVIEW_SYMBOL_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/electronics_pilot_diagrams_test.dart --reporter expanded
```

Пути шрифтов локальные: при другом SDK/ОС задайте доступные аналоги.
Roboto загружается только в headless test; Arial служит fallback символов.
Production fonts/theme и dependencies не меняются. SVG экспортировались
локальным Arial; файл шрифта в проект не включён.

Просмотр всех 22 кадров выполнен агентом при подготовке отчёта. Подписи,
U(S,G), единицы V/kPa/s/ms, масштабы и R/S/G/B− различимы. На 320 px есть
дополнительные layout tests, но PNG-текст уменьшается до 15,75 logical px.
Системный текст масштабирует только caption/Flutter-текст, не bitmap.
Физический Android smoke и проверка реальным новичком не выполнялись.
Подробности: [R10_ELECTRONICS_PILOT.md](../R10_ELECTRONICS_PILOT.md).
