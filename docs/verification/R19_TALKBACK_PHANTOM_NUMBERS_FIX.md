# R19.3B.2 — Исправление лишних чисел TalkBack

Дата: 6 ноября 2026, Asia/Qyzylorda.

## Baseline и scope

Worktree `electrician-r19`, ветка `fix/r19-release-readiness`, исходный HEAD
`c781ce59bb1325b3ec9003242259e639427e1e98`. Рабочее дерево до изменений чистое.
Прочитан полный [отчёт расследования](R19_TALKBACK_PHANTOM_NUMBERS_INVESTIGATION.md),
изучены HomeScreen, callers/navigation, progress model, существующие Home и
accessibility tests, стандартные правила ListView/SliverChildListDelegate.
R19.3 `1279a25` является предком HEAD; его production baseline сохранён.

Изменены только:

- `lib/screens/home_screen.dart`;
- новый `test/widgets/home_accessibility_test.dart`;
- данный отчёт.

Исторические отчёты, прежние тесты, расчёт прогресса, учебная логика, навигационные
callbacks, shared_preferences, applicationId, версия `0.1.0+1` и зависимости
не изменены. Остальные worktree не перезаписывались. Новые функции не добавлены.

## Первопричины и исправления

**Дублирование прогресса.** Неинтерактивный LinearProgressIndicator добавлял
числовой `value=4`, роль progressBar и диапазон 0–100 в карточку, у которой уже
имелись доступные тексты «Общий прогресс», «4%» и «5 из 132 уроков».
Embedding добавлял `4, ` в начало contentDescription, а RangeInfo давал TalkBack
ещё один источник числового состояния `4.0`.

В `home_screen.dart:167` ExcludeSemantics оборачивает **только полосу**.
Она продолжает рисовать тот же `data.progress`. Заголовок, процент и число
уроков остаются обычными доступными Text. Вся карточка и интерактивные элементы
не исключаются. Название следующего модуля, его урок и действия карточек сохранены.
Исчезновение native ProgressBar role/RangeInfo здесь намеренно: состояние
полностью представлено доступным текстом, у полосы нет отдельного действия.

**Индексирование отступов.** Три top-level SizedBox считались самостоятельными
элементами коллекции Home. Те же расстояния 24/24/16 перенесены в верхний Padding
содержательных карточек (`home_screen.dart:138`, `:188`, `:200`). Стандартный
ListView теперь индексирует пять содержательных элементов: banner, progress,
continue/completed, course, practice. Порядок тот же. Не добавлены ручные
IndexedSemantics, нестандартные индексы или отключение коллекции целиком.

Ветка всех завершённых уроков сохранена: вместо Continue остаётся прежняя
completion card с тем же отступом. Правила завершения не изменены.

## Semantics до и после

Пример: пять завершённых уроков из 132, округление по прежней формуле даёт 4%.
ID из отдельных запусков не являются стабильными идентификаторами продукта.

```text
ДО — исследование R19.3B.1:
  collection.scrollChildCount=8
  progress item.indexInParent=2
    label="Общий прогресс\n4%\n5 из 132 уроков"
    value="4", minValue="0", maxValue="100"
    role=progressBar

ПОСЛЕ — dump неизменённых production widgets после исправления:
  collection #18: scrollChildCount=5
    item index=0: banner
    item index=1:
      node #11:
        label="Общий прогресс\n4%\n5 из 132 уроков"
        value="", minValue=null, maxValue=null, hint=""
        role=none, children=[], actions=0
    item index=2: continue / completed
    item index=3: course
    item index=4: practice
```

Дополнительный временный widget probe вне репозитория получил dumps для
0/1/5/132 completed и Course/Module. Четыре пробы прошли; writes=0.
Они не входят в количество штатных тестов.

## Регрессионные тесты

Новый файл добавляет **20** тестов:

- 16 комбинаций: 320/360 logical px × text scale 1/1.3/1.5/2 × light/dark;
- ещё три состояния completed=0/1/132; completed=5 проверяется матрицей;
- открытие Continue, Course и Practice через `SemanticsAction.tap`, с возвратом.

Проверяются точная метка прогресса, один процент, пустой value и отсутствие
min/max/progressBar как у карточки, так и у её семантических потомков.
Проверяются индексы всех пяти элементов и scrollChildCount=5, доступность
названий следующего модуля/урока, количества уроков/модулей/кейсов, наличие tap,
реальное открытие нужного экрана и отсутствие записей прогресса.
Использован Roboto из установленного SDK, как в прежнем Home layout suite;
проверяются Flutter exceptions/overflow при прокрутке к содержимому.

До изменения production новые проверки выявили value=4. После исключения
только полосы **19 проверок ещё падали на индексе 2 вместо 1**, а проверка
активации проходила. После переноса отступов весь набор проходит.
Первоначальные ошибки самого test fixture — позднее освобождение SemanticsHandle
и попытка найти уже выгруженный lazy-list элемент — исправлены через try/finally
и последовательную прокрутку. Assertions и существующие тесты не ослаблялись.

Focused run нового файла, home_screen_test и app_accessibility_test: **45 PASS**.
Полный suite: **1467 PASS = прежние 1447 + 20 новых**.

## APK и установка на Samsung

Устройство доступно: Samsung SM-S931B, Android 17 / API 37, 1080×2340,
density 480, font_scale=1.0. Серийный номер в отчёт не включён.
Системная locale первая kk-KZ, Samsung TTS locale ru_RU.

Собран новый **debug APK**, путь `build/app/outputs/flutter-apk/app-debug.apk`.
SHA-256: `eaf0c3b58245bbb7fe343ec0e989c17bfdc5d8dbbfc62700cbe49de326c2687e`.
Предыдущий установленный APK перед обновлением имел SHA-256
`3cd06a73fb4ad2ed08cfde2e5a108a0e913ba36c0f77a0dbf45fc1a846d473e7`.

Оба APK проверены apksigner: одинаковый Android Debug certificate,
SHA-256 `72fe40666599647f40d946340a2926e05fbdaaf66fbce789c7d802793f1fe295`.
Aapt подтвердил прежние applicationId, versionName=0.1.0, versionCode=1,
minSdk=24, targetSdk=36. Debug signing не является production-store signing.

`adb install -r`: **Success**. Uninstall, clear data и ручная запись preferences
не выполнялись. Снимок native preferences до установки побайтно совпал:

1. сразу после обновления;
2. после первого холодного запуска;
3. после TalkBack-ретеста и повторного force-stop/start.

Сохранены пять завершённых уроков и прежний результат dp01; новые результаты
не создавались. Оба холодных запуска завершились Status: ok.
Hash установленного base.apk совпал с новым локальным APK.
ZIP CRC исправен, все **333** объявленных asset-файла побайтно совпали с source:
166 JSON, 157 PNG, 10 MD. Course/practice assets не изменены: 14 модулей,
132 урока, 1819 блоков и 18 кейсов.

## Физическая проверка TalkBack

Владелец явно разрешил агенту включить TalkBack для прослушивания и выключить
его после проверки. Язык, голос, verbosity и масштаб текста не менялись.
Агент открыл Home и одиночным касанием сфокусировал прежнюю проблемную карточку.

Нативные данные получены read-only инспектором UiAutomation с сохранением
других accessibility services. Он выбирал root целевого пакета среди окон:
первоначальная версия, читавшая только active window, не дала пригодного снимка.
Финальная версия завершилась exit 0. Ошибка кодировки диагностического Python
сравнения исправлена при чтении UTF-8; production-код для этого не менялся.

