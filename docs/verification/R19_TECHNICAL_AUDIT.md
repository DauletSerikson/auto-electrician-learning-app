# R19.1 — Технический аудит и Release Readiness Assessment

Дата: **2 ноября 2026, Asia/Qyzylorda**.

## 1. Executive summary

**Рекомендация: NOT READY для выпуска текущего R18 без дополнительной приёмки.**
Аудит R19.1 выполнен; исправления и релизные операции не выполнялись.

Независимое чтение текущей реализации и повторный запуск проверок подтвердили
baseline: **14 модулей, 132 урока, 1819 блоков, 764 задания, 18 кейсов**.
Штатный suite: **1422 PASS**, analyzer: **No issues found!**, debug APK собран.
Подтверждённых P0/P1 в исследованном объёме не найдено. Найдены **один P2 и два P3**:
переполнение Home при увеличенном тексте; устаревшее число кейсов на Home;
устаревшее описание курса в README. Это не утверждение об отсутствии иных дефектов.

Основные незакрытые условия: физическая QA именно R18, обновление установленного
APK с сохранением данных, cold restart, TalkBack и независимая профильная проверка
содержания. Debug signing — известное ограничение portfolio/sideload, не готовая
подпись для магазина. Успех тестов и сборки эти условия не закрывает.

## 2. Фактический baseline и границы проверки

Цель аудита — worktree `electrician-r18`, ветка `feature/diagnostic-practice`,
HEAD **`3856e4d448e5eca4e2f37ac167c239b6ee4fbf41`**. Его tracked tree чист до и
после аудита. Предыдущий отчёт R18.5 использован как перечень утверждений для
проверки, а не как замена повторным проверкам.

Текущая рабочая папка чата — `electrician`, ветка `release/r6-readiness`,
HEAD **`ca1262ea127de14f61fea817fdfb424c50347369`**. Здесь уже были шесть
изменённых файлов документации. Они сохранены; новый отчёт находится здесь,
**он описывает R18, а не production tree текущей ветки R6**. Все указанные ниже
пути к исходникам и тестам, если не оговорено иначе, относятся к R18.

Чтобы не менять другие worktree, исполняемые проверки проведены на `git archive`
точного `3856e4d` во временной папке:
`%TEMP%/electrician-r19-audit-3856e4d/source`.
Это копия tracked baseline без пользовательских данных и ignored build artifacts.
Она не является новым Git worktree или release-веткой. Исходники приложения,
учебные материалы и зависимости в зарегистрированных worktree не менялись.

Окружение: Flutter **3.47.5**, Dart **3.13.4**, Windows; SDK Flutter `6a19cca564`,
engine `af7e796e16`. `flutter doctor -v`: No issues found! Android-устройств нет:
`adb devices -l` пуст, доступны Windows/Chrome/Edge.

## 3. Git/worktree audit

Проверены все **14 зарегистрированных worktree**, их HEAD и `git status --short`.

| Worktree | Ветка | HEAD | Состояние до аудита |
|---|---|---|---|
| electrician | release/r6-readiness | ca1262e | 6 modified docs |
| electrician-r7 | feature/module-4-vehicle-electrical-systems | e71e0ac | чисто |
| electrician-r8 | feature/module-5-wiring-diagrams | f6b30ea | чисто |
| electrician-r9 | feature/module-6-electrical-diagnostics | 196482a | чисто |
| electrician-r10 | feature/module-7-automotive-electronics | e5f8905 | чисто |
| electrician-r11 | feature/module-8-obd-diagnostics | e7e5d52 | untracked Android QA |
| electrician-r12 | feature/module-9-starting-charging-parasitic-draw | c9a91f2 | чисто |
| electrician-r13 | feature/module-10-wiring-repair | a12e337 | чисто |
| electrician-r14 | feature/module-11-automotive-oscilloscope | 1eca4fe | чисто |
| electrician-r15 | feature/module-12-body-electronics | 4f2fc8b | чисто |
| electrician-r16 | feature/module-13-vehicle-safety-systems | 3e831fb | чисто |
| electrician-r17 | feature/module-14-hybrid-electric-vehicles | 1aacdc9 | чисто |
| electrician-quiz-hotfix | fix/quiz-answer-persistence | 2388aac | modified QA report + untracked evidence |
| electrician-r18 | feature/diagnostic-practice | 3856e4d | чисто |

