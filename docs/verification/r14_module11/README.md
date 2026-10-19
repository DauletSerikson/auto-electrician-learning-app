# R14 — representative Flutter captures

Ширина 360 logical px, text scale ×1,3, light/dark. Все 18 изображений и captions
прошли layout-test; полный набор 36 рендеров — ignored `build/r14_module11_previews`.
Здесь сохранены шесть кадров CKP/CMP, low-side и HS-CAN для review.
Это headless widget captures, не скриншоты Android.

| Пример | Light | Dark |
| --- | --- | --- |
| Общая ось CKP/CMP | [кадр](crank_cam_light_360.png) | [кадр](crank_cam_dark_360.png) |
| Заданный clamp | [кадр](actuator_low_light_360.png) | [кадр](actuator_low_dark_360.png) |
| HS-CAN и разность | [кадр](can_levels_light_360.png) | [кадр](can_levels_dark_360.png) |

Воспроизведение (PowerShell; путь font зависит от окружения):

```powershell
$env:R14_MODULE_FONT='C:\Windows\Fonts\arial.ttf'
$env:SAVE_R14_MODULE_PREVIEWS='1'
flutter test test/widgets/module_11_diagrams_test.dart --reporter expanded
```

Для полной карточки capture увеличивает viewport по высоте до 5000;
ширина, 20-px padding реального LessonScreen, production renderer, theme и
text scale сохранены. При обычном запуске тест использует высоту 1050.
PNG-подписи не растут с системным шрифтом, поэтому значения и условия
продублированы масштабируемым caption. Font не добавлен в приложение.
