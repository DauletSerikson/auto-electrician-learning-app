# R14.2B–R14.4 — модуль 11 «Автомобильный осциллограф и анализ сигналов»

Дата: 19 октября 2026. Worktree: `electrician-r14`.
Ветка: `feature/module-11-automotive-oscilloscope`.
Baseline: утверждённый MVP `04e880c`; план —
[R14_MODULE_11_PLAN.md](../roadmap/R14_MODULE_11_PLAN.md).

## Результат и изученная реализация

Курс содержит **11 модулей, 102 урока, 1339 блоков, 557 оцениваемых заданий**.
Новый `stage_10` добавляет **10 уроков, 146 блоков, 66 заданий**.
Семь интерактивных oscilloscope-блоков используются в **пяти уроках** — 3, 4,
5, 9 и 10. Добавлены **18 авторских пар SVG/PNG**. Плановые композиции R14.1
объединены по учебному смыслу: кейсы повторно используют подписанные записи,
а не получают декоративные дубликаты.

Изучены sealed LessonBlock и JSON parsing, LessonBlockRenderer, симуляторы,
LessonScreen, LessonAttempt, CourseService/ProgressService, callbacks retry,
completion, существующие content/diagram/quiz tests и предыдущие authoring tools.
Целевой аудит MVP до интеграции прошёл 49 тестов; исправления production Dart
не потребовались. Подробное [ревью сигналов](R14_MODULE_11_SIGNAL_REVIEW.md)
описывает математику, направления/режимы триггера и пределы вывода.

## Содержание десяти уроков

| № | Тема | Практика |
| --- | --- | --- |
| 1 | Назначение автомобильного осциллографа | Выбор прибора, форма против среднего, краткое нарушение, предел наблюдения |
| 2 | Устройство, щупы и безопасность | Общие земли/PE, дифференциальное измерение, допустимая точка в заданной схеме, пределы входа |
| 3 | Масштабы напряжения, времени и триггер | Три реальные интерактивные настройки: V/div/центр, ms/div, уровень и rising/falling; Normal/Auto/Single |
| 4 | Аналоговые сигналы | Амплитуда/размах/смещение, ramp, помеха, пропуск; исследование MVP и ограничение диагноза |
| 5 | Период, частота и ШИМ | T/f/tHigh/DHigh/среднее, настройка окна, сравнение двух заполнений, DOn против DHigh |
| 6 | Сигналы ДПКВ и ДПРВ | Индуктивная/Hall конструкции, учебные диски, скорость, опорный промежуток, общая временная ось |
| 7 | Сигналы исполнительных механизмов | Low/high-side, заданный clamp, среднее, необходимость тока и механической проверки |
| 8 | Осциллограммы CAN и LIN | Дифференциальная/common-mode величины, dominant/recessive, битовый интервал против периода, физика против decoder |
| 9 | Комплексные диагностические кейсы | K1–K6: условия → наблюдение → гипотезы → вывод → следующая проверка; восстановление trigger |
| 10 | Итоговый практикум | 15 заданий: 9 Question, 5 Calculation, 1 Oscilloscope; проходной порог 80% |

Уроки 1–9 требуют все правильные ответы по прежним правилам. Для quiz нужны
все 15 отвеченных и не менее 12 правильных; completion сохраняется только
после отдельной кнопки. Retry расчёта и изменение проверенной настройки
осциллографа снимают ответ и временно блокируют завершение. Переход к 102 урокам
меняет знаменатель общего прогресса; старые completed IDs сохраняются.

Уроки и упражнения полностью офлайн, не требуют автомобиля или прибора.
Физические измерения/декодирование CAN/LIN/двухканальный захват не приписаны MVP.

## Изменённые файлы и архитектурные границы

- `assets/course/stage_10/`: индекс и десять новых JSON, стабильные IDs
  `oscilloscope_01`–`oscilloscope_10`.
- `assets/course/modules.json`: только добавлен один модуль в конец списка;
  первые десять записей сохранены.
- `pubspec.yaml`: только две строки регистрации нового course/image каталога.
- `assets/images/oscilloscope/`: 18 PNG, SVG originals, catalog и provenance README.
- `tools/build_oscilloscope_course.py`: воспроизводимый авторинг только stage_10;
  `tools/render_oscilloscope_assets.py`: оригинальная математическая геометрия;
  `tools/audit_oscilloscope_module.py`: read-only baseline/bundle audit.
- Новые content/geometry, widget/quiz и diagram tests; в исторических tests
  обновлены точные counts, знаменатели и состав списка модулей/quiz metadata.
  Добавлен ожидаемый существующий OscilloscopeLessonBlock в проверку
  классификации реальных course assets.
- Два отчёта и шесть representative renderer captures.

**Весь `lib/` остался прежним**, включая MVP, pilot entrypoint, persistence,
общий scoring, renderer и старые симуляторы. Новых типов блоков, зависимостей,
state-management frameworks, backend или Android configuration нет.
Прежние 92 урока/IDs/изображения не переписаны. R6/Android QA и другие worktrees
не затронуты. Для реальных уроков применён существующий typed JSON контракт.

## Проверки и регрессии

Добавлено **20 тестов**, baseline 812 → **832**:

