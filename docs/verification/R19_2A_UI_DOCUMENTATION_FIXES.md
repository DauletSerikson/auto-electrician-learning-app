# R19.2A — Исправление Home и документации

Дата: 2 ноября 2026, Asia/Qyzylorda.

## Baseline и изоляция

Перед изменениями выполнены `git worktree list --porcelain`, status/branch/HEAD
корневой папки `electrician` и `electrician-r18`. R18 чистый, HEAD
`3856e4d448e5eca4e2f37ac167c239b6ee4fbf41`, ветка `feature/diagnostic-practice`.
Изучены Home, Course/Module navigation, HomeProgress, course progress aggregation,
CourseService, PracticeService, реальные индексы, app smoke и progress loading tests.
Установлены 14 модулей / 132 урока / 18 кейсов; исходный R18 содержит весь baseline.

Командой `git worktree add -b fix/r19-release-readiness ../electrician-r19 3856e4d`
создан новый чистый worktree:
`F:/projects/FlutterApps/new_app/AutoElectro/electrician-r19`.
Все изменения R19.2A выполнялись только здесь. Остальные worktree не изменялись.

## Первопричина и воспроизведение P2

В исходном `HomeScreen` строка «Общий прогресс» и процент были двумя обычными
Text внутри Row. Row измерял оба текста без гибкого ограничения ширины;
`spaceBetween` не мог вместить их при крупном шрифте. На viewport 360×800,
text scale ×2 и настоящем Roboto возникал `RenderFlex overflowed by 14 pixels
on the right` (исходный `home_screen.dart:138`).

До изменения production-кода добавлен widget regression и выполнен:

```text
flutter test --no-pub test/widgets/home_screen_test.dart --plain-name "Home width=360.0 scale=2.0 dark=false scroll and routes" --reporter expanded
```

Результат: **FAIL, 0 PASS / 1 FAIL**, ожидаемое отсутствие исключения нарушено
именно указанным overflow. Лог: `%TEMP%/r19-2a-before.log`.
Первая техническая попытка загрузить SDK font через Isolate.resolvePackageUri
не поддерживалась flutter_tester; helper исправлен на чтение package_config.
Это ошибка setup теста, не дефект приложения. После исправления setup получен
описанный red regression до изменения Home.

## Минимальное исправление

Заголовок прогресса обёрнут в `Expanded`, между ним и процентом оставлен
промежуток 12 px. Заголовок переносится в доступной ширине; процент виден
полностью. Нет принудительного уменьшения TextScaler, ellipsis, maxLines,
фиксированной высоты или удаления важного текста. Состав и оформление Home
сохранены; отдельный redesign не выполнялся.

## Актуализация Home

- Карточка «Курс» показывает число учебных модулей и уроков. Количество модулей
  получено как число различных module ID в уже загруженном полном списке уроков,
  количество уроков — из существующего HomeProgress. Для текущих assets это **14 / 132**.
- Карточка «Практика диагноста» показывает **18 диагностических кейсов**.
  Число загружается через существующий PracticeService из реального каталога
  один раз за жизнь Home; FutureBuilder показывает его после загрузки.
  До результата/при ошибке остаётся нейтральная подпись «Проверки и доказательства»,
  без выдуманного количества. Открытие каталога и его обработка ошибок сохранены.
- Практикум остаётся отдельной route и не включён в число учебных модулей.
  На Home нет дублирующих констант 14/132/18.
- Порядок курса, ID, completion, quiz HOTFIX, scoring, persistence и engine
  не менялись. Новый показ количества кейсов не читает/не пишет practice results.

## README

README отражает 14 реальных модулей, 132 урока и отдельный практикум из 18 кейсов.
Добавлены описание осциллографа и различие session draft урока/практикума и
сохраняемого practice summary. Сохранены команды запуска/форматирования/анализа/
тестирования/debug и release build, Android как основной клиент и offline-first.

