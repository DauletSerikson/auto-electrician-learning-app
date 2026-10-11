# Preview модуля 5

Откройте `preview.html` в браузере, масштаб 100%. Здесь 22 снимка новых
11 схем в двух темах. В каталоге `../r8_pilot/` сохранены снимки семи
утверждённых схем. PNG здесь — артефакты проверки, не Flutter assets.

Воспроизведение из корня worktree:

```powershell
$env:SAVE_R8_PREVIEWS = '1'
$env:R8_PREVIEW_FONT = 'F:/sdk/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf'
flutter test test/widgets/wiring_pilot_test.dart --reporter expanded
```

Снимки создаются `RepaintBoundary` вокруг существующего renderer с темой
приложения, padding 20 и TextScaler.linear(1.3). Проверки охватывают все
18 схем, ширины 320/360, обе темы. Физический Android smoke не выполнен.
