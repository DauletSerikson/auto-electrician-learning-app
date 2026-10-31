# R18.3 — Стабилизация диагностического практикума

Дата: 31 октября 2026, Asia/Qyzylorda.
Worktree `electrician-r18`, ветка `feature/diagnostic-practice`.
Baseline R18.2: `517ce03`.

## Scope и сохранность baseline

Добавлены изолированное сохранение итогов, статусы каталога и целевые
регрессионные проверки. В каталоге прежние три кейса dp01/dp13/dp05.
Новые кейсы, зависимости, аккаунты, achievements, синхронизация и backend
не добавлялись. Pure Dart engine/evaluator, веса 25/30/25/15/5, обязательные
доказательства, critical interpretations, safety gate и порог 80 не менялись.
132 урока, course assets, quiz HOTFIX, симуляторы и ProgressService не менялись.

## Схема хранения

`PracticeResultRepository` — отдельная тестируемая граница. Реализация
`PreferencesPracticeResultRepository` использует имеющийся shared_preferences.
Каждый сценарий имеет свой ключ `diagnostic_practice.result.<scenarioId>`.
Допустимы ID вида dp01. Версия находится внутри JSON, чтобы новая несовместимая
версия не маскировалась как отсутствие старого результата.

| Поле JSON | Тип | Смысл |
|---|---|---|
| schemaVersion | int = 1 | Версия формата summary |
| scenarioId | String | Идентификатор кейса; сверяется с ключом |
| passed | bool | Был хотя бы один подтверждённый evaluator PASS |
| bestScore | double, 0…100 | Максимальный исходный балл, без округления |
| completedAttempts | positive int | Число отправленных итоговых попыток |
| lastCompletedAt | ISO-8601 UTC String | Время последнего submit, а не storage retry |
| lastSubmissionId | String | Служебная квитанция последнего submit |

Сохраняется summary, не PracticeAttempt: нет журнала, профилей, ответов,
гипотез, ссылок на измерения, персональных данных или незавершённых черновиков.
Lesson progress не мигрируется: `completed_lessons` не читается и не пишется
практикумом; repository не вызывает `clear`/`remove`.

## Политика обновления и фиксация завершения

Завершение — переход session из editable в submitted после общей кнопки
оценки. Каждое заключение, включая FAIL и needsMoreEvidence, считается
завершённой попыткой. Неотправленный черновик, rebuild, просмотр результата,
прокрутка и открытие сценария ничего не сохраняют и не увеличивают счётчик.

`passed = old.passed || evaluation.passed`; `bestScore = max(old, current)`;
счётчик +1; время берётся в момент submit и сохраняется при storage retry.
Лучший численный балл и успешное прохождение независимы: высокий FAIL не
превращается в PASS, а более низкий балл позднейшего PASS не уменьшает best.
Повторный FAIL после PASS не снимает завершение.

Controller присваивает route/attempt submission ID и инициирует запись только
при submit. Повтор записи последнего ID возвращает прежний summary без +1.
Все repository instances в isolate используют общую очередь всего цикла
read/modify/write; очередь продолжает работу после ошибки. Гарантия retry
рассчитана на текущий route flow, где нельзя начать новый retry до подтверждения
записи. Это не распределённый журнал произвольного replay старых submissions.

После успешного submit engine остаётся frozen. Пока запись выполняется или
завершилась ошибкой, общий retry запрещён. Есть отдельная кнопка повторной
записи. UI сообщает об успехе только после подтверждённого setter.
При чтении вызывается reload: optimistic plugin cache после failed setter
не выдаётся за сохранённый прогресс. Уничтоженный controller не уведомляет UI.
Каталог после возврата ждёт текущую запись и перечитывает summary.

## Повреждения и ошибки

Отсутствующий ключ — нормальное состояние «Не пройден», best — прочерк.
Неверные типы, JSON, версия, ID, поля, число попыток, score или UTC date
вызывают явную ошибку чтения. Повреждённая запись не стирается и не заменяется
новой; остальные кейсы продолжают читаться/сохраняться отдельно. Каталог
показывает ошибку конкретного кейса и предлагает повторное чтение, не ложное
нулевое состояние. Ошибка сохранения доступна для явного повторения.

Автоматического сброса/восстановления повреждённого summary нет: это потребовало
бы отдельного решения о сохранении исходных данных. Пользователь может выйти
после предупреждения о неподтверждённой записи; аварийное завершение процесса
до записи может потерять только этот результат. SharedPreferences не даёт
гарантий транзакционной БД или fsync при аварии питания.

## Целевой аудит состояния и scoring

| Проверка | Результат |
|---|---|
| Гипотезы и citations после прокрутки | Route-owned PracticeAttempt сохранён; отдельный widget test с 45 записями и lazy scroll до конца/обратно, rebuild |
| Reset/retry | Новый ID, пустые журнал, hypotheses, responses, purposes; сохранённый summary остаётся |
| Повтор одной проверки | 50 повторений каждого пилота не увеличивают score/proof; действуют прежние правила unique action |
| Угадывание / правильный ответ | Без записей E=0 и I=0, PASS невозможен, включая все hypotheses confirmed |
| Альтернативные маршруты | Прежние tests R18.2 с независимыми proof routes сохранены |
| Evidence против выбора ответа | Интерпретация требует выполненных и процитированных records; один option/hypothesis label не заменяет evidence |
| Лишние безопасные проверки | Обоснованные дополнительные проверки не штрафуются: 100/PASS во всех пилотах |
| Необоснованные безопасные проверки | Влияют только на R весом 5, не отменяют доказательства; доказанный маршрут остаётся в диапазоне 95…100/PASS |
| Итог после rebuild | Три rebuild не создают дополнительные записи, score остаётся 100, число попыток =1 |
| Повтор после худшего результата | Число =2, best=100 и passed=true остаются |

