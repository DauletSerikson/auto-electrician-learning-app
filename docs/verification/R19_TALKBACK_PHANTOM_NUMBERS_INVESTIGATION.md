# R19.3B.1 — Исследование лишних чисел TalkBack

Дата: 6 ноября 2026, Asia/Qyzylorda. **Только исследование, без исправлений.**

## Результат и степень доказанности

Источник отдельного **«4» перед заголовком установлен**: `value="4"`
индикатора добавляется Android embedding в начало `contentDescription` всей
карточки. Одновременно в её `label` уже присутствует видимый текст `4%`.

Источник объявления позиции **«3 из …» установлен**: это метаданные коллекции
Home. Сам TalkBack сообщил `ListItemState.index=2`, `rowCount=8`. Среди восьми
индексируемых элементов есть три декоративных `SizedBox`. Это не количество
завершённых или доступных уроков. Полное число «8» владелец дословно не передал;
оно подтверждено нативным деревом и внутренним состоянием TalkBack.

Для услышанного **«4 ноля»** есть сильное объяснение: нативный ProgressBar имеет
`RangeInfo(type=FLOAT, current=4.0)`. Публичный код TalkBack преобразует такое
состояние через `String.valueOf(float)`, то есть в `4.0`. Владелец при повторе
сообщил именно «4 ноля», затем «4», затем заголовок. Однако точная строка,
переданная **установленным** TalkBack в Samsung TTS, не перехвачена.
**Отдельное самостоятельное объявление «0» — UNCONFIRMED.** Нельзя объявлять
доказанным чтение `minValue=0`: наличие этой границы не означает её озвучивание.

Подтверждено дублирование информации **внутри одного узла** между label/value
и нативным RangeInfo. Дублирования двух самостоятельных родительского/дочернего
узлов, каждый из которых читает весь блок, в полученных деревьях нет.

## Baseline и границы работы

- Worktree: `electrician-r19`, ветка `fix/r19-release-readiness`.
- Начальный HEAD: `368ea076d212cf5a6fa1f51a16ef039542637537`; status/diff чистые.
- `R19_ACCESSIBILITY_FIXES.md` прочитан: исторический OPEN дефект описан честно;
  фраза об оставленных незакоммиченными изменениях относится к прошлому сеансу.
  R19.3 впоследствии закоммичен как `1279a25`. Исторический отчёт не изменён.
- Подтверждённый baseline: 14 модулей, 132 урока, 18 кейсов, 1447 тестов.
- Исследованы Home/Course/Module, модель прогресса, app localization boundary,
  accessibility/smoke tests и соответствующие части установленного Flutter SDK.
- Production Dart, существующие UI-тесты, course JSON, зависимости, порядок
  фокуса и рабочая разметка не изменялись. Нового APK не собиралось/не устанавливалось.

Корневой worktree `electrician` по-прежнему содержит старые пользовательские
изменения R6 и untracked аудит. Они не удалялись и не перезаписывались.
Единственный сохраняемый файл этой задачи — данный отчёт.

## Samsung и условия воспроизведения

`flutter devices` и `adb devices -l` обнаружили подключённый Samsung **SM-S931B**,
Android **17 / API 37**, 1080×2340, density 480, font_scale **1.0**.
Серийный номер устройства в отчёт не включён.

Установленный APK прочитан через `pm path`/`adb pull`: SHA-256
`3cd06a73fb4ad2ed08cfde2e5a108a0e913ba36c0f77a0dbf45fc1a846d473e7`.
Он совпал с имеющимся локальным debug APK и APK из отчёта R19.3.
Версия `0.1.0+1`, applicationId `com.dauletserikson.autoelectrician`.
Никакого обновления/удаления приложения или очистки данных не было.

Системная locale первая `kk-KZ`; TTS — `com.samsung.SMT:ru_RU`.
Фактический TalkBack service dump: **17.1.0.1003738110**, versionCode **60236122**,
`systemLanguage=kk_KZ`, TTS `localeInUse=ru-RU`, `preferredVoice=ru-RU-default`.
Включены `speakCollectionInfo` и `speakRoles`; настройки не менялись.

На старте TalkBack выключен. Владелец согласился включить его самостоятельно.
После его сообщения о трудностях управления приложение повторно выведено
на передний план через `am start`, фокус установлен одиночным ADB-касанием
по карточке. Нативный инспектор подтвердил `accessibilityFocused=true` у ProgressBar.
Ни уроки, ни кейсы не завершались, ответы не вводились.

Фактические сообщения владельца при прослушивании:

1. Сначала «4», затем видимое содержимое карточки, после количества уроков —
   «ОРЫНДАЛУ ЖОЛЫ 3 ИЗ сколько то там».
2. После повторной фокусировки: «он говорит 4 ноля. Потом 4 потом читает Общий прогресс».

Это результаты прослушивания владельцем, не аудиозапись и не самостоятельно
услышанная агентом речь. Полная последовательность каждого повтора не записана.
Видимый порядок, порядок дерева и порядок речи не приравниваются друг к другу.

По отдельному явному разрешению владельца в конце выключен **только TalkBack**.
Проверены исходные `accessibility_enabled=0`, enabled services=`null`;
locale list, font_scale и TTS locale сохранены. Временные inspector JAR/XML
удалены с телефона. Приложение оставлено на Home.
Native preferences побайтно совпали с диагностическим снимком перед дальнейшими
действиями: пять completed lesson IDs и сохранённый результат dp01 не изменены.

## Получение деревьев без изменения рабочего приложения

Из `git archive 368ea07` создана отдельная копия во временном каталоге
`%TEMP%/electrician-r19-phantom-368ea07-20261106/source`.
Это **не Git worktree**. Только там добавлен `audit_probes/semantics_probe_test.dart`.

Пробы используют неизменённые `AutoElectricianApp`/HomeScreen, реальные assets,
`PreferencesPlatformFake`, `tester.ensureSemantics`, `tester.getSemantics`,
обход `SemanticsNode`, `getSemanticsData` и `debugDumpSemanticsTree`.
Для 0/1/5/132 завершённых уроков сохранены label/value/hint/min/max/role,
индексы, размеры коллекции и дочерние узлы. Для пяти уроков также открыты
Course и первый Module. Во всех четырёх пробах `preferences.writes == 0`.

Первый вариант probe ошибочно обращался к `SemanticsData.indexInParent`.
В данном SDK свойство принадлежит `SemanticsNode`; инструмент исправлен.
Это ошибка временного скрипта, не приложения. Финальный запуск — **4 PASS**.
Пробы не добавлены в существующий suite и не считаются частью его 1447 тестов.
`SemanticsDebugger` overlay не включался: он менял бы рабочее представление;
dump и widget probe дали нужные свойства без production-инструментализации.