- `test/services/module_11_content_test.dart`: **13**. Реальные JSON и metadata,
  11/102, порядок/уникальность/старый prefix, 146/66/7/18, пять интерактивных
  уроков, все asset references, 15/80, сохранение всех 92 IDs плюс неизвестного
  и pilot ID, решаемость всех настроек, независимые расчёты, SVG waveform/axes,
  PWM/пропуск, Hall/CKP/CMP, площадь clamp, CAN differential/common-mode,
  LIN и средние конечных окон по площади реальной нарисованной кривой.
- `test/widgets/module_11_quiz_test.dart`: **4**. Все text/tasks обоих theme
  при 360 px/×1,3; основная навигация открывает настоящий первый урок;
  настоящий смешанный quiz: 11/15 не проходит → retry расчёта → 12/15;
  изменение проверенного scope и retry вопроса временно снимают eligibility;
  до явного завершения нет записи, после — одна запись с сохранением старых IDs.
- `test/widgets/module_11_diagrams_test.dart`: **3**. Decode всех 18 bundled PNG,
  размеры ×3, исключение source SVG из runtime, layout всех image/captions
  light/dark при 360 px/×1,3; optional captures не создаются обычным test run.

Исторические тесты не удалены/ослаблены: старые локальные модели, quiz,
immutable DiagnosticMeasurementRecord и storage concurrency продолжают
проверяться. Общекурсовые exact expectations обновлены до 11/102 и 91 ordinary
урока + 11 quiz; старые prefix-тесты сохраняют границы своих прежних модулей.

Первый интеграционный прогон обнаружил семь оставшихся count/list ожиданий,
которые исправлены точечно. Тест нового quiz предварительно декодирует PNG
в real async и использует достаточный viewport для длинного реального урока.
Новый diagram test очищает rootBundle между тестами и загружает JSON в real
async: это устраняет зависание cached future из завершённой fake-async зоны.
Production код ради тестов не менялся.

## Визуальная проверка

Все 18 изображений и captions отрендерены обеими темами при 360 logical px
и text scale 1,3: 36 captures в ignored `build/r14_module11_previews`.
Для снимка всей карточки увеличен только viewport по высоте; проверка обычного
layout также выполнена при 360×1050. Шесть кадров CKP/CMP, clamp и CAN сохранены
в [r14_module11](r14_module11/README.md) и просмотрены вместе с SVG/PNG
без наложения/обрезания подписей. PNG имеет стабильный непрозрачный белый фон;
условия продублированы масштабируемым Flutter caption. Статические осевые числа
не увеличиваются с системным шрифтом — это ограничение явно учтено.

Примеры: [ДПКВ/ДПРВ light](r14_module11/crank_cam_light_360.png),
[low-side light](r14_module11/actuator_low_light_360.png),
[CAN dark](r14_module11/can_levels_dark_360.png).

Снимки — headless Flutter renders с локально загруженным Arial для captions;
это не кадры с устройства и не подтверждение TalkBack/реальных touch gestures.

## Фактическая верификация

| Команда | Результат |
| --- | --- |
| Целевой прогон трёх MVP test files до интеграции | Exit 0; **49 / All tests passed!** |
| `dart format lib test` | Exit 0; 106 файлов; итоговый код отформатирован, lib без изменений |
| `flutter pub get` | Exit 0; dependencies/lock прежние, upgrade не выполнялся |
| `flutter analyze` | Exit 0; **No issues found!**, 2,4 s |
| `flutter test --reporter expanded` | Exit 0; **832 / All tests passed!**, 81 s; 812 baseline + 20 новых |
| Diagram capture run с Arial / `SAVE_R14_MODULE_PREVIEWS=1` | Exit 0; 3 теста, 2 s; 36 PNG сформированы |
| Отдельный реальный mixed quiz | Exit 0; 1 тест, 13 s |
| `flutter build apk --debug` | Exit 0; **Built build/app/outputs/flutter-apk/app-debug.apk**, 28,6 s |
| `python tools/audit_oscilloscope_module.py --apk build/app/outputs/flutter-apk/app-debug.apk` | Exit 0; **11/102/1339/557**, **325 baseline файлов неизменны**, все **218 referenced JSON/PNG** bundled byte-exact; новые SVG/catalog sources исключены |
| `git diff --check` | Exit 0; staged diff проверяется перед локальными коммитами |
| `git status --short` | Перед staging только новый контент/integration/tests/tools/verification; итоговый SHA и clean status сообщаются владельцу |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **197128568 bytes**.
SHA256: `fa2c8710590b8a83b1e06294482ba5faaa13210d2ebb6715854fbefdf3e1fa59`.
Это локальный debug build, не production-store signing; APK не добавлен в Git.
Gradle предупредил о Java native access, сборка завершилась exit 0.
Generated registrants macOS/Windows без содержательного diff возвращаются к HEAD
только в этом worktree; пользовательские изменения не откатываются.

## Оставшиеся ограничения и STOP

`flutter devices --machine` показал Windows, Chrome и Edge, без Android device
или emulator. Физический Android smoke, TalkBack, реальный ввод на телефоне и
испытания осциллографа не выполнены. R6 Android QA остаётся отдельной работой.
Самопроверка материала не равна независимому экспертному ревью.

Новый модуль не превращает MVP в двухканальный прибор, solver катушки или
протокольный анализатор. Данные/геометрия синтетические; реальные допуски,
подключения и выводы требуют документации конкретной системы.
Обязательные упражнения не требуют опасного подключения к SRS/HV.

После R14 — **STOP**. Push, merge, tag и GitHub Release не выполняются;
следующий модуль самостоятельно не начинается.
