# R18.5 — Финальная проверка практикума диагноста

Дата: 2 ноября 2026, Asia/Qyzylorda. Worktree `electrician-r18`, ветка
`feature/diagnostic-practice`; исходный HEAD `59bc41d`, рабочее дерево чистое.

## Итоговый статус: PARTIAL

Автоматическая функциональная/UX-приёмка и debug APK: **PASS**.
Физическая Android QA: **NOT TESTED** — `flutter devices` показывает Windows,
Chrome и Edge, `adb devices -l` возвращает пустой список. Samsung S25 не доступен.
Нельзя объявить готовность к Android-релизу без установки обновления на устройство,
полного кейса, перезапуска процесса и контроля сохранённых результатов/старых уроков.
Внешней блокировки автоматической проверки нет; BLOCKED не применяется.

Новых кейсов и крупных функций нет. Baseline: 14 модулей, 132 урока,
1819 блоков, 764 задания, 18 кейсов. Все данные практикума остаются синтетическими.
Самостоятельное technical/safety review ниже **не является независимой экспертизой**.

## Матрица всех 18 кейсов

Обозначения: **W** — реальный workflow через Flutter widget controls;
**D** — domain/repository tests на реальных definitions. Это не instrumented
Android integration и не проверка настоящего автомобиля.

Для каждой строки W проходит в light/primary и dark/alternative, 360 logical px,
text ×1.3. Не подставляются готовые записи/ответы в controller для полного
прохождения: выбираются цель, профиль, проверки, hypotheses, citations,
интерпретации, conclusion и общий submit через UI.

| Кейс | Основной W | Альтернативный W | Угадывание / неверный / неполный D | Повтор D / retry W | Best, count, date, restart W/D | Объяснения, условия W/D / safety D |
|---|---|---|---|---|---|---|
| dp01 Тишина при попытке запуска | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp02 Прокрутка без запуска | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp03 Разрядка после стоянки | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp04 Зарядка меняется под нагрузкой | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp05 Один источник света тусклее | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp06 Предохранитель снова сработал | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp07 Странные напряжения при включении нагрузки | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp08 Сигнал пропадает ненадолго | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp09 Одна дверь не запирается | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp10 Стекло движется только вниз | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp11 Запрос дворников не выполняется | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp12 Воздух идёт только на максимуме | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp13 P0102: от сообщения к проверке | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp14 Одно колесо выпадает из записи | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp15 Один блок не отвечает | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp16 Необычная форма сигнала | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp17 Зарядная сессия не начинается | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |
| dp18 Предупреждение системы удержания | 100/PASS | 100/PASS | FAIL / FAIL / FAIL | PASS / PASS | PASS | PASS |

Столбцы перечисляют все десять требований R18.5:
1. Основной маршрут W — 100/PASS.
2. Альтернативный маршрут W — 100/PASS.
3–5. Правильный вывод без доказательств, неправильный вывод и недостаточные
   evidence/citations — D FAIL; для каждого случая проверяется содержание feedback.
6. Повтор проверки — D: без роста баллов, snapshots неизменны.
7. Retry — W: подтверждение, чистые draft/journal/hypotheses/responses; D: полный reset.
8. Сохранение — W: best=100, счётчик=1, UTC date в окне submit; rebuild не меняет
   счётчик/дату. После уничтожения route и reset plugin instance новый каталог
   перечитывает passed/best. D: худший повтор не стирает best/PASS, count=2.
9. Объяснение — W: соответствующий полный разбор после доказанного PASS;
   D: адресная ошибка для неверной интерпретации с достаточными ссылками, отсутствие
   утверждения о неподтверждённых измерениях при угадывании.
10. Safety — D: запрещённый метод blocked, без evidence, safety gate не даёт PASS;
    самостоятельное review действий/выводов по матрице R18.1 и полному ревью R18.4.

