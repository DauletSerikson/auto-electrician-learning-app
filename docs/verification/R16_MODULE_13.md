# R16.2–R16.4 — Модуль 13: реализация и проверка

25 октября 2026, Asia/Qyzylorda. Worktree `electrician-r16`, ветка
`feature/module-13-vehicle-safety-systems`. Утверждённый baseline `189da12`
([план R16.1](../roadmap/R16_MODULE_13_PLAN.md)); родитель реализации R15 — `4f2fc8b`.
Завершение ограничено R16, без push/merge/tag/Release и перехода к модулю 14.

## Результат

| Объём | До | После | Добавлено |
| --- | ---: | ---: | ---: |
| Модули | 12 | 13 | 1 |
| Уроки | 112 | 122 | 10 |
| Блоки | 1511 | 1667 | 156 |
| Оцениваемые задания | 628 | 696 | 68 |
| Проходящие тесты | 852 | 876 | 24 |

Добавлены 17 оригинальных SVG и 17 runtime PNG ×3, исходники/каталог/описание
происхождения, пять диагностических карт, смешанный практикум 15/80.
В обычных уроках нужны все правильные ответы. Практикум: 11/15 недостаточно,
12/15 достаточно только после ответа на все задания и явного завершения.

| ID safety_systems_ | Урок | Блоки | Задания |
| --- | --- | ---: | ---: |
| 01 | Активная и пассивная безопасность автомобиля | 10 | 4 |
| 02 | Архитектура ABS и гидравлического управления | 11 | 4 |
| 03 | Датчики скорости вращения колёс | 17 | 7 |
| 04 | Диагностика ABS | 14 | 5 |
| 05 | ESC/ESP и электронная стабилизация | 9 | 4 |
| 06 | Датчики ESC | 13 | 5 |
| 07 | Архитектура SRS | 10 | 4 |
| 08 | Безопасная диагностика SRS | 13 | 5 |
| 09 | Комплексные диагностические кейсы | 33 | 15 |
| 10 | Итоговый практикум | 26 | 15 |

Изучены CourseService/ProgressService, typed LessonBlock/renderer,
lesson attempt/completion, модели sine/scope/evaluator, предыдущий модуль,
контентные, progress, simulator и widget tests. Использованы существующие
типы text/image/question/calculation/warning/remember/oscilloscope.
Новые симуляторы, типы, production Dart, storage и scoring не потребовались.

Поведение изменено добавлением stage_12 в конец курса: общий знаменатель
прогресса теперь 122. ID/порядок/данные прежних 112 уроков сохранены.
Тест сохраняет все 112 completed IDs и неизвестный ID, затем явно добавляет
новое завершение; миграции SharedPreferences нет. Backend/AI/облачных функций нет.

## Изменённые файлы и воспроизводимость

- `assets/course/modules.json`: одна новая запись, старый prefix сохранён.
- `assets/course/stage_12/`: индекс и десять JSON-уроков.
- `assets/images/safety_systems/`: PNG, `source/*.svg`, каталог размеров и README.
- `pubspec.yaml`: только две asset-директории; версия `0.1.0+1` прежняя.
- `tools/build_safety_systems_course.py`: детерминированное создание только stage_12.
- `tools/render_safety_systems_assets.py`: собственная геометрия с существующими
  графическими helpers R15; выходной каталог переопределён на safety_systems.
- `tools/audit_safety_systems_module.py`: read-only аудит baseline, counts и APK.
- `test/services/module_13_content_test.dart`,
  `test/widgets/module_13_diagrams_test.dart`,
  `test/widgets/module_13_quiz_test.dart`: 24 новых проверки.
- 19 существующих test files: только актуальные общекурсовые expectations,
  prefix-срез R15 и metadata нового quiz. Проверки прежних моделей/заданий
  не удалены и не ослаблены. Исторические генераторы/аудиты/отчёты не переписаны.
- Этот отчёт и [техническое/safety review](R16_MODULE_13_SAFETY_REVIEW.md).

Генерация контента: `python tools/build_safety_systems_course.py`.
Рендер в этой среде использовал прежний изолированный dev-инструмент resvg-py:

```powershell
$env:PYTHONPATH = 'F:/projects/FlutterApps/new_app/AutoElectro/electrician-r10/build/asset-tools'
python tools/render_safety_systems_assets.py
```

Arial использован локально для PNG; файл шрифта не распространяется.
Это dev tooling, новая Flutter dependency не добавлялась.
Каталог содержит только размеры, ответы не зашиты в графический metadata-файл.

## Тестирование

Новые проверки охватывают typed parsing и все metadata, 122 уникальных ID,
регистрацию/наличие изображений, сохранение старого прогресса, обычное завершение,
точный порог quiz и требование всех ответов. UI-тест открывает настоящий модуль,
выполняет реальный mixed quiz (11 questions, 3 calculations, 1 scope), retry
расчёта/вопроса, изменение/сброс scope, отсутствие записи до explicit completion
и ровно одну запись с сохранением прежних IDs после завершения.