Первичный `uiautomator dump` выполнен до включения TalkBack. При включённом
TalkBack применён отдельный read-only Java inspector через shell `app_process`:
`UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`, чтение
`AccessibilityNodeInfo`, без `performAction` и без установки APK.
Флаг сохраняет работу других accessibility services
([Android API](https://developer.android.com/reference/android/app/UiAutomation#FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)).
После чтения UiAutomation отключался. Инспектор отдельно ограничивал обход
и сохранял повторные ID, чтобы не обходить дерево бесконечно.

Промежуточные диагностические ошибки: скрытые connect/disconnect потребовали
reflection; d8.bat выбрал старую Java, поэтому D8 запущен явной Android Studio JBR;
вариант с waitForIdle завершался `Killed / 137`. Финальный вариант без этого
ожидания успешно прочитал дерево и завершился exit 0. Эти попытки не названы
дефектами приложения или успешным исследованием нативных данных.

## Flutter Semantics Tree

При пяти завершённых уроках: `5 / 132 * 100 = 3.7878…`, округление даёт **4**.
Формула — `lib/models/home_progress.dart:14`, деление — строка 19.
Число не является скрытой константой или индексом модуля.

Сокращённый dump финальной пробы, ID действительны только для этого запуска:

```text
SemanticsNode#21: scrollChildren=8, scrollIndex=0
  #9  indexInParent=0  banner label
  #10 indexInParent=1  empty label                    // SizedBox(height:24)
  #11 indexInParent=2  empty label                    // progress list item
    #12 role=progressBar
        label="Общий прогресс\n4%\n5 из 132 уроков"
        value="4", minValue="0", maxValue="100", hint=""
        actions=0, children=[]
  #13 indexInParent=3  empty label                    // SizedBox(height:24)
  #14 indexInParent=4
    #15 label="Продолжить обучение\n…"
  #16 indexInParent=5  empty label                    // SizedBox(height:16)
  #17 indexInParent=6
    #18 label="Курс\nУчебных модулей: 14\nУроков: 132"
  #19 indexInParent=7
    #20 label="Практика диагноста\nДиагностических кейсов: 18\n…"
```

У #12 `isMergedIntoParent=false`, `mergeAllDescendants=false`: это не доказательство
наличия явного `MergeSemantics`. Текстовые аннотации и роль индикатора уже собраны
в один итоговый узел; отдельного дочернего узла с повтором всей метки нет.
Стандартная Card образует семантическую границу: Flutter SDK
`material/card.dart:253` и `:267`; на Home она создаётся в строке 139.

| Completed | label карточки | value | min/max | role |
|---|---|---|---|---|
| 0 | Общий прогресс / 0% / 0 из 132 уроков | 0 | 0/100 | progressBar |
| 1 | Общий прогресс / 1% / 1 из 132 уроков | 1 | 0/100 | progressBar |
| 5 | Общий прогресс / 4% / 5 из 132 уроков | 4 | 0/100 | progressBar |
| 132 | Общий прогресс / 100% / 132 из 132 уроков | 100 | 0/100 | progressBar |

Course: `scrollChildCount=14`; видимые цифровые badges входят в метки модулей.
Модуль с order=0 показывает иконку безопасности, а не скрытый Text «0»
(`course_screen.dart:59`). Остальные badges — видимые `module.order`, строка 62.
Module: `scrollChildCount=5`; каждая полученная метка содержит ровно один статус
«Урок N, завершён», название, описание и видимое время. Источники:
`module_screen.dart:100`, `:115`, `:119`, `:123`, `:137`, `:141`.
Необъяснимого отдельного «0» в этих метках не найдено. Полного физического
прослушивания всех модулей/уроков эта проверка не заменяет.

## Android AccessibilityNodeInfo и состояние самого TalkBack

В нативном снимке этой сессии virtual IDs отличаются от widget-test IDs:

```text
virtual #58 android.view.View
  CollectionInfo(rows=8, columns=1, hierarchical=false)
  virtual #48 android.view.View
    CollectionItemInfo(rowIndex=2, columnIndex=0, spans=1x1)
    virtual #49 android.widget.ProgressBar
      contentDescription="4, Общий прогресс\n4%\n5 из 132 уроков"
      text=null, stateDescription=null
      RangeInfo(type=1/FLOAT, min=0.0, max=100.0, current=4.0)
      accessibilityFocused=true
      bounds=[60,823][1020,1153]
      actions=[ACTION_CLEAR_ACCESSIBILITY_FOCUS]
```

`sourceNodeId` прочитан инспектором; virtual ID выделен из его старших 32 бит.
Эти ID служат идентификаторами узлов, а не произносимыми числами.

Read-only `dumpsys activity service …TalkBackService` дополнительно подтвердил:

```text
speakCollectionInfo=true, speakRoles=true
CollectionState: colCount=1, rowCount=8
ListItemState: index=2
AccessibilityFocusActionHistory:
  class=android.widget.ProgressBar
  content="4, Общий прогресс\n4%\n5 из 132 уроков"
```

Это доказательство получения метаданных **самим TalkBack**, а не только
наличия их во Flutter. Speech Controller dump показал русскую TTS locale,
но не содержал полного текста последней utterance. Логирование речи и настройки
verbosity специально не включались. В репозиторий не включены raw dumps:
история фокуса содержит также сведения о системных экранах вне приложения.

SDK **Flutter 3.47.5 / Dart 3.13.4**, engine `af7e796e161ae0bb1ff0758c71a7105418bd9ded`.
В `material/progress_indicator.dart:150` determinate value преобразуется в
целую числовую строку без знака процента, строки 153–158 задают роль/min/max/value.
Комментарий SDK о значении с `%` не заменяет фактическую реализацию и dump.

В соответствующем локальном `flutter_embedding_debug-1.0.0-af7e796e….jar`
через javap проверены `BaseRoleConfigurator` и `ProgressBarRoleConfigurator`:
первый устанавливает contentDescription из value/label/hint, второй задаёт
класс ProgressBar и RangeInfo типа FLOAT. LineNumberTable последнего указывает
на `ProgressBarRoleConfigurator.java:19` и `:39`; это сведения bytecode,
а не заявление о наличии Java source в репозитории приложения.

Публичный [SeekBarDescription](https://github.com/google/talkback/blob/229212fdf5842191d0a93fc95d9ca1423b346866/talkback/src/main/java/com/google/android/accessibility/talkback/compositor/roledescription/SeekBarDescription.java#L106)
использует FLOAT current для строки состояния. Его
[RoleDescriptionExtractor](https://github.com/google/talkback/blob/229212fdf5842191d0a93fc95d9ca1423b346866/talkback/src/main/java/com/google/android/accessibility/talkback/compositor/roledescription/RoleDescriptionExtractor.java)
применяет этот обработчик и к ProgressBar и допускает порядок state → name → role.
Это поддерживает объяснение `4.0 → 4, … → роль`, но публичный snapshot не объявлен
побайтовым исходником установленного TalkBack 17.1. Точная настройка порядка
описаний и конкретная TTS utterance здесь не извлечены.

## Обязательная таблица расследования

| Наблюдение | Источник в UI | Semantic node | Значение | Причина | Уверенность |
|---|---|---|---|---|---|
| «4» перед «Общий прогресс» | LinearProgressIndicator, `home_screen.dart:167`; видимый процент — `:157` | Flutter #12; Android virtual #49 | Flutter value=4; Android contentDescription начинается с `4, ` | SDK берёт rounded progress; embedding соединяет value с label, который уже содержит 4% | CONFIRMED, высокая: Flutter + native + focus history + прослушивание владельца |
| «0» / уточнённое «4 ноля» | Тот же индикатор, `home_screen.dart:167`; SDK `progress_indicator.dart:156` и `:158` | Android #49, RangeInfo FLOAT current=4.0; отдельной label «0» нет | min=0, max=100, current=4.0 | Сильная гипотеза: дробная часть из stringification FLOAT state в TalkBack; нельзя приравнивать её к чтению min=0 | UNCONFIRMED как отдельное «0»; объяснение через 4.0 — высокая согласованность, без прямого TTS transcript |
| Дополнительное «3 из …» после уроков | Home ListView `home_screen.dart:87`; progress — третий child после banner и gap `:137` | Flutter #21/#11; Android #58/#48; TalkBack ListItemState | zero-based index=2, rowCount=8 → позиция 3 из 8 | Автоматическое объявление коллекции; три отступа индексируются наравне с содержимым | CONFIRMED источник/метаданные; «3 из …» услышано владельцем, конечное «8» не процитировано им дословно |
| «ОРЫНДАЛУ ЖОЛЫ» | Роль индикатора `home_screen.dart:167` | Android #49 class=ProgressBar | Нативная роль progress bar, не строка из assets | Системное описание роли от TalkBack при systemLanguage=kk_KZ; пользовательский контент имеет ru locale | Подтверждены роль, locale и фраза владельца; это не дополнительное число |

## Причина индексирования и отличие от дефекта TalkBack

Home ListView не задаёт специальную семантику коллекции. SDK
`widgets/scroll_view.dart:1330` включает addSemanticIndexes, строка 1356 берёт
children.length. `widgets/scroll_delegate.dart:777` оборачивает children
в IndexedSemantics. Поэтому в коллекции оказываются:

| Index | Child Home | Строка home_screen.dart |
|---|---|---|
| 0 | Banner | 90 |
| 1 | SizedBox 24 | 137 |
| 2 | Карточка прогресса | 139 |
| 3 | SizedBox 24 | 182 |
| 4 | Continue / completion card | 184 |
| 5 | SizedBox 16 | 194 |
| 6 | Курс | 196 |
| 7 | Практика | 214 |

TalkBack штатно объявляет роль и позицию, предоставленные приложением/embedding.
Полученные данные не доказывают ошибку самого TalkBack. Проблема приложения —
избыточное представление одного прогресса и коллекция с декоративными элементами.
Настройки Samsung TTS не объявлены первопричиной: дублирование существует до TTS.

## Минимальные варианты исправления — НЕ РЕАЛИЗОВАНЫ

| Подход | Оценка |
|---|---|
| Только добавить semanticsLabel индикатору | Не устраняет числовой value, RangeInfo и повтор 4% в общей label; может добавить ещё один повтор заголовка |
| Задать произвольный русский semanticsValue | Неподходящее изменение для этого SDK: progressBar требует числовые value/min/max; текстовое value может нарушить validation/RangeInfo |
| Дополнительно объединить карточку через MergeSemantics | Узел уже объединён; это не устраняет несколько представлений процента и не исправляет индекс коллекции |
| Исключить только семантику неинтерактивной полосы LinearProgressIndicator | Наименьший кандидат после установленного дублирования: оставить доступными заголовок, 4% и 5 из 132 уроков; убрать только повторные value/RangeInfo от визуальной полосы |
| Явно описать всю карточку одним Semantics label/value | Возможный более явный вариант, но требует аккуратно заменить дочерние аннотации и выбрать роль; не должен повторить процент или скрыть count |
| Исправить индексы только Home | Не индексировать декоративные gaps, согласовать semanticChildCount с содержательными карточками; сохранить смысл позиции в коллекции |
| Отключить индексирование всех списков / speakCollectionInfo в TalkBack | Не рекомендуется: скрывает полезные позиции модулей и уроков и затрагивает пользовательские настройки |

Предлагается отдельно согласовать **два узких изменения**:

1. Проверить хирургическое исключение только неинтерактивной полосы из semantics
   при сохранении всех трёх доступных текстов карточки. Это не ExcludeSemantics
   наугад: native tree доказал, что полоса вносит уже представленные value/RangeInfo.
   Компромисс — исчезнет нативная роль ProgressBar/диапазон; их смысл должен
   полностью оставаться в доступном названии «Общий прогресс», проценте и count.
   Нельзя исключать всю карточку, ListView или controls. Если сохранение нативной
   роли обязательно, нужен более явный единый контракт semantics с отдельной
   проверкой Android/TalkBack вместо механической замены value.
2. Исправить семантическое индексирование Home, пропуская только декоративные
   отступы. Например, через delegate с semanticIndexCallback/осмысленные
   IndexedSemantics и согласованный count. Одного уменьшения semanticChildCount
   недостаточно: индексы тоже должны быть непрерывными. При пяти содержательных
   children progress станет второй карточкой, а не третьей из восьми.

Оба варианта сохраняют значимую информацию: завершено/всего/процент, доступ к
курсу и практике, полезные позиции модулей/уроков. Ни один здесь не применён.

## Серьёзность, ограничения и ретест

Оценка **P2 / moderate accessibility issue**: прогресс озвучивается избыточно,
метаданные выглядят как непонятные дополнительные числа, владелец подтвердил
затруднение. Потери данных или недоступности всего учебного процесса не доказано.

После отдельного разрешения на исправление:

1. Regression tests для 0/1/5/132 completed, обеих тем, повторного открытия Home;
   проверить label/value/role и отсутствие повторного процента, а не только Text.
2. Проверить индексы и count Home, отсутствие индексируемых gaps, курс/модули
   и действия открытия; отдельно учитывать completed-all ветку.
3. На этом Samsung проверить одновременно Flutter tree, AccessibilityNodeInfo,
   TalkBack CollectionState и фактическую речь. Зафиксировать полную фразу и
   порядок, лучше с согласованной записью, не угадывать их по порядку дерева.
4. Не менять язык телефона/TTS/verbosity ради обхода. Проверить хотя бы ru и
   kk системные locale только при отдельном согласовании и вернуть настройки.
5. Подтвердить, что слышны заголовок, процент и completed/total ровно в нужном
   объёме, а не достигнуть тишины удалением всех semantics. Проверить native
   persistence до/после совместимого обновления, без uninstall/clear data.

Ограничения: один физический Samsung/одна конфигурация; нет аудиозаписи и
точного transcript TTS; standalone «0» не доказан; полный accessibility audit,
все уроки/кейсы и остальные устройства не проверялись. Историческое OPEN
состояние дефекта не заменено на FIXED/PASS. Временные logs/Java/Dart probes
остаются в Temp и не являются постоянными репозиторными артефактами;
существенные очищенные от персональных данных фрагменты приведены выше.

## Verification и Git

Проверки приложения выполнены на точном `git archive 368ea07` в изолированной
копии. Перед завершением lib/test/assets побайтно сравнены с целевым R19;
pubspec/lock и исторический отчёт совпали с учётом checkout line endings.
Наличие archive без .git ожидаемо: Git-проверки проводились в реальном R19.

| Проверка | Фактический результат |
|---|---|
| dart format lib test | 142 файла, 0 изменений |
| flutter pub get | exit 0; зависимости не обновлялись |
| flutter analyze | No issues found! |
| flutter test --reporter expanded | 1447 PASS, All tests passed! |
| Отдельный временный semantics probe | 4 PASS, writes=0 |
| Samsung native inspector | exit 0, AccessibilityNodeInfo прочитан при включённом TalkBack |
| Native preferences comparison | побайтно без изменений относительно диагностического snapshot |
| git diff --check | exit 0 перед сохранением отчёта; повторяется перед commit |
| Новый APK | NOT BUILT / NOT INSTALLED; использован прежний R19.3 |

Разрешён один локальный docs commit только данного отчёта после проверки diff.
Commit исправления, push, merge, rebase, reset, clean, изменения версии,
зависимостей, applicationId и Release не выполняются. Итоговый SHA локального
docs commit и Git status сообщаются владельцу отдельно.

**STOP после исследования. Исправление требует отдельного утверждения.**