Подтверждённых дефектов математической модели оценки не найдено; evaluator
и контент не изменены. Исправлены/закрыты риски интеграции persistence:
повторная запись из UI, read/modify/write race между repository instances,
ложный успех optimistic cache, замена невалидных данных, потеря frozen result
при слишком раннем retry и устаревший каталог после pending save.

## Тесты

Добавлено 38 тестов: 17 repository, 4 storage/controller failure, 12 scoring,
5 widget. Все прежние 987 тестов сохранены, общее число — 1025.

Новые файлы:
- `test/practice/practice_result_repository_test.dart`: отсутствующие данные,
  summary, лучшие/худшие повторы, независимый PASS, пересоздание repository и
  сброс plugin instance, idempotent receipt, конкурентные записи, изоляция
  сценариев/lesson progress, повреждения и строгая валидация полей.
- `test/practice/practice_result_storage_failure_test.dart`: реальная plugin
  boundary с отказами чтения/setter, продолжение очереди, freeze во время
  сохранения, явный storage retry и отсутствие повторного +1.
- `test/practice/practice_scoring_audit_test.dart`: по четырём целевым проверкам
  для каждого из трёх пилотов, без изменения evaluator.
- `test/widgets/practice_stabilization_test.dart`: каталог после возврата и
  пересоздания приложения, rebuild/retry/счётчик, ошибка записи и повтор,
  изоляция повреждённого результата, длинный журнал и hypotheses/citations.

Старый widget test session-only обновлён под явно запрошенное новое поведение:
повторное открытие по-прежнему даёт пустой draft, summary PASS теперь сохраняется.
Ни один прежний тест не удалён. Общий fake preferences расширен поддержкой
setString; прежнее поведение setStringList сохранено.

## Verification

| Команда | Фактический результат |
|---|---|
| `dart format lib test` | PASS, 135 файлов; отформатированы затронутые файлы |
| `flutter pub get` | PASS, dependencies и pubspec.lock без diff |
| `flutter analyze` | PASS — No issues found!, 2.6 s |
| `flutter test --reporter expanded` | PASS — 1025 tests, финальный прогон 1:49 |
| `flutter build apk --debug` | PASS — assembleDebug, 38.8 s |
| `git diff --check` | PASS |
| Защищённый baseline | Нет diff в assets/course, assets/practice, старых моделях/симуляторах, ProgressService, LessonScreen, pubspec/lock и Android configuration |

Первый полный прогон также завершился 1025 PASS. Финальный повтор включает
сброс plugin instance в тесте восстановления и кнопку повторного чтения
ошибочных результатов. Ни один сбой проверок не скрыт: промежуточные lint
и несовпадение ожидаемого типа platform exception в новых тестах исправлены.
Четыре generated registrants после Flutter commands имели лишь line-ending
изменения (git diff --quiet: 0); они восстановлены из HEAD и исключены из commits.

## Android QA

`flutter devices` выполнен: доступны Windows, Chrome и Edge; Android нет.
`adb devices -l` выполнен: список устройств пуст. Samsung S25 недоступен.

**NOT TESTED**: установка обновления на Samsung, запуск, физический smoke
практикума и persistence после перезапуска процесса. Приложение не удалялось,
данные/SharedPreferences не очищались, подпись установленного приложения
не проверялась без устройства. Unit/widget tests не заменяют physical QA.

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, **224790614 байта**.
SHA-256: `3d1933e37fba665e4126de04d1ee0cce062c86344dce3d12664daac95ff19401`.
Сборка включает все production changes R18.3; последующие commits фиксируют
проверенные файлы без изменения кода/данных APK. Это debug APK, не release.

## Ограничения перед расширением до 18 кейсов

Нужен физический Android smoke с обновлением без удаления данных, проверкой
старого course progress, PASS/best после kill/relaunch, retry, большими шрифтами
и TalkBack. При несовместимой подписи установка должна остановиться без uninstall.
Для несовместимых content/rubric revisions понадобится отдельно утверждённая
политика миграции best/PASS; текущий summary не пересчитывает историю.
Модели остаются конечными синтетическими сценариями, без solver, trace UI,
полного журнала/истории и resume. Повреждённые записи требуют отдельного
решения о восстановлении. Масштабирование rule types/новые кейсы — отдельная задача.

## Локальные commits и diff

- `7a36661` — `feat: persist isolated diagnostic practice result summaries`.
- `07a6d7f` — `feat: stabilize practice completion and saved catalog results`.
- Отдельный docs commit — этот отчёт; SHA указан в итоговом сообщении.

Итоговый scope: 11 файлов, из них 6 новых (repository, четыре тестовых файла
и отчёт), 5 изменённых (controller, два экрана, test fake, один прежний widget
test). Незакоммиченных пользовательских изменений в исходном worktree не было.
Итоговый `git status --short` проверяется после docs commit.

STOP после R18.3. Push, merge, tag и GitHub Release не выполнялись.