Для `main`, R6, всех R7–R17 и quiz HOTFIX команда
`git merge-base --is-ancestor <branch> 3856e4d` вернула **0**.
Следовательно, все перечисленные committed tips присутствуют в истории R18.
Загрузка assets и штатные тесты независимо подтверждают присутствие всех модулей,
осциллографа, исправлений quiz и 18 кейсов. Потери этих committed этапов не выявлено.

`main` = `f75cc63`, локальный `origin/main` указывает туда же.
`git rev-list --left-right --count main...feature/diagnostic-practice`: **0 / 110**.
Для `release/r6-readiness...feature/diagnostic-practice`: **0 / 69**.
Таким образом, R18 — потомок main/R6; отдельной расходящейся committed линии
с этими ветками сейчас нет. Remote refs прочитаны локально; fetch/push не выполнялись,
актуальное состояние сервера и remote CI R18 **NOT VERIFIED**.

Незакоммиченные материалы не наследуются:

- R6: `README.md`, `docs/releases/v0.1.0.md`, `docs/roadmap/R6_PLAN.txt`,
  `docs/verification/R6_6.md`, `R6_6_DEVICE_CHECKLIST.md`, `R6_7.md`.
  В diff — сведения о CI ca1262e, уточнение числа блоков старого baseline и
  незакрытый physical explicit completion; исходный diff **71 insertions / 10 deletions**.
- R11: `docs/verification/ANDROID_DEVICE_QA_R11.md` и `android_device_qa_r11/`.
  Отчёт описывает частичную QA 72 уроков и cold restart старого baseline;
  не подтверждает прохождение нового практикума.
- HOTFIX: `docs/verification/QUIZ_ANSWER_PERSISTENCE_HOTFIX.md` и `evidence/`.
  Прочитанный diff описывает физическую проверку `safety_05`, трёх циклов scroll,
  общей проверки/retry/explicit completion и сохранения пяти ранее завершённых ID.
  Это полезные исторические evidence, но не R18 QA и не первое сохранение нового ID.

Новые merge/rebase/cherry-pick/reset/stash/clean/tag, удаление worktree, переключение
веток и commits не выполнялись. Безопасная последовательность консолидации приведена
в разделе 14; сама консолидация не выполнялась.

## 4. Android configuration

| Параметр | Проверенное значение / источник |
|---|---|
| namespace / applicationId | `com.dauletserikson.autoelectrician`, app Gradle и собранный APK |
| Activity | `.MainActivity`, Kotlin package совпадает; launcher exported=true |
| Название | «Автоэлектрика с нуля», manifest и aapt |
| Версия | `0.1.0+1`; APK versionName=0.1.0, versionCode=1 |
| compileSdk / minSdk / targetSdk | **36 / 24 / 36**, FlutterExtension и APK |
| NDK | Flutter default `28.2.13676358` |
| Gradle / AGP / Kotlin plugin | **9.3.1 / 9.1.0 / 2.4.0** |
| JDK сборки / JVM target | Android Studio JBR **25.0.3** / Java и Kotlin **17** |
| Kotlin incremental | отключён существующим Windows workaround |
| Adaptive icon | API26 XML, foreground PNG и background color; legacy mipmaps присутствуют |
| Release signing | `signingConfigs.getByName("debug")`, явный TODO |

`git diff --name-only ca1262e..3856e4d -- android pubspec.lock .github` пуст:
эти настройки не менялись при добавлении R7–R18.

