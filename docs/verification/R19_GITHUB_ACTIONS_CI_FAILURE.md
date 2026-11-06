# R19.4 — GitHub Actions CI Failure Investigation

Дата: 6 ноября 2026, Asia/Qyzylorda.

## Итог

Оба сбоя вызваны **неверным регистром имён Roboto TTF в тестовых setUpAll**.
Тесты запрашивали roboto-regular.ttf, тогда как SDK archive содержит
Roboto-Regular.ttf. Windows допускает такое обращение, Linux filesystem — нет.
Такая же ошибка была в путях к Medium/Bold; они исправлены одновременно.

Изменены две строки в каждом из двух файлов тестов и добавлен этот отчёт.
Production-код, assertions, количество тестов, workflow, зависимости, course assets,
scoring, persistence и диагностический движок не изменены. Тесты не удалялись
и не пропускались. После исправления: **1467 PASS**, focused Home **40 PASS**.
Новый удалённый CI run не запускался: push запрещён текущим заданием.

## Git и получение полных логов

Начальный HEAD **2b93ac49d3e64a88ae769972bdc29b65647d667e**, ветка
fix/r19-release-readiness, worktree electrician-r19; status/diff чистые.
Это полный R19 baseline с локальными RC1 commits. CI проверял предыдущий
**65b7f9d40aa0414371c4d5ea20c16acc2282a191**. Между ним и исходным локальным HEAD
нет изменений lib/test/workflow; RC1 затрагивал только версию/README/отчёт.

GitHub CLI gh отсутствует. Список последних пяти runs получен через GitHub REST
API workflow runs, jobs и **полные job logs** — через подключённый GitHub connector.
Владелец не должен скачивать файлы вручную: логи успешно получены агентом.