Маршруты определены отдельно в `test/practice/full_catalog_routes.dart`, а
не вычислены из proof groups. [Ревью моделей всех 18 кейсов](R18_FULL_SCENARIO_REVIEW.md)
содержит условия, конкурирующие гипотезы, расчёты, границы и ограничения.

## Функциональный и UX-аудит

| Проверка | Метод / результат |
|---|---|
| Главный экран → практикум | Прежний Home widget test: вход, каталог 18, прогресс 1/132 сохранён |
| Все карточки, сложность, описание | Каталог прокручивается, все 18 ID доступны; intro каждого проверяет difficulty/symptoms/topology |
| Выбор проверок и условия | W ×36: цель до результата, требуемый профиль; viewer совпадает с actual result, profile и scope |
| Числа/единицы/точки | Отдельные физические assertions R18.4 + viewer assertions; нет Ω на питаемой цепи, reversed voltage остаётся отдельным знаком |
| Журнал | Неизменяемые snapshots; прежний regression на 45 записях, прокрутка до конца/обратно |
| Гипотезы | W ×36: supported → contradicted, связанная реальная запись #1, прокрутка к последней гипотезе и rebuild; selections не теряются |
| Интерпретации | W ×36: варианты и конкретные citations через bottom sheet; rebuild сохраняет responses |
| Баллы / итог | W ×36: 100/PASS и текст разбора; отрицательные маршруты D сохраняют FAIL |
| Переполнения / темы | 360×800, text ×1.3, обе темы в полном W; прежние resize 600×420 и scroll regression сохранены |
| Основные действия | Находятся и нажимаются реальными pointer events; missed hit-test в новых W считается ошибкой |
| Большие packets в citations | Checkbox tile может быть выше листа; можно выбрать через видимый заголовок строки, без необходимости попадать в центр длинного текста |
| Защита сброса | Новый диалог retry; отмена и закрытие через barrier оставляют текущую immutable попытку и счётчик без изменений |
| Защита выхода | Сохраняющаяся работа учитывает также только safety/profile/polarity, а не лишь журнал/ответы |
| Завершённые кейсы | Каталог после пересоздания отображает passed и best; результаты разных ID независимы |

Дополнительно выполнен локальный visual audit четырёх PNG: окно samples dp16
и оценка dp18, light/dark, 360×800, text ×1.3, с загруженным Roboto из SDK.
Просмотрены `build/verification/r18_5/signal_{light,dark}.png` и
`srs_{light,dark}.png` (локальные generated artifacts, не native screenshots).
Контраст, переносы, прокрутка модального содержимого и доступность кнопки
закрытия визуально проверены. Длинный app bar title сокращается многоточием,
полное название и схема доступны в intro; вкладки переносятся в две строки.
В headless SDK-font export один символ стрелки имеет отсутствующий fallback glyph;
это ограничение локального рендера, а не подтверждённая ошибка Android. Проверка
реального системного font fallback остаётся на устройстве. Отдельные повторные
запуски тех же dp16/dp18 widget flows с Roboto: 4 PASS; они не прибавлены к общему
числу уникальных тестов.

Основные кнопки и предупреждения — на русском. Интерфейс указывает виртуальность,
условия и границы вывода; условная схема — текст с легендой, не интерактивный wiring.
Технические обозначения ECU, RUN, pull-up/down, capture остаются в материалах с
рекомендуемыми предзнаниями. Это экспертная оценка читаемости; usability-сессия
с новичком и TalkBack на телефоне не проводились. Большие шрифты сверх ×1.3,
реальные Android insets/клавиатура и физический touch требуют устройства.

До измерений нет вывода engine с отмеченным правильным ответом; набор возможных
заключений не является подтверждённым диагнозом. После исправления отправка
угаданного ответа также не раскрывает авторское утверждение о якобы выполненных
измерениях. Полезные объяснения ошибочной интерпретации сохраняются, когда нужные
измерения действительно выполнены и процитированы.

## Подтверждённые дефекты и локальные исправления

