# R15.2–R15.4 — модуль 12 «Кузовная электроника и системы комфорта»

Дата: 21 октября 2026, Asia/Qyzylorda. Worktree: `electrician-r15`.
Ветка: `feature/module-12-body-electronics`.
Основа: утверждённый [план R15.1](../roadmap/R15_MODULE_12_PLAN.md), `2e02a42`.
Технические допущения и ревью — в [отдельном отчёте](R15_MODULE_12_ELECTRICAL_REVIEW.md).

## Результат и границы изменений

Курс: **12 модулей, 112 уроков, 1511 блоков, 628 оцениваемых заданий**.
Новый `stage_11`: **10 уроков, 172 блока, 71 задание**, **16 оригинальных пар
SVG/PNG**. Предыдущий baseline: 11/102/1339/557 и 832 теста.

Изучены фактические sealed LessonBlock, renderer, LessonScreen/LessonAttempt,
CourseService/ProgressService, fixed simulation models, current scope evaluator,
content/diagram/quiz/progress tests и инструменты авторинга R13/R14.
Новый модуль использует прежние механизмы и полностью bundled/offline.

| № | Урок | Практика |
| --- | --- | --- |
| 1 | Архитектура BCM | Вход/разрешение/выход/действие, отдельная силовая ветвь |
| 2 | Центральный замок | Импульс реверса, полярность щупов, передача DA–A |
| 3 | Стеклоподъёмники | Полный мост, торможение/Hi-Z, разрешения и anti-pinch |
| 4 | Освещение | Лампа/LED/ключи, масса K3, отдельный плюсовой V1 и среднее PWM |
| 5 | Дворники/омыватели | W1, отдельный park-вход, команда OFF и обратная связь |
| 6 | Зеркала/сиденья | Ось, память, датчик, электрическая мощность, граница SRS |
| 7 | HVAC | Заслонка, диапазон датчика, силовое питание/команда, RMS и SCOPE1 |
| 8 | Датчики/сети | Три записи входа/запроса/разрешения/выхода, предел CAN/LIN |
| 9 | Комплексная диагностика | K1–K5, по три решения на карту; обычный урок |
| 10 | Итоговый практикум | 15 заданий: 11 Question, 3 Calculation, 1 Oscilloscope; 80% |

Кейсы: одна дверь не запирается; стекло идёт только вниз; тусклая фара;
дворники не паркуются; вентилятор не работает в LOW/MED. Для каждого указаны
симптом, схема, источник, команда/окно, состояние механизма, точки и полярность,
измерения, гипотезы, допустимый вывод и следующая проверка. K2 намеренно
не устанавливает единственную причину. K1/K4/K5 локализуют участок/элемент,
но не точное место повреждения или причину срабатывания защиты без данных.

Обычный урок требует всех правильных ответов. Quiz требует ответить на все
15 и набрать минимум 12; completion записывается отдельной кнопкой. Retry
снимает ответ, изменение проверенных scope-настроек также снимает его.
Прогресс хранит прежние completed IDs; общий знаменатель теперь 112.

## Файлы и архитектурная сохранность

- `assets/course/stage_11/`: индекс и десять уроков, IDs `body_electronics_01`–`10`.
- `assets/course/modules.json`: одна запись в конце; первые 11 сохранены.
- `pubspec.yaml`: только регистрация нового course/image каталога.
- `assets/images/body_electronics/`: 16 runtime PNG, SVG originals, размеры и provenance.
- `tools/build_body_electronics_course.py`: авторинг только stage_11.
- `tools/render_body_electronics_assets.py`: оригинальные схемы и PNG ×3;
  используется уже существующий resvg-py dev tool, application dependency не добавлена.
- `tools/audit_body_electronics_module.py`: read-only baseline/count/APK audit.
- Три новых test files и точечные изменения текущих общекурсовых ожиданий.
- Два verification документа и шесть representative Flutter captures.

Весь `lib/`, 102 прежних урока и изображения, `pubspec.lock`, версия и Android
configuration сохранены. Аудит сравнивает **374 baseline файла** с `2e02a42`
(текст с нормализацией CRLF/LF, бинарные изображения побайтно), отдельно
проверяет старый prefix modules и ровно две asset-регистрации pubspec.
Новых типов блоков, симуляторов, backend/auth/AI или framework нет.

Исторические инструменты аудита R14 не переписаны под новый курс:
они по-прежнему описывают свой baseline. Для текущего курса используется R15 audit.
Незакоммиченные изменения R6 и остальные worktrees не меняются.

## Тесты и регрессии

Добавлено **20 тестов**, итог **852**:

- `test/services/module_12_content_test.dart`: **13**. Реальные typed JSON,
  metadata/IDs/order/counts/images, 102 прежних completions и неизвестный ID,
  15/80/all-answered, независимая арифметика всех C, мост по ключам/потенциалам,
  полярности K1/K2, K3 из actual SVG сопротивлений/узлов, интеграл P1 mean/RMS,
  park-связность/pull-up/запись тайм-аута, селектор K5, V1 и решаемость scope.
- `test/widgets/module_12_quiz_test.dart`: **4**. Все text/tasks light/dark
  на 360 px/scale 1,3; настоящая навигация в первый урок; настоящий mixed quiz:
  11/15 не проходит → retry расчёта → 12/15; изменение scope и unanswered retry
  снимают eligibility; до explicit completion нет записи, после — одна с прежними IDs.
