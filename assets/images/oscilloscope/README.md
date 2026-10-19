# Авторские осциллограммы R14

18 пар SVG/PNG созданы для модуля 11 по формулам из
`tools/render_oscilloscope_assets.py`; учебные паспорта находятся в caption
соответствующих ImageLessonBlock и `docs/verification/R14_MODULE_11_SIGNAL_REVIEW.md`.
Это синтетические модели, не записи автомобиля, не OEM artwork.
Сторонние изображения не использовались. Авторство: проект Daulet Serikson.
Лицензия исходников и этих геометрических рисунков — MIT проекта.

SVG находятся в `source/`, экспорт PNG ×3 через существующий resvg-py 0.2.0
(только dev tooling; Flutter dependencies прежние). SVG/каталог не нужны runtime.
Оси каждой кривой подписаны; `polyline` содержит audit attributes геометрии.
Ширина исходника 320, основной текст 17–20 px; осевые числа 12–13 px
дублируются шкалами и доступным текстовым caption. Белый непрозрачный фон
сохраняет контраст обеих тем. Статические подписи не растут с text scale:
условия и значения также даны в масштабируемом Flutter-тексте.

| Файл | Назначение |
| --- | --- |
| instrument_compare | Форма PWM и DC с одним средним |
| common_ground | Опасный путь КЗ через общие зажимы |
| differential_input | Разность выводов и требования к входу |
| scale_axes | Синус: A, Vpp и период |
| trigger_edges | Рост/спад и диапазон уровня |
| analog_ramp | Однократное плавное изменение |
| analog_noise | Помеха на отдельном постоянном участке |
| missing_pulse | Один подавленный импульс |
| pwm_compare | Два заполнения при одном периоде |
| inductive_speed | Условная зависимость от скорости |
| hall_crank | Учебный Hall и диск 12−1 при двух rpm |
| crank_cam | Одновременные CKP/CMP в известном цикле |
| actuator_low | Low-side с заданным clamp |
| actuator_high | High-side резистивной нагрузки |
| can_levels | HS-CAN: две линии и разность |
| lin_levels | LIN: физические состояния |
| can_suspect | Изменённая разность HS-CAN |
| lin_suspect | Поднятый dominant LIN |