Main manifest не запрашивает INTERNET; оно добавлено debug/profile manifest.
В проверенном **debug** APK присутствуют INTERNET и сгенерированное AndroidX
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` с protectionLevel=signature.
`android:debuggable=true` относится к debug-варианту. Backend, авторизация и
дополнительные runtime permissions в исходной конфигурации не обнаружены.
Release merged manifest в этом проходе не строился: отсутствие в нём debug-полей
нельзя выдавать за фактическую APK-проверку.

**Debug APK:** assembleDebug успешен, 193.6 s, **209258543 байта** (около 199.6 MiB),
ABI arm64-v8a / armeabi-v7a / x86_64. SHA-256:
`5c475014ddcc60eafaec71e697c25f5cedee7701dacda19ed1d75591b23713be`.
Путь: `%TEMP%/electrician-r19-audit-3856e4d/source/build/app/outputs/flutter-apk/app-debug.apk`.
ZIP CRC исправен. `apksigner verify --print-certs` успешен: Android Debug,
SHA-256 сертификата `72fe40666599647f40d946340a2926e05fbdaaf66fbce789c7d802793f1fe295`.

Размер debug APK не является размером release APK. Release build как необязательная
диагностика не запускался; release-размер и поведение AOT **NOT VERIFIED в R19.1**.
JDK выдаёт warning restricted native access; debug-сборку он не остановил.
На устройстве не проверены insets, lifecycle и работа Android API 24/36/37.
Успех сборки не подтверждает совместимость со всеми этими устройствами.

## 5. Dependencies and licensing

`pubspec.yaml`: единственная внешняя production dependency —
`shared_preferences: ^2.5.5`; dev — `flutter_test` и `flutter_lints: ^6.0.0`.
Lockfile фиксирует shared_preferences **2.5.5**, Android **2.4.28**, foundation
**2.5.7**. Пакет используется обоими хранилищами. Неиспользуемых прямых внешних
зависимостей при просмотре imports не выявлено.

`flutter pub get` выполнен успешно. `pubspec.yaml` и `pubspec.lock` побайтово
совпадают с архивом baseline. Никаких upgrade не выполнялось.
`flutter pub outdated --json` успешен: для **9 установленных пакетов** показаны
более новые версии: material_color_utilities, meta, shared_preferences,
shared_preferences_android, shared_preferences_foundation, test_api, vector_math,
vm_service, web. Устаревшая версия сама по себе не доказывает уязвимость.

Внешняя проверка: отправлен запрос к
[OSV querybatch API](https://google.github.io/osv.dev/post-v1-querybatch/)
для **39 hosted Pub packages**, с точными именами/версиями из lockfile.
Получены 39 результатов, все пустые: известных записей в этой базе для этих
версий запрос не вернул. Это **ограниченная проверка**, не заключение
«уязвимостей нет». Flutter/Dart SDK, engine, JDK, Gradle/AGP, Maven dependencies,
GitHub Actions и полная supply chain на уязвимости **NOT VERIFIED**.

Ограниченный поиск high-confidence credential signatures в tracked archive
(PEM private key header, GitHub token, AWS access key ID) не дал находок.
По tracked filenames keystore/JKS/key.properties/PEM/.env не найдено.
Полная Git history и любые формы секретов этим не покрыты.

Проект имеет MIT LICENSE. Из 43 разрешённых внешних/SDK package roots 41 содержит
собственный `LICENSE*`; flutter_test/flutter_web_plugins поставляются внутри
Flutter SDK с корневой лицензией SDK. APK содержит `assets/flutter_assets/NOTICES.Z`.
Полная юридическая проверка notices и native Maven licenses не выполнялась.

Для иконки и аккумулятора README фиксирует заявленное владельцем происхождение
через OpenAI image generation, без гарантии исключительных прав. Для остальных
учебных схем есть SVG sources, скрипты экспорта и README о программном создании;
SVG не используется как runtime renderer. Наличие этих записей подтверждено;
внешняя проверка прав/лицензий всех исходников не заявляется.

## 6. Architecture review

Сохраняются конкретные, проверяемые границы:

- `models/lesson_block.dart`: sealed typed hierarchy, отдельные subtype и
  строгая parsing boundary. Неизвестные типы/отсутствующие обязательные поля
  вызывают ошибки; этому соответствуют model/content tests.
- `CourseService` загружает bundled JSON отдельно от прогресса. Модули/уроки
  сортируются по order; все реальные индексы проверены тестами.
- `LessonBlockRenderer` выбирает widget через subtype switch; диспетчеризация
  не перенесена в `LessonScreen`. Scored widgets используют keep-alive.
- `LessonScreen` хранит route-local answers/controllers, выполняет общий submit,
  блокирует редактирование после quiz submit, пересоздаёт попытку при retry,
  требует explicit completion и обрабатывает ошибку сохранения.
- `domain/lesson_attempt.dart` определяет scoring/completion; `course_progress.dart`
  считает прогресс по реальному каталогу. Неизвестные persisted IDs не увеличивают
  текущий прогресс. Возврат из урока обновляет Module/Home.
- `simulation/` содержит pure Dart расчёты. Diagnostic measurement snapshots
  не пересчитывают старую историю при переключении питания; regression tests сохранены.
- `practice/definition.dart`, `observation.dart`, `attempt.dart` отделяют definitions,
  immutable observations, evidence/evaluation от UI. `PracticeController` —
  route-scoped адаптер, repository сохраняет summary после submit.
- Осциллограф: `scope_signal.dart` и `oscilloscope_simulation.dart` рассчитывают
  capture/trigger, `ScopeDisplay` рисует данные, `OscilloscopeBlock` управляет UI.
  Это конечная синтетическая учебная модель, не автомобильный прибор.

Quiz HOTFIX проверен не только по истории: tests прокручивают реальные quiz
всех 14 модулей, проверяют drafts, rebuild/resize, общий submit/retry.
Practice acceptance содержит 36 полных UI-маршрутов для 18 кейсов, отрицательные
evidence routes находятся в domain tests. Архитектурного rewrite по результатам
аудита не требуется.

Ограничение обработки ошибок: callbacks открытия урока в Home/Module напрямую
await `loadLesson` без локального catch/retry. Все текущие bundled lessons валидны;
фактический отказ такого открытия на текущих assets не воспроизведён. Это
неподтверждённый риск при будущей порче/изменении bundle, а не найденный сбой курса.

## 7. Data persistence audit

| Данные | Ключ/формат | Наблюдаемое поведение |
|---|---|---|
| Lesson progress | `completed_lessons`, `List<String>`; native prefix `flutter.` | чтение reload; dedup через Set; read/modify/write сериализован между экземплярами в одном isolate |
| Practice results | `diagnostic_practice.result.dpNN`, JSON schemaVersion=1 | отдельный key на кейс, passed, bestScore, completedAttempts, UTC date, lastSubmissionId |
| Draft / journal | только текущая route/session | после выхода не восстанавливаются; UI предупреждает об этом |

От R6 к R18 `ProgressService` и Android applicationId не менялись; старые lesson
IDs сохранены. Изменение ключа/формата прогресса не обнаружено. Новые результаты
практикума не смешаны с completion уроков.

Оба сервиса делают reload перед чтением, проверяют результат setter и не выдают
optimistic cache за подтверждённое сохранение. Ошибка не ломает очередь следующих
записей. Lesson UI показывает retry сохранения и защищает pending completion.
Practice repository сериализует read/modify/write; best = max, passed сохраняется
через OR, count увеличивается на новую завершённую попытку. Повтор последнего
submissionId не увеличивает count. Это защита повтора последней операции,
не бессрочный журнал идемпотентности всех submission IDs.

Practice parsing проверяет типы, schemaVersion, scenarioId, score 0–100,
положительный count, UTC date, непустой receipt. Повреждённая/несовместимая запись
не сбрасывается автоматически; read/complete сообщают ошибку, другие кейсы и уроки
сохраняются. Для corrupt lesson key чтение ошибочно; UI допускает повтор, очистки
хранилища в обработке ошибки нет. Механизм ручного восстановления corrupt storage
не реализован; реального повреждения пользовательских данных не наблюдалось.

Unit/widget tests проверяют ошибки reload/setter, concurrent writes, retry,
best/PASS/count/date, пересоздание service/plugin и независимость ключей.
Это не native disk/power-loss тест. Сам пакет
[shared_preferences](https://pub.dev/packages/shared_preferences)
оговаривает ограниченную гарантию долговечности записи; текущий await/reload
не даёт оснований обещать сохранность при любом аварийном завершении.

Обновление APK **не требует удаления данных по реализации**, но фактический
R18 upgrade на устройство не выполнялся. Требуется тот же applicationId и
совместимый сертификат. Сертификат нового APK проверен, сертификат установленного
приложения сейчас неизвестен. При несовпадении остановить установку, не применять
uninstall/clear data как обход. Старый `com.example.electrician` — другое приложение,
его данные автоматически не перенесутся. При будущей миграции preferences API
нужна отдельная проверка формата/backend; R19.1 ничего не мигрирует.

## 8. Course/asset integrity

Повторный обход всех индексов и JSON подтвердил:

| Объект | Результат |
|---|---|
| Модули | 14, stage_0–stage_13 |
| Уроки по модулям | 5 / 8 / 9 / далее по 10 в stage_3–stage_13 |
| Уроки / unique lesson IDs | 132 / 132 |
| Блоки / scored | 1819 / 764, scoring types сверены с `isScoredLessonBlock` |
| Practice catalog | 18 ID; strict parsing и маршруты проходят suite |
| JSON syntax | все assets JSON разбираются |
| Порядок уроков | последовательный внутри каждого индекса |
| Index → lesson ID/file | совпадает; отсутствующих/неперечисленных lesson files нет |
| Image references | все image assets существуют; неиспользуемых PNG в assets/images нет |
| Дубликаты уроков | одинаковых полных payload после исключения id/title не найдено |
| Дубликаты изображений | побайтово одинаковых PNG в assets/images не найдено |
| APK JSON | все **166** course/practice JSON совпадают с source побайтово |

Распределение блоков: text=531, remember=136, warning=114, question=645,
image=269, circuit=4, calculation=85, multimeter=1, measurement=11,
voltageDrop=6, currentMeasurement=2, diagnosticCase=3, diagnosticChoice=1,
oscilloscope=11. Идентификаторы блоков/quiz metadata дополнительно проверяются
штатными model/content tests; они прошли.

Повторение отдельных safety warnings и закрепляющих вопросов не названо
случайным дублированием. Семантическая уникальность каждой формулировки и всех
учебных целей не доказана автоматическим сравнением JSON. Полная побайтовая сверка
каждого PNG внутри нового APK отдельно не выполнялась; source references и
соответствующие штатные asset/image tests прошли.

## 9. Critical workflow coverage matrix

Обозначения: U — unit/domain, W — widget. Все перечисленные штатные тесты входят
в успешно выполненные **1422**. Android integration/instrumentation tests для
этих сценариев не найдены. PASS ниже относится к автоматическому уровню.

| № | Сценарий | Имеющееся покрытие / результат | Что проверить на устройстве R18 |
|---|---|---|---|
| 1 | Открытие приложения | W `app_smoke_test.dart`: PASS | запуск/возврат из background, insets |
| 2 | Навигация курса | W app_smoke; U course_service/content: PASS | реальные переходы/Back на полном каталоге |
| 3 | Чтение урока | W lesson_screen, course_image, module_*_diagrams: PASS | длинные уроки, PNG, scroll/font |
| 4 | Ответ на вопрос | W lesson_screen, quiz_attempt: PASS | touch, клавиатура/фокус |
| 5 | Одна общая проверка quiz | W quiz_scroll_regression, module_*_quiz: PASS | общий submit, блокировка после него |
| 6 | Scroll без потери выбора | W quiz_scroll_regression, 14 real quiz: PASS | длинная прокрутка, resize/lifecycle |
| 7 | Retry quiz | W quiz_attempt/module_*_quiz: PASS | очищение попытки, новая оценка |
| 8 | Explicit completion | W app_smoke, lesson_save, module_*_quiz: PASS | новый ID → Module/Home после кнопки |
| 9 | Прогресс уроков | U progress_service/save/concurrency; W progress_loading/lesson_save: PASS | cold restart и native preferences |
| 10 | Мультиметр | U multimeter; W multimeter_block/measurement_block: PASS | hit targets, режимы и labels |
| 11 | Падение напряжения | U voltage_drop_simulation; W voltage_drop_block: PASS | читаемость схемы/щупов, touch |
| 12 | Осциллограф | U oscilloscope_simulation; W oscilloscope_block/module_11: PASS | шкалы, controls, font и TalkBack |
| 13 | Открытие практикума | W practice_screen/stabilization/final_acceptance: PASS | Home → каталог → кейс |
| 14 | Полный кейс | W practice_final_acceptance: 36 маршрутов PASS | хотя бы полный новый кейс и альтернативный путь |
| 15 | Evidence evaluation | U practice_engine/full_catalog/scoring_audit/acceptance_feedback: PASS | понятность claims/citations пользователю |
| 16 | Лучший результат | U result_repository/storage_failure; W practice acceptance: PASS | лучший/худший submit, restart каталога |
| 17 | Повторная попытка | W practice_final_acceptance/stabilization + U engine: PASS | cancel/confirm retry, best/count |
| 18 | Upgrade без удаления данных | U/W пересоздание store/route: PASS; native upgrade R18 NOT TESTED | install -r с совместимой подписью, старые IDs и practice results до/после |

Исторический physical HOTFIX smoke полезен для строк 5–8/18, но не подменяет
приёмку R18 и не подтверждает native persistence новых practice keys.

## 10. UX/accessibility

Штатные W включают узкие экраны, light/dark, text ×1.3, scroll/rebuild/resize,
длинный journal и реальные нажатия. Полный аудит всех комбинаций экранов/шрифтов
не выполнялся. Для Home добавлена **временная диагностическая проба вне test/**
только в архивной копии; в репозиторий тесты не добавлялись.

С настоящим Roboto из Flutter SDK, AppTheme.light/dark, viewport **360×800**:

| text scale | Light | Dark |
|---|---|---|
| ×1.0 | PASS | PASS |
| ×1.3 | PASS | PASS |
| ×2.0 | FAIL: RenderFlex overflow 14 px | FAIL: RenderFlex overflow 14 px |

Локатор исключения — `lib/screens/home_screen.dart:138`, Row с текстом
«Общий прогресс» и процентом. Это подтверждённый layout defect **R19-D01**,
а не предположение по коду. Два падающих probe cases не входят в штатные 1422.
Первый вариант probe имел ошибку async asset setup, исправлен preloading через
runAsync. Проверка с Ahem также давала overflow при ×1.3; этот результат
**не перенесён в finding**, поскольку с Roboto ×1.3 проходит.

PNG подписи являются частью изображения и не масштабируются как Flutter Text;
есть captions и сопутствующий текст, но эквивалентность всей схемы для screen reader
не проверена. У осциллографа есть Semantics с состоянием и шкалами; это не доказывает
полную доступность формы сигнала. В практикуме controls подписаны текстом,
однако реальный порядок фокуса, объявления модальных окон и обновлений не проверены.
Инструментальная оценка контраста всех состояний не выполнялась.

**TalkBack: NOT TESTED.** Ни accessibility hierarchy старого QA, ни widget semantics
не названы фактическим прогоном TalkBack. Android системный font fallback,
крупный текст, landscape и реальные touch targets остаются для device QA.

## 11. Safety and independent review gaps

В репозитории есть поэтапные technical/electrical reviews R8–R18, включая
`R16_MODULE_13_SAFETY_REVIEW.md`, `R17_MODULE_14_HV_SAFETY_REVIEW.md`,
`R18_FULL_SCENARIO_REVIEW.md` и `R18_FINAL_ACCEPTANCE.md`.
Они прямо описывают саморевью и границы синтетических моделей.

Текущие tests проверяют safety gates и отказ от недоказанных выводов. Наличие
этих проверок подтверждено; **независимая экспертиза инженером не подтверждена**.
Отдельного профильного sign-off для схем, диагностических кейсов, SRS, ABS/ESC,
HV и процедур измерений не найдено. Нужна проверка человеком соответствующей
квалификации до заявлений об экспертной пригодности курса. Этот аудит исходников
такой экспертизой не является. Технический контент R19.1 не менялся.

## 12. Confirmed defects

### R19-D01 — P2: Home переполняется при увеличенном тексте

- **Доказательство:** Roboto probe, 360×800, text ×2, обе темы: FlutterError
  `A RenderFlex overflowed by 14 pixels on the right`, Row `home_screen.dart:138`.
- **Affected files:** `lib/screens/home_screen.dart`; будущий regression test Home.
- **Воспроизводимость:** 2/2 настроек темы; ×1/×1.3 — 4/4 PASS.
- **Вероятность:** высокая при указанной конфигурации; доля пользователей неизвестна.
- **Влияние:** текст/процент выходят за доступную ширину, ухудшая чтение прогресса.
- **Минимальное исправление:** дать заголовку гибкую ширину/перенос или перестроить
  строку при нехватке места; не уменьшать системный text scale глобально.
- **Проверка:** regression с Roboto, 360 px, ×1/1.3/2 и обе темы; затем Android
  с крупным шрифтом, 0%/100% и сохранённым прогрессом.

### R19-D02 — P3: Home сообщает о трёх кейсах вместо восемнадцати

- **Доказательство:** `lib/screens/home_screen.dart:209` содержит
  «Три комплексных сценария: проверки и доказательства»; реальный каталог = 18.
- **Affected files:** `lib/screens/home_screen.dart`.
- **Воспроизводимость/вероятность:** постоянный текст при показе карточки практикума.
- **Влияние:** неверное представление об объёме доступной практики, без потери данных.
- **Минимальное исправление:** актуальная нейтральная подпись или число из каталога,
  если для этого уже есть данные; отдельный сервис ради числа не нужен.
- **Проверка:** сверка Home и каталога, smoke перехода в практикум.

### R19-D03 — P3: README описывает устаревший состав продукта

- **Доказательство:** `README.md:16` говорит «3 модуля и 22 урока», тогда как
  повторные assets tests/обход дают 14/132; список возможностей не описывает
  текущие осциллограф и отдельный сохраняемый практикум. В README также осталась
  прежняя оценка состояния R6 и непроверенного remote CI.
- **Affected files:** `README.md` в R18; локальные R6 docs требуют сверки при консолидации.
- **Воспроизводимость/вероятность:** каждый просмотр текущего README R18.
- **Влияние:** портфолио и инструкция не отражают проверяемый baseline;
  пользователь может неверно понять границы сохранения результатов.
- **Минимальное исправление:** после выбора baseline обновить текущие факты и
  явно отделить session draft урока от practice summary; не переписывать
  исторические QA-отчёты как будто они проверяли R18.
- **Проверка:** сверка чисел с assets, ссылок и статусов с evidence; не заявлять READY.

Подтверждённых **P0: 0, P1: 0, P2: 1, P3: 2** в проверенном объёме.
Задокументированные signing/QA/expert-review ограничения ниже не представлены
как воспроизведённые программные дефекты.

## 13. Unverified risks

| ID / приоритет проверки | Риск, evidence и affected files | Вероятность / влияние | Минимальное действие и проверка |
|---|---|---|---|
| R19-U01 / P1 | Не проверено native сохранение/upgrade R18; ProgressService, practice repository, установленный APK недоступен | вероятность неизвестна; возможна потеря/недоступность прогресса при ошибочной процедуре обновления | сверить сертификат и applicationId; install -r без удаления; проверить старые IDs, новые результаты и cold restart |
| R19-U02 / P1 для store, условно для sideload | release использует debug signing; app/build.gradle.kts | настройка подтверждена; несовместимость с установленным сертификатом неизвестна | определить канал и постоянный ключ отдельной задачей; не менять подпись перед upgrade без плана данных |
| R19-U03 / P1 | Независимое техническое/safety review отсутствует в evidence, включая SRS/ABS/HV | вероятность содержательной ошибки неизвестна; потенциально серьёзный учебный вывод | профильный review всех safety-critical материалов и sign-off; исправления отдельно |
| R19-U04 / P2 | TalkBack, native font/insets, contrast и touch нового практикума не проверены | неизвестна; часть пользователей может не завершить обучение | полный кейс, quiz и приборы с TalkBack, большим текстом, обеими темами на Android |
| R19-U05 / P2 | Последняя подтверждённая здесь история CI относится к R6; workflow push filter только main/R6 | факт фильтра подтверждён; текущий remote статус неизвестен | после отдельного разрешения проверить актуальный commit в CI через PR/manual workflow; Android build сейчас в CI отсутствует |
| R19-U06 / P2 | Native/toolchain vulnerabilities и полная лицензия supply chain не проверены | неизвестна; покрытие OSV ограничено Pub lockfile | отдельный inventory/audit SDK/Maven/Actions и notices без автоматического upgrade |
| R19-U07 / P2 | Release APK/AOT performance и размер текущего R18 не проверены | неизвестна; debug APK около 200 MiB не даёт release-оценки | отдельная release diagnostic build без публикации, затем smoke именно её |

Непроверенность не доказывает дефект. Для U01/U03 приоритет P1 обозначает
срочность закрытия серьёзного риска, а не подтверждённую потерю данных или
найденный опасный текст.

## 14. Prioritized action plan

1. **Сохранить baseline и evidence.** R18 уже содержит всю committed линию.
   Отдельно рассмотреть существующие R6/R11/HOTFIX docs и QA artifacts с владельцем,
   сохранив привязку каждого к старому HEAD. Не переносить ветки целиком ради docs.
   Текущий отчёт также нужно будет включить в выбранный baseline отдельным
   согласованным действием; сейчас он остаётся в рабочей папке R6.
2. **R19.2 — узкие исправления D01–D03.** Отдельная feature/fix-ветка от
   подтверждённого R18 после согласования; один regression для Home, актуализация
   подписи и README. Course JSON и storage schema для этих исправлений не нужны.
3. **Physical QA:** подписанный совместимым ключом upgrade без очистки;
   новый lesson completion, quiz fail/retry/pass/explicit completion, полный кейс,
   повтор/лучший результат и перезапуск процесса, затем TalkBack/крупный текст.
4. **Safety review и канал выпуска:** получить профильную оценку; отдельно
   решить portfolio/sideload или store и требования к постоянной подписи.
5. После приёмки — повторная итоговая проверка выбранного commit, release
   diagnostic build и CI. Только затем отдельное решение о release-ветке/публикации.

Это последовательность предложенных действий. Консолидация, fixes, запуск
remote workflow, смена signing/версии и release операции **не выполнялись**.

## 15. Release blockers

Для заявленного portfolio/sideload выпуска пока нет достаточного evidence:
**R18 physical QA, safe upgrade/native persistence, доступность нового практикума
и профильное safety review не закрыты**. D01 следует исправить до итоговой
приёмки крупного текста; D02/D03 — перед представлением текущего портфолио.

Для магазина дополнительно отсутствует настроенная production signing стратегия;
debug key не назван store-ready. Store readiness в текущем scope не достигалась.
Ни один найденный layout/documentation defect не требует удаления данных,
смены applicationId, схемы storage или массового refactoring.

## 16. Evidence and commands

| Команда / проверка | Фактический результат этого прохода |
|---|---|
| `git worktree list --porcelain`, status/HEAD каждого | 14 worktree, состояния в разделе 3 |
| `git merge-base --is-ancestor <tip> 3856e4d` | exit 0 для main/R6/R7–R17/HOTFIX |
| `git rev-list --left-right --count main...feature/diagnostic-practice` | 0 / 110 |
| `dart format --output=none --set-exit-if-changed lib test` | exit 0, **140 files, 0 changed** |
| `flutter pub get` | exit 0, Got dependencies; lockfile не изменён |
| `flutter analyze` | exit 0, **No issues found!**, 4.0 s |
| `flutter test --reporter expanded` | exit 0, **1422 / All tests passed!**, 3:39 |
| `flutter build apk --debug` | успешен, assembleDebug 193.6 s |
| `flutter pub outdated --json` | exit 0; 9 установленных пакетов имеют новые версии |
| OSV querybatch, exact Pub versions | 39/39 результатов, findings 0 в ответе базы |
| Home Roboto probe | **4 PASS / 2 FAIL**, подтверждает D01; отдельный диагностический запуск |
| aapt / apksigner / ZIP / JSON audit | package/version/SDK/signature/CRC подтверждены, 166 JSON совпадают |
| `git diff --check` в текущем workspace и R18 | exit 0; в текущем workspace только предупреждения LF→CRLF |
| `git status --short` R18 после проверок | пусто |
| `flutter build apk --release` | **NOT RUN**, необязательная диагностика |
| Android/TalkBack R18 | **NOT TESTED**, ADB devices пуст |

Команды Flutter исполнялись в архивной копии; Git-проверки — в настоящих worktree.
Попытка `git diff/status` внутри archive ожидаемо не применима (там нет .git);
итоговые успешные Git-проверки сделаны по реальным путям. Начальный вариант
счётчика assets был исправлен под фактические JSON-поля и camelCase type names;
в baseline это ничего не изменило. Промежуточные ошибки диагностических скриптов
не названы дефектами приложения.

`pub get`/Flutter commands изменили только line endings четырёх tracked generated
registrants **в архивной копии**: macOS GeneratedPluginRegistrant и три Windows
generated files. Сравнение после нормализации CRLF/LF совпадает с исходным архивом.
В настоящих worktree эти побочные изменения отсутствуют; pubspec/lock неизменны.

Локальные необязательные подробные logs/scripts сохранены в
`%TEMP%/electrician-r19-audit-3856e4d/`: `format.log`, `pub-get.log`, `analyze.log`,
`test.log`, `build-debug.log`, `outdated.json`, `osv.json`, `content-audit.json`,
`audit.py`, `extra_audit.py`, `home-scale-roboto.log` и
`source/audit_probes/home_scale_test.dart`. Temp не является постоянным архивом
evidence; существенные результаты и условия воспроизведения включены в этот отчёт.

Воспроизведение D01: взять точный R18, загрузить Roboto regular/medium/bold из
Flutter SDK через FontLoader, задать `tester.binding.setSurfaceSize(Size(360, 800))`,
предзагрузить `CourseService().loadAllLessons()` внутри `tester.runAsync`, использовать
mock preferences, `MaterialApp(theme: AppTheme.light/dark, home: HomeScreen())`
с `MediaQuery.textScaler=TextScaler.linear(2)`, завершить загрузку/pump и проверить
`tester.takeException()`. Исключение указывает Row `home_screen.dart:138`.
При ×1/×1.3 с тем же шрифтом исключения нет. Временный probe не добавлен к suite.

**Diff задачи:** добавлен только `docs/verification/R19_TECHNICAL_AUDIT.md`.
Шесть исходных пользовательских modified docs сохранены без редактирования
агентом. Production code, course data, тесты, Android и dependencies не менялись.
Commit не создавался: текущая папка уже содержала пользовательский diff, а
чистый аудитируемый R18 расположен в другом worktree. Push/merge/tag/Release нет.

## 17. Recommendation for R19.2

Согласовать небольшой этап D01–D03 от `3856e4d`, затем выполнить физическую
приёмку и профильное safety review. Не начинать новые модули/симуляторы и не
мигрировать storage ради этого аудита. До закрытия указанных условий сохранить
оценку **NOT READY**, не подменяя её числом успешных автоматических тестов.

**STOP после R19.1.**