- `test/widgets/module_12_diagrams_test.dart`: **3**. Decode всех 16 bundled PNG,
  размеры ×3, отсутствие source SVG в runtime, image/caption layout в обеих темах.

Точные общекурсовые counts/list/знаменатели обновлены до 12/112, ordinary=100,
quiz=12 и нового stage_11/15. Проверки прежнего поведения/содержания не удалялись
и не ослаблялись; прежний R14 prefix проверяется по его десяти урокам.
Старые oscilloscope, immutable diagnostic history и progress concurrency тесты
проходят в полном suite. Новые тесты не подменяют проверку реального оборудования.

Первый targeted run обнаружил старое название модуля в новом navigation test;
оно исправлено на настоящий заголовок модуля 12. Первые analyzer замечания
о скобках в новом test code исправлены. Production Dart для этого не менялся.

## Визуальная проверка

16 оригинальных схем просмотрены общим листом. Созданы **32 headless Flutter
renders** image/caption light/dark, ширина 360 logical px, text scale 1,3.
Исходные captions загружены с локальным Arial; шрифт не включён в репозиторий.
Проверки высоты/положения подписи и PNG decode проходят без overflow.

Ключевые рендеры H-моста, плохой массы, park, PWM и вентилятора просмотрены
визуально. Шесть сохранённых примеров:
[r15_module12](r15_module12/README.md). Полные 32 изображения находятся в ignored
`build/r15_module12_previews` и не генерируются обычным test run.
Для capture увеличен viewport по высоте; обычный layout проверяется 360×1050.

В процессе QA исправлены масштабирование raster (размеры теперь ×3), показ
независимых световых ветвей и выбор одной ветви селектора. Непрозрачный белый
фон PNG сохраняет контраст в обеих темах, условия повторены Flutter-текстом.
Статические числа внутри PNG не увеличиваются с системным шрифтом — ограничение.

## Фактическая верификация

| Команда | Результат |
| --- | --- |
| `dart format lib test` | Exit 0; 109 файлов; новые tests отформатированы, lib без изменений |
| `flutter pub get` | Exit 0; зависимости получены без upgrade; lock прежний |
| `flutter analyze` | Exit 0; **No issues found!**, итог 10,1 s |
| `flutter test --reporter expanded` | Exit 0; **852 / All tests passed!**, 113 s |
| Отдельный mixed quiz module 12 | Exit 0; 1 тест; 20 s |
| Diagram capture run / `SAVE_R15_MODULE_PREVIEWS=1` | Exit 0; 3 теста; 9 s; 32 PNG |
| `python tools/audit_body_electronics_module.py` | Exit 0; 12/112/1511/628, module 12: 172/71/16; 374 baseline файла прежние |
| `flutter build apk --debug` | Exit 0; **Built build/app/outputs/flutter-apk/app-debug.apk**, 401,9 s |
| `python tools/audit_body_electronics_module.py --apk build/app/outputs/flutter-apk/app-debug.apk` | Exit 0; все **245 referenced JSON/PNG byte-exact**, новые source SVG исключены; baseline/counts проверены |
| `git diff --check` | Exit 0; staged diff также проверяется перед каждым commit |
| `git status --short` | Итоговые SHA и clean status сообщаются владельцу |

Gradle сообщил предупреждение Java native access; успешность сборки определяется
фактическим exit code и APK, а не наличием/отсутствием предупреждения.
APK: `build/app/outputs/flutter-apk/app-debug.apk`, **195317985 bytes**.
SHA256: `077df8f24ea87ae8eb23ff516388dc965b581e53ec36d64d709fa7155223aa7f`.
Это локальный debug APK, не production-store signing; файл не добавлен в Git.
Попытка APK-аудита до завершения сборки получила FileNotFoundError; повтор
после появления готового APK завершился успешно, как указано в таблице.
После Flutter-команд четыре generated registrants macOS/Windows имели только
изменённое представление строк без текстового diff; возвращены к HEAD только
в изначально чистом R15 worktree. Пользовательские изменения не откатывались.
Физическая Android проверка, TalkBack, release build и публикация не выполняются.

## Ограничения и STOP

Учебные схемы не универсальны для всех машин, а измерения синтетические.
Данные Q-кейсов предоставлены заранее, обязательный порядок измерений кодом
не обеспечивается. Нет свободного H-моста, временного motor solver или
нового park-симулятора. V1 моделирует только плюсовую потерю с идеальной массой;
SCOPE1 только существующую логическую форму 0/5 V, не силовой моторный выход.

Сохранение реальных completions проверено fake storage/SharedPreferences tests,
не ручным проходом на устройстве. Ответы/баллы/история попыток не сохраняются
после выхода; unlocking и миграция прогресса не добавлены.
SRS/HV/хладагент и обход защит не являются практикой.
Саморевью не является независимой экспертизой; physical Android QA и TalkBack
остаются непроверенными. Push/merge/tag/GitHub Release запрещены и не выполняются.
Локальные коммиты: `fedd3ac` — контент/иллюстрации/интеграция;
`dac5db5` — тесты/текущие ожидания/audit. Документация фиксируется третьим
локальным docs commit; его SHA сообщается в финальном отчёте.

**После R15 — STOP. Следующий модуль не начинается.**