1. **Преждевременное подтверждение в feedback.** В исходном HEAD правильное
   угадывание давало FAIL, но conclusion.explanation всё равно утверждал
   «подтверждён путь/неисправность». Claim explanations также описывали результаты,
   которых в journal не было. Без полезного next action insufficient-объяснение
   могло утверждать, что он уже выбран. Новые 73 tests до исправления: 36 PASS,
   **37 FAIL**. После исправления все 73 PASS. Теперь сначала проверяется
   наличие нужного cited proof; при его отсутствии сообщается конкретный пробел.
   Подтверждающий разбор заключения выводится только при доказательствах и
   critical interpretations либо корректном промежуточном insufficient.
   **Веса, баллы, gates и вывод evaluator.passed не менялись.**
2. **Retry очищал journal без подтверждения.** Добавлен небольшой диалог:
   журнал/гипотезы/ответы будут очищены, best и lesson progress сохранятся.
   Cancel/barrier не меняют state; confirm создаёт новую попытку. Защита attempt ID
   не позволяет позднему ответу диалога сбросить уже другую попытку.
3. **Неполный guard выхода.** Изменение только профиля, полярности или отметки
   безопасности не попадало в hasDraft и терялось без предупреждения. Guard
   расширен на эти поля и follow-up/unsafe intent. Три отдельные widget regression
   проверяют cancel, сохранность state и явный подтверждённый выход без storage write.

Изменены только `lib/practice/attempt.dart` (формирование feedback) и
`lib/screens/practice_screen.dart` (два предупреждения). Данные кейсов не менялись.
Прежние widget tests теперь явно подтверждают retry; их старые assertions
сохранены и дополнены проверкой диалога. Ни один прежний тест не удалён/ослаблен.
Тестовый helper корректно прокручивает lazy intro и нажимает заголовок длинного
packet в citations; промежуточные ошибки автоматизации не названы дефектами приложения.

## Persistence и совместимость

Repository/schema практикума и `completed_lessons` не менялись.
В каждом из 36 полных W проверены результат, count=1, дата submit и неизменность
после rebuild; имитируется перезапуск route/plugin, не native Android процесса.
Прежние unit tests дополнительно проверяют лучшую/худшую попытку, +1 на submit,
последнюю дату, receipt retry без +1, ошибку platform setter/reload, очередность
записей, corrupt/incompatible data и независимость всех 18 keys.
Повреждённый key остаётся сохранённым и явно ошибочным, не сбрасывает уроки
или остальные результаты. Незавершённые попытки и полный журнал не сохраняются.

Полный suite включает quiz HOTFIX (черновики после длительной прокрутки),
132 урока и проверки course assets, progress reliability, мультиметр,
voltage drop/current, осциллограф, diagnostic blocks и их pure Dart модели.
Защищённые course assets, LessonBlock/models, LessonScreen, старые simulator
widgets/domain, ProgressService, зависимости, версия и Android configuration
сверены с `59bc41d`: **нет diff**. Подсчёт реальных assets подтверждает
14 модулей / 132 уникальных урока / 1819 блоков / 764 задания / 18 кейсов.

## Повторное safety review

Это самостоятельное ревью реализации и синтетического контента, **не независимая
экспертиза** и не разрешение выполнять работы на реальном автомобиле.

- **SRS / dp18:** только сообщения/сервисная граница, нет ReadingAction,
  pinout, номиналов пироцепи, процедур отключения/имитации/обхода. Четыре причины
  остаются неразличимыми; угадывание скрытого контакта не даёт PASS. Полный
  безопасный итог — обоснованный qualified referral.
- **HV / dp17:** только synthetic status packets. Нет HV-измерений, вскрытия,
  изоляционных процедур, обхода HVIL/контакторов/разрешений. LV-ready и not_run
  не доказывают исправность или безопасность HV; доказана внешняя авторизация EVSE.
- **ABS / dp14:** готовый стендовый эквивалент, анализ событий и сравнительных
  отчётов; нет дорожных опытов, гидравлических процедур и тормозных активаций.
