# R15: примеры Flutter image/caption renders

21 октября 2026. H-мост, K3 (масса) и K4 (park) в light/dark.
Headless Flutter, 360 logical px, scale 1,3, локальный Arial для captions.
Это не скриншоты Android-устройства и не подтверждение TalkBack.

Генерация: `R15_MODULE_FONT=C:/Windows/Fonts/arial.ttf`,
`SAVE_R15_MODULE_PREVIEWS=1`,
`flutter test test/widgets/module_12_diagrams_test.dart`.
В PowerShell переменные задаются через `$env:...`.
Все 32 captures находятся в ignored `build/r15_module12_previews`;
обычный test run их не создаёт.

| Схема | Светлая | Тёмная |
| --- | --- | --- |
| H-мост | [light](h_bridge_light_360.png) | [dark](h_bridge_dark_360.png) |
| K3, потери массы | [light](case_lamp_light_360.png) | [dark](case_lamp_dark_360.png) |
| K4, park | [light](case_park_light_360.png) | [dark](case_park_dark_360.png) |