Физические тесты читают реальные SVG: 48 зубьев и 96 чередующихся полюсов,
узлы активной петли, точки синусоид и импульсов, независимые f/T/U/I/duty/mean,
геометрию четырёх скоростей на повороте, H1-клапаны, K1 validity/timeline,
масштаб K2, единицы и согласованность K3, баланс потенциалов K4.
SRS-тесты проверяют допустимые типы и правильные безопасные решения K5/quiz.
Подробности применимости и ручного review — в отдельном safety-отчёте.

Первый общий прогон выявил пять отказов: одно оставшееся старое ожидание числа
модулей, две неточности новых assertions и переполнение длинной единицы в двух
темах. Исправлены expectations, floating-point comparison и подпись единицы.
Содержание не подгонялось под неправильный ответ; production widget не менялся.
Первый analyzer выявил один lint braces в новом тесте, исправлен без подавления.

| Команда | Фактический результат |
| --- | --- |
| `dart format lib test` | Exit 0; финальный повтор: 112 файлов, 0 изменений |
| `flutter pub get` | Exit 0; без upgrade, lock неизменён |
| `flutter analyze` | Exit 0; **No issues found!** |
| `flutter test --reporter expanded` | Exit 0; **876 / All tests passed!**, 92 s |
| Три новых test files с захватом PNG | Exit 0; 22 теста до добавления двух дополнительных K1/SRS assertions, 19 s; оба дополнительных затем прошли в общем suite |
| `python tools/audit_safety_systems_module.py` | Exit 0; **13/122/1667/696**, модуль 13 **156/68/17**, **419 baseline файлов неизменны**, prefix и asset-only pubspec verified |
| `flutter build apk --debug` | Exit 0; assembleDebug 78,9 s, APK создан |
| `python tools/audit_safety_systems_module.py --apk build/app/outputs/flutter-apk/app-debug.apk` | Exit 0; **273 referenced JSON/PNG byte-exact**, новые SVG sources исключены из runtime |
| `git diff --check` | Exit 0; повтор перед staging/commit |

Список доступных обновлений от `pub get` не применялся. После Flutter-команд
четыре generated registrants macOS/Windows имели только представление строк
без текстового diff; возвращены к HEAD исключительно в изначально чистом R16.
Worktree R6/R15 и их Android QA не изменялись.

Финальный повтор `flutter analyze`: **No issues found!**, 3,3 s. Java/Gradle
предупредили о restricted native access; сборка при этом завершилась с exit 0.
Версии toolchain и параметры JVM для подавления предупреждения не менялись.
Повторная генерация дала побайтово одинаковые **47 авторских файлов**
stage_12 и safety_systems; пересборка после неё не требуется.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **201 526 475 bytes**
(≈192,2 MiB), debug universal APK. SHA-256:

```text
7B55FBA66751F1C80909BC109A6D4E572C7F0AA8FD7AA6EBBDD08C119D54EC52
```

APK находится в игнорируемом build/, в Git не добавлен. Размер debug APK
не является оценкой размера release. Подписание для магазина не проверялось.

## Визуальная проверка и ограничения

Все image/caption проходят на 360 logical px, light/dark, text scale ×1,3;
все остальные блоки десяти уроков также проверены в обеих темах без overflow.
Сохранены 34 полных Flutter-рендера с локальным Arial в игнорируемом
`build/r16_module13_previews/`, просмотрены все 17 исходных рисунков и
представительные пары light/dark для A1, графиков, Live Data, K4 и SRS.
Важные условия продублированы масштабируемыми Flutter-подписями.

Повторить захват:

```powershell
$env:SAVE_R16_MODULE_PREVIEWS = '1'
$env:R16_MODULE_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/module_13_diagrams_test.dart --reporter expanded
```

Физическое Android QA и TalkBack не выполнялись. Widget tests и debug build
не подтверждают поведение реального устройства, доступность и удобство длинного
урока. Release build/signing/публикация не входят в эту реализацию.
Техническое саморевью не заменяет независимого профильного эксперта.

## Локальные commits и финальная проверка

1. `5efa1ad` — `feat: add module 13 vehicle safety lessons and diagrams`
   (51 файл: контент/графика/регистрация/генераторы).
2. `43a5d6c` — `test: verify module 13 physics safety progress and quiz flow`
   (23 файла: 19 обновлённых tests, 3 новых test files, read-only audit).
3. `docs: record module 13 verification and safety review` — два отчёта;
   SHA сообщается владельцу отдельно, чтобы не создавать самоссылку.

Перед итоговым docs commit изменены только эти два новых отчёта, staged diff
проходит `git diff --cached --check`. После commit повторяются `git status --short`,
`git diff 189da12..HEAD --check` и аудит APK. Итоговый статус сообщается владельцу.
Локальные commits разрешены заданием; сетевых Git-операций не выполнялось.
