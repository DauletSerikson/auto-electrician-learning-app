# R17.2–R17.4 — Реализация модуля 14

Дата: 26 октября 2026, Asia/Qyzylorda. Worktree `electrician-r17`, ветка
`feature/module-14-hybrid-electric-vehicles`. Утверждённый план R17.1 — commit
`7f4516c`, [основной документ](../roadmap/R17_MODULE_14_PLAN.md).
Реализован только согласованный R17. Без push/merge/tag/Release, R18 не начат.

## Итоговый объём и поведение

| Показатель | Baseline | После R17 | Добавлено |
| --- | ---: | ---: | ---: |
| Модули | 13 | 14 | 1 |
| Уроки | 122 | 132 | 10 |
| Учебные блоки | 1667 | 1819 | 152 |
| Оцениваемые задания | 696 | 764 | 68 |
| Проходящие автоматические тесты | 876 | 900 | 24 |

Добавлены 20 оригинальных SVG и 20 PNG ×3. Только существующие
text/image/question/calculation/warning/remember, пять диагностических карт
K1–K5, практикум **12 questions + 3 calculations = 15 / passingScore80**.
Для обычных уроков нужны все правильные ответы; для quiz — все ответы,
минимум 12 верных и отдельное explicit completion. Retry снимает результат.

| Lesson ID | Тема | Блоки | Задания |
| --- | --- | ---: | ---: |
| hybrid_ev_01 | Архитектура HEV, PHEV и BEV | 13 | 4 |
| hybrid_ev_02 | Высоковольтные системы и безопасность | 12 | 5 |
| hybrid_ev_03 | Тяговая батарея и BMS | 11 | 5 |
| hybrid_ev_04 | Инвертор и тяговый электродвигатель | 11 | 5 |
| hybrid_ev_05 | DC/DC-преобразователь и низковольтная сеть | 9 | 4 |
| hybrid_ev_06 | AC/DC-зарядка электромобиля | 11 | 5 |
| hybrid_ev_07 | Контакторы, предзаряд и контроль изоляции | 13 | 5 |
| hybrid_ev_08 | Охлаждение и терморегулирование | 10 | 5 |
| hybrid_ev_09 | Комплексные диагностические кейсы | 33 | 15 |
| hybrid_ev_10 | Итоговый практикум | 29 | 15 |

Изменение пользовательских данных: stage_13 добавлен в конец курса,
общий знаменатель прогресса стал 132. Прежние 122 lesson IDs/порядок/данные
сохранены; миграция storage не нужна. Прогресс проверен с сохранением всех
старых completed IDs и неизвестного ID, затем одного нового завершения.
Ответы/попытки по-прежнему живут в LessonScreen, в storage только completed IDs.

## Изучено и затронутые файлы

Проверены фактические AGENTS.md, утверждённый план, модели/парсинг LessonBlock,
LessonBlockRenderer, LessonAttempt/completion, CourseService/ProgressService,
CalculationBlock/QuestionBlock и тесты предыдущих модулей. DiagnosticChoice
привязан к электрическому сценарию лампы, scope не поддерживает RC-предзаряд:
они не переименовывались в HV-симуляторы. Production Dart не менялся.

- `assets/course/modules.json`: одна запись stage_13; старый prefix прежний.
- `assets/course/stage_13/`: индекс и 10 JSON-уроков.
- `assets/images/hybrid_ev/`:20 PNG, SVG-исходники, каталог размеров и README
  происхождения. Каталог не содержит ключей ответов.
- `pubspec.yaml`: только две новые asset-директории. Версия 0.1.0+1 прежняя,
  dependencies и lock не изменены.
- `tools/build_hybrid_ev_course.py`, `tools/render_hybrid_ev_assets.py`:
  детерминированный авторинг только новых файлов; renderer использует прежние
  графические helpers R15 без изменения старого генератора/изображений.
- `tools/audit_hybrid_ev_module.py`: read-only baseline/course/APK audit.
- Три новых test files: `test/services/module_14_content_test.dart`,
  `test/widgets/module_14_diagrams_test.dart`, `test/widgets/module_14_quiz_test.dart`.
-20 прежних test files обновлены только по актуальным общекурсовым counts,
  completion metadata и ограниченному prefix-срезу модуля 13. Существующие
  физические/диагностические assertions не ослаблены и не удалены.
- Этот отчёт и [отдельное HV safety review](R17_MODULE_14_HV_SAFETY_REVIEW.md).

Учебный контент/графика изменены добавлением нового модуля; код, scoring,
persistence, прежние тренажёры и 122 урока сохранены. Backend/облака/AI/
новые framework/types/dependencies не добавлялись. Другие worktree/R6 не изменялись.
Исторические планы/отчёты/аудиты R9–R16 не переписаны как R17.

## Проверка технического содержания и безопасности

Отдельное саморевью проверяет архитектуру E0/B0, номиналы против фактических
значений, Ah/Wh/SOC/SOH, преобразование мощности/потери, port/battery/heater,
RC-условия/энергию и тепловой поток. Источники и применимость названы в
HV-отчёте и §10 плана. Все данные авторские синтетические; числа не OEM-нормы.

Кейсы: отсутствие поддержки LV, cold charging limit, недостигнутый предзаряд,
разброс групп, thermal derating. Для каждого заданы архитектура/режим/сообщения,
данные/гипотезы/границы и безопасное продолжение. Конкретная неисправная деталь
по одному статусу или корреляции не назначается.

Положительных рекомендаций практического HV-вмешательства не выявлено в рамках
саморевью. Нет вскрытия/отключения HV-разъёмов, процедур обесточивания/разряда,
физических HV/изоляционных измерений, команд контакторам/обхода HVIL/BMS.
OFF/Ready/feedback/IMD/цвет/один U не выдаются за доказательство безопасности.
Ученик анализирует готовые данные; неизвестное опасное состояние передаётся
квалифицированной помощи. Это не независимое экспертное заключение.