| Run | Commit | Job validate | Результат Test |
|---|---|---|---|
| [42250183089](https://github.com/DauletSerikson/auto-electrician-learning-app/actions/runs/42250183089) | 65b7f9d | 128002884041 | 1427 PASS, 2 FAIL, exit 1 |
| [42220448113](https://github.com/DauletSerikson/auto-electrician-learning-app/actions/runs/42220448113) | 368ea07 | 127900871602 | 1427 PASS, 1 FAIL, exit 1 |

Основной исследуемый run начался 6 ноября около 21:12 Asia/Qyzylorda,
закончился около 21:16. В обоих runs checkout, Flutter setup, pub get и analyze
успешны, упал именно Test. Полные latest-job.log / previous-job.log сохранены
вне Git в `%TEMP%/electrician-r19-ci-2b93ac4-20261106/`.

API-эквиваленты получения доказательств: workflow runs endpoint,
`GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` и
`GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`.

## Точные два FAIL и полные выведенные stack traces

Это **два сбоя suite-level setUpAll**, а не две падающие проверки состояния UI.
Полные error/stack blocks из основного job приведены без timestamp prefix.

### test/widgets/home_accessibility_test.dart: (setUpAll)

```text
PathNotFoundException: Cannot open file, path = '/opt/hostedtoolcache/flutter/stable-3.47.5-x64/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf' (OS Error: No such file or directory, errno = 2)
dart:io                                          _File.readAsBytes
test/widgets/home_accessibility_test.dart 82:9   main.<fn>
===== asynchronous gap ===========================
dart:async                                       _CustomZone.registerUnaryCallback
test/widgets/home_accessibility_test.dart 72:31  main.<fn>
```

### test/widgets/home_screen_test.dart: (setUpAll)

```text
PathNotFoundException: Cannot open file, path = '/opt/hostedtoolcache/flutter/stable-3.47.5-x64/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf' (OS Error: No such file or directory, errno = 2)
dart:io                                   _File.readAsBytes
test/widgets/home_screen_test.dart 56:9   main.<fn>
===== asynchronous gap ===========================
dart:async                                _CustomZone.registerUnaryCallback
test/widgets/home_screen_test.dart 46:20  main.<fn>
```

В старом run 368ea07 тот же второй stack block; нового home_accessibility_test
там ещё не было. Никакие другие названия упавших widget cases не предполагаются.

## Доказательство первопричины

В обоих setUpAll SDK root вычислялся правильно: ошибка содержит ожидаемый
Flutter 3.47.5 cache path. Неправильным был basename и регистр weight.
В исходниках установленного SDK MaterialFonts загружает универсальный fonts.zip;
его путь прочитан из bin/internal/material_fonts.version.

Скачан [официальный архив шрифтов](https://storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/fonts.zip).
В его ZIP directory имена **Roboto-Regular.ttf, Roboto-Medium.ttf, Roboto-Bold.ttf**.
Сопоставление с локально используемыми файлами подтвердило одинаковые байты:

| Weight | SHA-256 |
|---|---|
| Regular | 79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95 |
| Medium | f205cc511821ea56078a105557fcea6253129404d411c997e1866fbd006abb68 |
| Bold | 7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86 |

Поэтому исправление не подменяет Roboto на Ahem/другую метрику и не ослабляет
layout-проверки. Корректные font files остаются теми же.

В Docker Ubuntu **26.04.1 LTS**, как в CI, fonts.zip распакован в собственный
Linux /tmp. Windows bind-mount использован только как read-only источник ZIP;
проверка выполнялась на case-sensitive filesystem контейнера, а не на Windows mount.
Для каждого из трёх старых имён воспроизведён FileNotFoundError/errno=2.
Каждое исправленное имя прочитано успешно, все три SHA-256 совпали с baseline.
Probe завершился exit 0. Это воспроизведение filesystem-причины, не полный
Linux Flutter widget suite. Исходные SDK cache/шрифты не переименовывались.

## Почему 1429 результатов вместо 1467

- home_screen_test.dart содержит 20 тестов: 16 комбинаций viewport/scale/theme
  и 4 progress-state cases.
- home_accessibility_test.dart содержит ещё 20: 16 комбинаций, 3 boundary states
  и 1 accessibility-action test.
- Оба глобальных setup падают **до запуска этих 40 test bodies**.
- Остальные 1467 − 40 = **1427** тестов проходят.
- Reporter добавляет **2 ошибки setup**: 1427 + 2 = **1429 результатов**.

Это не 38 удалённых тестов и не 40 явно выставленных skip. Тестовые тела
заблокированы неуспешной подготовкой suite. Старый run имел baseline 1447:
1447 − 20 = 1427 PASS и 1 setup failure, что независимо подтверждает расчёт.
Два новых локальных RC1 commits не меняли состав тестов.

## Версии, команды и прочие возможные факторы

| Параметр | Локально | Неуспешный CI |
|---|---|---|
| Flutter | 3.47.5 stable, framework 6a19cca564 | workflow/action input 3.47.5 stable; FLUTTER_ROOT содержит stable-3.47.5-x64 |
| Dart | 3.13.4, flutter --version и dart-sdk/version | отдельно --version в job не печатался; прямое измерение NOT VERIFIED |
| Engine revision | af7e796e16 | полный engine SHA в job log не напечатан |
| OS | Windows 11 | Ubuntu 26.04.1 LTS, image ubuntu-26.04, 20261101.186.1 |
| Test command | flutter test | flutter test |
| Reporter | обычный локальный | GitHub-aware reporter по окружению Actions |

Локально также выполнен тот же flutter test для двух файлов с process-local
GITHUB_ACTIONS=true и CI=true: **40 PASS**, GitHub reporter. Это Windows run
с CI flags, а не объявление Linux widget PASS.

Flutter уже одинаково закреплён на 3.47.5 в workflow и разработке; оснований
обновлять/менять SDK или добавлять другой pin для этого бага нет. Ожидаемая
версия Dart соответствует SDK, но её точный CI stdout не был записан — не выдаётся
за отдельно проверенный факт. При последующем CI run полезно явно вывести
flutter --version; данный фикс не расширяет workflow ради диагностики.

В двух suite нет Platform/skip/@TestOn условий, меняющих число cases.
dart:io используется для конфигурации SDK и чтения TTF. Ошибка возникает до
построения Home, установки per-test fake preferences, semantics assertions,
навигации и обработки пользовательских ответов. Locale/TZ/timing/order не нужны
для её воспроизведения. Не найдено доказательств, что они вызвали эти два FAIL.
app_accessibility_test.dart с ru/kk/en locale cases не входил в список FAIL.

## Минимальный фикс

В обоих файлах:

```dart
for (final weight in ['Regular', 'Medium', 'Bold']) {
  final bytes = await File(
    '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
  ).readAsBytes();
  // Existing FontLoader setup and assertions are retained.
}
```

Изменено четыре строки суммарно. Нет fallback, игнорирования отсутствующего
шрифта, skip, дополнительных fonts/dependencies, изменений SDK cache или CI image.
Все прежние проверки узких экранов, масштаба, тем, процента, индексов, module title,
количества уроков, действий и отсутствия storage writes сохранены.

## Node.js и Ubuntu warnings

Job log сообщает: actions/checkout@v4 target Node.js 20, но runner принудительно
исполняет action на Node.js 24. Checkout завершился success; warning выведен
после Test failure при cleanup. Причиной FAIL он не объявлен: stack указывает
на синхронную filesystem-проблему Dart при чтении конкретного font file.
Обновление Actions major versions не включено в этот минимальный фикс.

ubuntu-latest фактически выбрал Ubuntu 26.04.1. Само уведомление о миграции image
не является stack trace ошибки теста. На таком же дистрибутиве воспроизведён
конкретный case-sensitive lookup. Переключение на другой Linux image не является
исправлением неверного имени. runs-on оставлен без изменения.

## Проверки и ограничения

| Команда / проверка | Фактический результат |
|---|---|
| flutter --version | Flutter 3.47.5 / Dart 3.13.4 |
| dart format --output=none --set-exit-if-changed lib test | 143 файла, 0 изменений, exit 0 |
| flutter pub get | успешно, lockfile без изменений |
| flutter analyze | No issues found! |
| flutter test | 1467 PASS / All tests passed!, exit 0 |
| CI flags + flutter test для обоих исправленных файлов | 40 PASS, exit 0 |
| Ubuntu 26.04.1 case-sensitive font probe | старые пути errno=2; новые 3/3 PASS |
| flutter build apk --debug | успешно, assembleDebug 85.4 s |
| git diff --check | exit 0 |

Попытка получить Linux Flutter SDK 3.47.5 и releases_linux.json по официальным
storage URLs вернула HTTP 404. Поэтому полный Flutter suite на Linux с этим
SDK локально **NOT VERIFIED**. В контейнере проверена filesystem-причина,
полный Flutter suite и focused GitHub reporter run выполнены на Windows.
Успех нового настоящего GitHub Actions run **NOT VERIFIED / NOT RE-RUN**;
отправка и проверка CI остаются отдельным шагом согласно заданию.

Docker Desktop был запущен для изолированного probe; после окончания контейнера
проверено отсутствие работающих контейнеров и Desktop остановлен, как до задачи.
Новые container/image cache и diagnostic logs не входят в Git. Временные probes
не добавлены в штатный suite. Новых тестов нет: восстановлена возможность
запуска существующих 40 на case-sensitive filesystem без ослабления assertions.

Четыре generated registrants после Flutter commands получили только другие
line endings. Эквивалентность проверена, исходный формат восстановлен; в commit они не включены.
Чужие worktree/изменения не перезаписываются. Учебные JSON, lib, Android config,
version, dependencies и сохранение прогресса не меняются; установленное приложение
не обновляется.

После успешных локальных проверок создаётся отдельный локальный fix commit с
двумя файлами тестов и данным отчётом. SHA/status сообщаются владельцу отдельно.
Push, merge, rebase, force push, tag, Release и remote rerun не выполняются.

**STOP после локального исправления и проверки.**