Статус остаётся **NOT READY**, публикация не заявлена. Явно указаны незакрытые
physical QA текущего baseline, TalkBack, независимая профильная экспертиза,
debug signing release-mode APK и ограничения других платформ. Существующие
скриншоты и release notes обозначены как исторические материалы R6; их числа
не выдаются за текущий курс. Удалённый CI для этой ветки не заявлен проверенным.

## Регрессионные тесты

Добавлен `test/widgets/home_screen_test.dart`: **20 новых widget tests**.
Roboto regular/medium/bold берутся из активного Flutter SDK через package_config,
без абсолютного локального пути, новой зависимости или копирования font assets
в приложение. Тестовый Ahem не используется как источник Android font metrics.

| Viewport | Масштабы | Темы | Сценарии | Результат отдельного запуска |
|---|---|---|---|---|
| 320×800 | ×1 / ×1.3 / ×1.5 / ×2 | light и dark | Home, course counts, scroll всех 14 module cards, включая длинные заголовки, Module navigation/Back, карточка практикума, каталог и открытие dp01 | 8 PASS |
| 360×800 | ×1 / ×1.3 / ×1.5 / ×2 | light и dark | те же проверки, отсутствие исключений на каждом settle | 8 PASS |
| 320×800 | ×2 | light и dark | длинное название модуля проводки в «Продолжить обучение», переход в реальный урок | 2 PASS |
| 320×800 | ×2 | light и dark | прогресс 100%, сообщение завершённого курса, отсутствие «Продолжить обучение» | 2 PASS |

Основные разделы достигаются вертикальной прокруткой и нажимаются через реальные
widget controls; карточки не обязаны одновременно помещаться в viewport.
Прогресс подставлен только в изолированный PreferencesPlatformFake; все 20 тестов
дополнительно проверяют **0 storage writes** при просмотре/навигации.
До исправления основной regression падал; после исправления отдельный запуск
нового файла — **20 PASS**. Существующие 1422 теста не редактировались и не ослаблялись.

## Автоматические проверки

| Команда / проверка | Фактический результат |
|---|---|
| `dart format lib test` | PASS, 141 файл; последний запуск — 0 изменений |
| `flutter pub get` | PASS, Got dependencies; pubspec/lockfile не изменены |
| `flutter analyze` и окончательный `flutter analyze --no-pub` | PASS, No issues found!; последний запуск 3.3 s |
| `flutter test --reporter expanded`; повтор для окончательного кода с `--no-pub` | оба PASS, **1442 теста**; окончательный запуск 2:24 |
| `flutter test --no-pub test/widgets/home_screen_test.dart --reporter expanded` | 20 PASS отдельным запуском; затем все 20 прошли в полном suite |
| `flutter build apk --debug` | PASS; окончательная сборка assembleDebug 13.5 s |
| `git diff --check` | PASS |
| `git status --short` перед локальным commit | только 4 файла задачи; итоговый status проверен после commit |
| `aapt dump badging` | applicationId/label сохранены, versionName=0.1.0, versionCode=1, minSdk=24, targetSdk=36 |
| `apksigner verify --print-certs` | PASS, Android Debug certificate, не production-store signing |
| ZIP CRC, kernel и JSON audit | PASS, см. ниже |

Итог: **1422 прежних + 20 новых = 1442 PASS**. Первый запуск analyzer нашёл
лишний `dart:typed_data` import в новом тесте; import удалён без отключения lint,
повторные запуски чистые. После уточнения lazy-загрузки счётчика практикума
повторены analyzer, полный suite и APK build на окончательном production-коде.
До появления subtitle его Future не запускается; FutureBuilder получает
результат/ошибку загрузки сразу с момента запуска.

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, **224871013 байт**.
SHA-256: `20a75f58ac88a3a57794ae88be2b575cc8ca20c5d89f4cf938f2fdc23539af4e`.
В `assets/flutter_assets/kernel_blob.bin` присутствует **точный исходный файл
текущего HomeScreen побайтово**, включая адаптивную строку и динамические
подписи курса/практикума. Все **166 course/practice JSON** внутри APK совпадают
с worktree побайтово; индексы внутри APK дают 14 модулей, 132 урока, 18 кейсов.
CRC проверка ZIP успешна. Это проверка содержимого сборки, не device smoke.