- **LV:** току/сопротивлению соответствуют подготовленные отчёты; R только
  OFF/isolated, никаких процедур реального включения амперметра. Ноль потенциала
  без нагрузки не подменяет proof массы; floating node не получает фиктивный 0 V.
- **Выводы:** dp01 не диагностирует силовой мотор по току катушки; dp12 не
  объявляет причину перегрева установленной; dp13 не заменяет MAF по DTC;
  dp15 не гарантирует CAN/ECU после восстановления питания; dp16 различает объект
  и измерительную цепь. Без необходимых доказательств — только ограниченный вывод.

## Verification и Android APK

| Команда / проверка | Фактический результат |
|---|---|
| `dart format lib test` | PASS, 140 файлов |
| `flutter pub get` | PASS, без изменений dependencies/lockfile |
| `flutter analyze` | PASS — No issues found!, 1.5 s |
| `flutter test --reporter expanded` | PASS — **1422**, 2:28; прежние 1309 + новые 113 |
| `flutter build apk --debug` | PASS — assembleDebug, 18.1 s |
| `git diff --check` | PASS |
| `aapt dump badging` | PASS, applicationId/version/label сохранены |
| `apksigner verify --print-certs` | PASS, валидная Android Debug подпись; не store signing |
| ZIP CRC / assets audit | PASS; 166 JSON assets курса/практикума внутри APK побайтово совпадают с worktree, в том числе все 18 кейсов |

Новые тесты: `test/practice/practice_acceptance_feedback_test.dart` — 73;
`test/widgets/practice_final_acceptance_test.dart` — 40 (36 полных UI-маршрутов,
cancel/barrier retry и три guard-exit regression). Прежние 1309 сохранены.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **224794290 байт**.
SHA-256: `1622bf44d0a366d8221a80a89625c8b76f919268c6a747b0d184c8b4c473f388`.
ApplicationId `com.dauletserikson.autoelectrician`, versionName `0.1.0`,
versionCode `1`, label «Автоэлектрика с нуля». minSdk=24, targetSdk=36;
ABI arm64-v8a / armeabi-v7a / x86_64. Это подтверждение корректности собранного
архива, не установки/работы на физическом Android. Сертификат архива проверен,
но не сравнивался с установленным на недоступном телефоне приложением.

**Android QA: NOT TESTED.** Доступного Samsung нет. Не выполнялись установка,
uninstall, очистка SharedPreferences или сброс данных. Совместимость подписи с
установленным на телефоне APK неизвестна. При несовместимости следующая физическая
проверка должна остановиться без удаления приложения. Native cold restart,
device rendering, TalkBack и реальный touch не заменяются widget tests.

## Git и оставшиеся ограничения

Локальные commits:
- `35d9193` — `fix: require evidence before affirming diagnostic feedback`.
- `353214f` — `fix: confirm practice reset and guard unsaved selections`.
- Отдельный docs commit фиксирует этот отчёт; SHA и окончательный status
  указаны в итоговом сообщении после выполнения `git status --short`.

Scope — 8 файлов: 2 небольших production исправления, 2 новых тестовых файла,
3 обновлённых widget tests/helpers и этот отчёт. Новых учебных данных нет.
Четыре generated registrants после Flutter commands имели только line-ending
изменения (`git diff --quiet`: 0); восстановлены из HEAD и не включены в commits.
Другие worktrees не изменялись. После сборки изменялась только документация;
APK соответствует проверенному production tree `353214f`.

Остаются конечные синтетические модели, готовые текстовые схемы/samples,
session-only journal и отсутствие восстановления draft. Это прежний утверждённый
scope, не новые дефекты. Для release остаются физическая Android QA, реальная
доступность/читаемость и пользовательская проверка терминов. Store signing,
версия, публикация и release preparation в этот этап не входят.

Push, merge, tag и Release не выполнялись. **STOP после R18.5**.