```text
ПОСЛЕ, Android AccessibilityNodeInfo:
  CollectionInfo(rows=5, columns=1)
  progress parent: CollectionItemInfo(rowIndex=1, columnIndex=0)
  progress content node: android.view.View
    contentDescription="Общий прогресс\n4%\n5 из 132 уроков"
    RangeInfo отсутствует
    bounds=[60,823][1020,1153]
  ни одного android.widget.ProgressBar на Home

ПОСЛЕ, собственный dump TalkBack при целевой фокусировке:
  CollectionState: rowCount=5, colCount=1
  ListItemState: index=1
```

Все шесть контентных native node bounds (app bar, banner, progress, continue,
course, practice) совпали с исходным снимком расследования. Позиция progress
теперь соответствует **2 из 5**, а не 3 из 8. Native contentDescription не
содержит начального `4, `, процент встречается один раз, диапазона 4.0 нет.

Владелец получил целевой вопрос: передать всю фразу, проверить лишние «4»,
«4 ноля» и отдельный «0», число объявлений процента и позицию коллекции.
Его фактический ответ: **«Все гуд спасибо рпботатет правильно»**.
Это общее положительное подтверждение целевого прослушивания на Samsung.
Дословной полной фразы TalkBack или аудиозаписи владелец не предоставил;
contentDescription выше не выдаётся за буквальный transcript речи.

### Отдельный статус «0»

Первоначальное происхождение самостоятельного «0» по-прежнему **UNCONFIRMED**:
исторический вывод не переписан. В этом ретесте владелец подтвердил корректную
работу в ответ на вопрос, явно включавший проверку «0», и не сообщил о его
сохранении. Источник FLOAT RangeInfo, согласующийся с прежним «4 ноля», теперь
доказанно отсутствует. Это положительный результат одной целевой конфигурации,
не доказательство произношения всех возможных числовых состояний на любых TTS.

После ретеста TalkBack выключен согласно полученному разрешению:
accessibility_enabled=0, enabled services=null. Locale list, TTS ru_RU и
font_scale=1.0 сохранены; временные inspector JAR удалены с телефона.
Приложение оставлено на Home после успешного холодного перезапуска.
В финальном PID log buffer не найдены FATAL EXCEPTION, Unhandled Exception,
RenderFlex overflow, EXCEPTION CAUGHT BY и E/flutter. Это ограниченная проверка
данного сеанса, а не гарантия отсутствия ошибок во всём приложении.

## Обязательные проверки и ограничения

| Проверка | Фактический результат |
|---|---|
| dart format lib test | 143 файла; source и новый test отформатированы, повторно 0 изменений |
| flutter pub get | успешно, lockfile не изменён |
| flutter analyze | No issues found! |
| flutter test --reporter expanded | 1467 PASS |
| flutter build apk --debug | успешно, assembleDebug 36.8 s |
| git diff --check | exit 0 |
| Старые тесты, assets, зависимости, исторический investigation report | git diff пустой |
| Samsung install -r | Success; native preferences сохранены |
| Целевое прослушивание | общее положительное подтверждение владельца; точного transcript нет |

Четыре generated registrants после Flutter команд отличались только checkout
line endings. Эквивалентность HEAD проверена, восстановлен исходный формат;
их содержимое не включено в diff. Чужие изменения не откатывались.
Новый файл тестов и отчёт — единственные добавления помимо правки HomeScreen.

Охват физической проверки ограничен одним Samsung, текущим прогрессом 5/132,
одним TTS и font_scale=1.0. Другие состояния/размеры/темы проверены автоматикой.
Полный accessibility checklist R19 и независимое профильное ревью этим не закрыты.
Raw screenshots, dumps, preferences и временные probes остаются вне Git;
персональные данные и серийный номер не публикуются.

Разрешённый локальный commit:
`fix(accessibility): deduplicate progress and correct list semantics`.
SHA и итоговый Git status сообщаются отдельно после commit.
Push, merge, rebase, изменение версии и GitHub Release не выполняются.

**STOP после R19.3B.2. Переход к R19.4 не выполняется.**