Flutter commands меняли только line endings четырёх generated registrants
macOS/Windows. После проверки побайтового равенства HEAD с нормализацией CRLF/LF
восстановлено исходное working-tree представление через Git filters, без
reset/checkout и без изменения содержимого. Эти файлы не входят в итоговый diff.
`git diff --quiet 3856e4d -- assets lib/models lib/domain lib/practice lib/services
lib/simulation lib/screens/lesson_screen.dart lib/widgets android pubspec.yaml
pubspec.lock` вернул 0. Ни один существующий тестовый файл не изменён.

Подробные локальные логи: `%TEMP%/r19-2a-before.log`, `r19-2a-home-final.log`,
`r19-2a-format-final.log`, `r19-2a-pub-get-final.log`, `r19-2a-analyze-final.log`,
`r19-2a-test-final.log`, `r19-2a-build-debug-final.log`. Временные логи и APK
не добавляются в Git. Изменения сохраняются одним локальным commit; SHA и
окончательный Git status приведены в итоговом сообщении.

## Отчёт R19.1 и документы в других worktree

Фактический отчёт R19.1 расположен по пути
`F:/projects/FlutterApps/new_app/AutoElectro/electrician/docs/verification/R19_TECHNICAL_AUDIT.md`.
Он остаётся **untracked** в корневом worktree `electrician`, ветка
`release/r6-readiness`, HEAD `ca1262e`. Он не входит в исходный `3856e4d` и
не копируется/не коммитится в R19.2A. Итог R19.1 — NOT READY.

Там же до начала задачи были **шесть modified документов**:

1. `README.md`.
2. `docs/releases/v0.1.0.md`.
3. `docs/roadmap/R6_PLAN.txt`.
4. `docs/verification/R6_6.md`.
5. `docs/verification/R6_6_DEVICE_CHECKLIST.md`.
6. `docs/verification/R6_7.md`.

Их исходный diff (71 insertions / 10 deletions) не перезаписывался.
Изменение README в R19.2A относится только к новому worktree и основано на R18.

Дополнительно сохранены без изменения:

- `electrician-quiz-hotfix`: modified
  `docs/verification/QUIZ_ANSWER_PERSISTENCE_HOTFIX.md`, untracked
  `docs/verification/evidence/` — исторические physical QA materials.
- `electrician-r11`: untracked `docs/verification/ANDROID_DEVICE_QA_R11.md`
  и `docs/verification/android_device_qa_r11/` — QA старого baseline.
- `electrician-r18`: чистый исходный baseline `3856e4d`.

Эти материалы не переносятся в ветку исправления. Их будущая консолидация —
отдельное согласованное действие с сохранением привязки к проверенному HEAD.

## Android QA, ограничения и scope

`adb devices -l` вернул пустой список. **Физическая Android QA R19.2A и TalkBack:
NOT TESTED.** Не выполнялись установка APK, очистка данных, uninstall, изменение
пользовательских preferences или проверка native cold restart. Widget navigation
и сборка не заменяют проверку телефона, крупного текста/insets/touch и safe upgrade.
Независимое электротехническое ревью не проводилось.

Изменения задачи: Home, README, один новый тестовый файл и этот отчёт.
Учебные JSON/изображения, зависимости/lockfile, Android configuration,
applicationId, версия 0.1.0+1 и все domain/persistence правила остаются прежними.

**STOP после R19.2A. R19.2B не начат; push, merge, rebase, tag и Release не выполнялись.**
