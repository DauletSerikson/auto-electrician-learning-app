# Предварительный просмотр полного модуля 8

[Галерея](preview.html): 14 композиций × две темы. Десять новых кадров
и 18 сохранённых кадров пилота; это реальные captures production
LessonBlockRenderer/AppTheme, не HTML-имитация экрана. Viewport 360,
padding 20, ширина PNG 320 logical px, Flutter textScaler ×1,3.

Новые изображения: diagnostic_chain, dlc_front, scanner_scope, dtc_status,
compare_voltage. Все десять новых кадров просмотрены; DLC/status повторно
после исправления геометрии нижнего ряда/длины подписи. Старые preview
файлы не переписывались; их проверка описана в отчёте пилота.

Воспроизведение новых captures из electrician-r11:

```powershell
$env:SAVE_R11_MODULE8_PREVIEWS = '1'
$env:R11_PREVIEW_FONT = 'F:/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
$env:R11_PREVIEW_SYMBOL_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/module_8_diagrams_test.dart --reporter expanded
```

Пути шрифтов локальные, загрузка только в headless tests; production font
fallback не менялся. PNG-подписи не масштабируются textScaler. Ключевые
данные дублируются обычным Flutter-текстом. Пять SVG/PNG экспортируются
`tools/render_obd_module_assets.py` с существующим resvg-py 0.2.0;
он не перерисовывает девять пилотных пар. Аудит: `python tools/audit_obd_module.py`.
Физический Android smoke не выполнялся.

[Итоговый отчёт](../R11_MODULE_8.md) ·
[Техническое ревью и таблицы](../R11_MODULE_8_TECHNICAL_REVIEW.md).