## Тестирование и фактические команды

24 новых теста:17 content/domain,3 image/manifest/layout,4 widgets/layout/
navigation/quiz. Проверяются metadata, parsing реальных JSON, регистрация/
уникальность/order,20 изображений, completion, все 122 старых completions и
unknown ID. Реальный quiz проходит 11/15 fail →12/15 pass после retry расчёта,
retry вопроса блокирует completion до нового ответа; до explicit completion
нет записи, после — одна запись с сохранением предыдущих IDs.

Математические проверки независимы от correctValue: реальные SVG-параметры
групп/мощностей,601 точка каждой U/I-кривой,601 точка эталона и 5 K3, энергия
по интегралу тока/потерь, баланс D0/K1/K2,95+1 группа K4, M1/K5 и тепло T0.
Whitelist типов и правильные безопасные ответы дополняют ручное safety review.

Первый targeted run обнаружил одно точное сравнение 28,9 с результатом
28,900000000000002 в новом тесте. Исправлено сравнением `closeTo(28.9, 1e-10)`;
числа учебной модели не менялись. Layout/навигация/quiz тогда уже проходили.
Последующий полный suite прошёл без отказов.

| Команда | Результат |
| --- | --- |
| `dart format lib test` | Exit0;115 файлов, итоговый прогон 0 изменений |
| `flutter pub get` | Exit0; без upgrade, lock/version прежние |
| `flutter analyze` | Exit0; **No issues found!**; финальный повтор 3,1 s |
| `flutter test --reporter expanded` | Exit0; **900 / All tests passed!**,83 s |
| Три новых test files + capture env | Первый запуск 23 passed/1 numeric assertion failed; после исправления все 24 прошли в общем suite.40 image/caption captures сохранены |
| `python tools/audit_hybrid_ev_module.py` | Exit0; **14/132/1819/764**, модуль 14 **152/68/20**, **466 baseline файлов неизменны**, modules prefix и asset-only pubspec verified |
| Повтор авторских генераторов и SHA-256 сравнение | Exit0; **53 файла** воспроизводятся побайтово:11 course JSON +42 image/source/README/catalog |
| `flutter build apk --debug` | Exit0; assembleDebug56,8 s, APK создан |
| `python tools/audit_hybrid_ev_module.py --apk build/app/outputs/flutter-apk/app-debug.apk` | Exit0; **304 referenced JSON/PNG byte-exact**, новые SVG source не включены в runtime |
| `git diff --check` | Exit0; staged/committed diff дополнительно проверяется перед/после commits |

Доступные обновления пакетов, перечисленные Flutter, не применялись.
Generated registrants macOS/Windows после Flutter-команд имеют только
line-ending churn без текстового diff; перед commit возвращены к HEAD
только эти четыре файла из изначально чистого R17.

При сборке Java/Gradle вывели предупреждение restricted native access;
процесс завершился с exit0, параметры JVM/toolchain для подавления не менялись.
APK `build/app/outputs/flutter-apk/app-debug.apk`: **209 067 701 bytes**
(≈199,4 MiB), debug universal APK. В Git не добавлен, находится в ignored build/.
Его размер не является оценкой размера release. SHA-256:

```text
B4EB94294B9A3D5011B5D8689D898F40A248A84FBA97AB5444E467C519621ACD
```

## Воспроизведение графики и визуальная QA

```powershell
python tools/build_hybrid_ev_course.py
$env:PYTHONPATH = 'F:/projects/FlutterApps/new_app/AutoElectro/electrician-r10/build/asset-tools'
python tools/render_hybrid_ev_assets.py
$env:SAVE_R17_MODULE_PREVIEWS = '1'
$env:R17_MODULE_FONT = 'C:/Windows/Fonts/arial.ttf'
flutter test test/widgets/module_14_diagrams_test.dart --reporter expanded
```

resvg-py — существующий изолированный dev tooling, не новая Flutter dependency.
Arial используется локально, файл шрифта не распространяется. PNG непрозрачные,
SVG source не нужен runtime. Все 20 исходных композиций просмотрены, все 40
image/caption layout проверены 360 logical px/light/dark/×1,3. Сохранённые
Flutter captures в игнорируемом `build/r17_module14_previews/`, просмотрены
пары light/dark B0/D0, P0/K3 и K2/K5. Все остальные blocks десяти уроков также
проверены в обеих темах при 360 px/×1,3 без overflow/исключений.

Физический Android QA, TalkBack и независимая профильная/HV-экспертиза
не выполнялись. Debug build/widget tests не доказывают удобство длительного
чтения на устройстве, доступность или экспертную пригодность материала.
Release APK/store signing/публикация не входят в разрешённый scope.

## Локальные commits и итог

1. `4e72388` — `feat: add module 14 hybrid and electric vehicle lessons`:
   57 файлов контента/графики/регистрации/генераторов.
2. `a6d593f` — `test: verify module 14 models HV boundaries and completion`:
   24 файла, в том числе 20 обновлённых tests,3 новых test files и read-only audit.
3. `docs: record module 14 verification and HV safety review` — два отчёта.
   SHA сообщается владельцу отдельно, чтобы не создавать самоссылку.

Перед docs commit изменены только два новых отчёта. Staged diff проверяется
`git diff --cached --check`; после commit повторяются `git status --short`,
`git diff 7f4516c..HEAD --check` и аудит APK. Локальные commits разрешены
заданием, сетевые Git-операции не выполнялись. **STOP после R17**.
