# R19.4 — Android Release Candidate RC1

Дата аудита: 6 ноября 2026, Asia/Qyzylorda.

**Итог: RC1 PARTIAL.** Технические release APK/AAB получены и проверены.
**Production signing: SIGNING BLOCKED.** Существующая конфигурация подписывает
release debug-ключом. Публичная готовность не заявляется. Дополнительно не пройдена
проверка отсутствия локальных путей и не подтверждена битовая воспроизводимость
независимых сборок. Артефакты остаются локальными, не предназначены для публикации.

## Git baseline и GitHub

Исходный HEAD: `65b7f9d40aa0414371c4d5ea20c16acc2282a191`, worktree
`electrician-r19`, ветка `fix/r19-release-readiness`, рабочее дерево чистое.
Подтверждены commits `c781ce5` и `65b7f9d`, правильный origin
`https://github.com/DauletSerikson/auto-electrician-learning-app.git`.

Выполнены status, branch -vv, remote -v, fetch origin, log -5 и worktree inventory.
После fetch main/origin/main = `368ea076d212cf5a6fa1f51a16ef039542637537`;
`rev-list --left-right --count origin/main...R19` = 0 / 2.
Оба main — предки R19. Main не был занят другим worktree.

Проверены четыре новых файловых объекта отправляемой истории: credential/key
signatures и неожиданных бинарных объектов не выявлено. Выполнены безопасный
fast-forward main, обычные push main и fix/r19-release-readiness, fetch и сверка.
После синхронизации все четыре refs совпали на **`65b7f9d40aa0414371c4d5ea20c16acc2282a191`**.
История не переписывалась, merge-коммит не создавался, чужие worktree не менялись.
Финальный ls-remote подтвердил тот же SHA обеих удалённых веток.

После этого создан локальный commit версии **`a04939504bd71c8e1577bddcfa5c5753aa5814e4`**
(`chore: prepare Android RC1 version metadata`): одна строка pubspec и две строки
README. Код и assets идентичны 65b7f9d. Данный отчёт сохраняется отдельным локальным
docs commit; его SHA сообщается в итоговом ответе. Новые RC1 commits не отправляются
автоматически: main/origin/main остаются на синхронизированном baseline 65b7f9d.

## Версия и безопасное обновление

Владелец явно подтвердил: распространялись только сборки с build number **+1**.
Git history также показывает только versionCode=1; установленное приложение
на Samsung имеет versionName=0.1.0, versionCode=1.

Принято минимальное изменение **`0.1.0-rc.1+2`**:

- Android versionName: `0.1.0-rc.1`;
- Android versionCode: `2`, монотонное увеличение 1 → 2;
- applicationId/namespace: **`com.dauletserikson.autoelectrician`**, без изменения.

Android проверяет обновление по applicationId, совместимой подписи и versionCode,
а не по лексикографическому сравнению versionName
([официальные правила обновления](https://developer.android.com/google/play/app-updates),
[versioning](https://developer.android.com/studio/publish/versioning)).
Откат к +1 после установки RC1 не является обычным обновлением. Будущая debug
сборка для того же приложения должна иметь совместимую подпись и code ≥2.

## Android-конфигурация и официальные требования

Проверены pubspec, app/root/settings Gradle Kotlin DSL, gradle.properties,
wrapper properties, main/debug/profile manifests, MainActivity, signing и ignore rules.

| Параметр | Фактическое значение |
|---|---|
| Flutter / Dart | 3.47.5 stable / 3.13.4 |
| Flutter framework / engine revision | 6a19cca564 / af7e796e16 |
| applicationId / namespace / Kotlin package | com.dauletserikson.autoelectrician |
| MainActivity | FlutterActivity, package и manifest согласованы |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36, SDK defaults и APK metadata |
| Android Build Tools | 36.0.0 |
| NDK | 28.2.13676358 |
| AGP / Gradle wrapper | 9.1.0 / 9.3.1 |
| Kotlin Gradle plugin | 2.4.0, settings.gradle.kts |
| Gradle embedded Kotlin | 2.2.21, не путать с KGP проекта |
| Фактическая Java / JVM target | Android Studio JBR 25.0.3 / Java и Kotlin 17 |
| signing release | существующий signingConfigs.getByName("debug") |

Gradle --version выполнен через явную JBR; Flutter doctor подтвердил тот же JDK.
Существующие android.newDsl=false, android.builtInKotlin=false и Windows workaround
kotlin.incremental=false не менялись. Обновление AGP/Kotlin/dependencies не выполнялось.

На дату аудита официальная [target API policy](https://developer.android.com/google/play/requirements/target-sdk)
требует для новых обычных Android apps/updates API 36 с 31 августа 2026;
targetSdk=36 удовлетворяет именно этому требованию. Это не полный Play compliance audit.
[Документация AGP 9.1](https://developer.android.com/build/releases/agp-9-1-0-release-notes)
указывает Gradle 9.3.1 и минимальный JDK 17; фактические release-сборки с JBR 25 успешны.

Проверена [официальная рекомендация по 16 KB](https://developer.android.com/guide/practices/page-sizes).
У обоих APK `zipalign -c -P 16 4` завершился exit 0. Все PT_LOAD 64-bit ELF
библиотек имеют alignment ≥16384: libapp/libflutter — 65536, datastore counter — 16384.
AAB BundleConfig задаёт `PAGE_ALIGNMENT_16K`. Это статическая проверка упаковки/ELF;
runtime на 16 KB устройстве **NOT VERIFIED**. Подключённый Samsung имеет page size 4096.

## Signing и manifest

Нового production keystore не создано. android/key.properties отсутствует;
production release signing не настроен. Существующий debug fallback оставлен
без изменения, новая подмена подписи не выполнялась.

APK 1/2 проверены apksigner: APK Signature Scheme **v2 valid**, одинаковый сертификат:

```text
DN: C=US, O=Android, CN=Android Debug
certificate SHA-256:
72fe40666599647f40d946340a2926e05fbdaaf66fbce789c7d802793f1fe295
```

Это тот же сертификат установленного debug APK, проверенный на предыдущем этапе.
Он технически совместим для локального обновления, но не production-store signing
([официальная документация](https://developer.android.com/studio/publish/app-signing)).
Пароли/приватные ключи не выводились и не копировались в Git.

Release manifest не содержит debuggable/testOnly marker или INTERNET permission.
Имеется стандартная generated signature permission AndroidX.
android.permission.DUMP у ProfileInstallReceiver — ограничение вызывающей стороны,
а не запрос приложением DUMP permission. Receiver/ProfileInstaller не удалялись.
Отсутствие debuggable не превращает debug-сертификат в production signing.

Оба AAB прошли **bundletool 1.18.3 validate**, exit 0. Официальный bundletool
загружен из google/bundletool; SHA-256 сверена с digest GitHub release asset.
Jarsigner вернул exit 0 / jar verified, но JBR 25 вывел предупреждения о self-signed
сертификате, отсутствии timestamp и различиях JarFile/JarInputStream из-за порядка
manifest. Они не скрыты и не объявлены подтверждением store readiness.
Дополнительная полная проверка через Java JarFile с verification=true прочитала
в обоих AAB **712 подписанных payload entries, 0 неподписанных**; сертификат совпал.
JarInputStream-совместимость отдельно не подтверждена; bundletool parsing успешен.

## Артефакты

Основные артефакты — build 1, из рабочего каталога:

| Формат | Путь | Размер, bytes | SHA-256 |
|---|---|---:|---|
| APK | build/app/outputs/flutter-apk/app-release.apk | 109312226 | `5a6d303635d6b0000bbcae767113634b16c15b18f09110416e361b4feda02f5d` |
| AAB | build/app/outputs/bundle/release/app-release.aab | 68369457 | `9a1ba4b06cf888e099ada51d4a1208dfbf73ea1084128ad038b688f24eebb1a9` |

Повторные артефакты и logs хранятся вне Git в
`%TEMP%/electrician-r19-rc1-65b7f9d-20261106/`, файлы rc1-build-1/2/3.apk/.aab.
Копии build 1 сверены с основными workspace outputs после всех проверок.
Артефакты не включались в commits и не загружались на GitHub.

## Содержимое и поиск секретов/локальных путей

Во всех четырёх независимо полученных APK/AAB 1/2 проверены ZIP CRC и побайтное
совпадение **333 объявленных assets** с source: 166 JSON, 157 PNG, 10 MD.
Каталог содержит **14 модулей, 132 урока, 1819 блоков, 764 задания, 18 кейсов**.
Русские тексты присутствуют в JSON и ресурсах. 156 авторских SVG остаются
в Git как исходники иллюстраций; runtime использует PNG. SVG source directories
намеренно не объявлены в pubspec и не названы потерянными runtime assets.

Source tree включает актуальный Home, quiz HOTFIX 17049fd и исправление
TalkBack 65b7f9d. Lib/test/assets в ходе R19.4 не менялись; полный suite прошёл.
Снимки tracked source в рабочем каталоге и archive совпали с нормализацией
checkout line endings. Это provenance сборки, не физический прогон AOT UI.

Проверены 1043 tracked файловых объекта и распакованные записи артефактов:
private-key/token/credential signatures и имена signing files. Секретов по этим
проверкам не выявлено. Срабатывания serial/email regex в source оказались словами
REPLACEMENT/RELIABILITY и iOS filenames вида @2x.png, а не персональными данными.
Это ограниченная проверка сигнатур, не гарантия отсутствия любых возможных секретов.

В APK/AAB нет тестовых каталогов, .dart_tool, .git, local.properties,
key.properties, keystore, kernel_blob.bin или debug snapshot files.
В AAB присутствуют штатные BUNDLE-METADATA native symbols/proguard map/profiles;
они перечислены отдельно и не названы случайно включённым test suite.

**Проверка отсутствия локальных путей НЕ ПРОЙДЕНА.** Найдены:

- во всех трёх ABI libapp.so — file URI к generated
  `%WORKTREE%/.dart_tool/flutter_build/dart_plugin_registrant.dart`;
- во второй сборке URI соответствует каталогу изолированной archive-копии;
- в AAB пути присутствуют также в libapp.so.sym и base/resources.pb.

Пути содержатся в данных артефакта, несмотря на отсутствие самого каталога
.dart_tool среди ZIP entries. Поиск охватывал raw bytes и нормализацию
UTF-16-представления. Для вывода/отчёта персональный профиль редактирован до
%USERPROFILE%/%TEMP%. Удаление путей из release pipeline требует отдельного
проверяемого решения; binary patch/непроверенные compiler flags не применялись.

## Воспроизводимость

Build 1: рабочая папка, source tree соответствует a049395. Build 2: свежий
`git archive a049395` вне всех worktree, без собственного build output/.dart_tool.
SDK/JDK, pubspec/lockfile, signing key и флаги одинаковы; абсолютный путь source
различается. Эта разница зафиксирована как входной фактор, а не замолчана.

| Сборка | APK release | AAB release |
|---|---|---|
| 1, рабочая папка | exit 0, 142.7 s | exit 0, 17.4 s |
| 2, свежий archive | exit 0, 55.1 s | exit 0, 13.8 s |
| 3, тот же каталог как 2, incremental | exit 0, 4.2 s | exit 0, 3.4 s |

Хэши build 2:

```text
APK, 109312226 bytes:
7f88ba3c1ba205e04a345860b69b96a35676d6505850a123da11065a83dae267
AAB, 68369644 bytes:
901d3e1455e7cf6e57b99ae8ad1e7f51bc4c05bb1977bcb052a34aa18527e85f
```

Build 1 и 2 **не бит-в-бит одинаковы**. ZIP entry names/order, timestamps,
compression metadata и все runtime assets совпадают. В APK различаются только
три libapp.so. В AAB различаются соответствующие libapp.so/sym и три JAR signing
entries. Остальные entries побайтно одинаковы, включая manifest/config и ресурсы.

ELF-анализ выявил различия build IDs, .rodata и части .text; размеры библиотек
одинаковы. Встроенная абсолютная URI registrant меняется между source directories,
что подтверждает зависимость AOT payload от пути. Только timestamps/упаковкой
объяснить результат нельзя. Не доказано, что все оставшиеся различия вызваны
исключительно URI; полная детерминированность compiler pipeline не установлена.

Дополнительный incremental build 3 совпал **обоими SHA-256** с build 2.
Это подтверждает стабильность повторного запуска с cache, но не независимую
битовую воспроизводимость. Попытка удалить только временный generated build
для отдельной пересборки в том же пути была отклонена автоматической проверкой
безопасности (причина не уточнена); удаления/очистки не произошло. Обхода отказа
через другой способ удаления не было; выбран обычный build без очистки.

AGP version-control-info.textproto в обеих сборках сообщает
NO_SUPPORTED_VCS_FOUND. Встроенный Git SHA не подтверждён этим файлом;
привязка source commit к артефактам выполняется данным отчётом и SHA-256.

## Данные установленного приложения и физическая QA

RC1 release APK **не устанавливался**: в этом проходе выполняется подготовка
технического кандидата с открытыми signing/artifact blockers. Сертификат, ID и
versionCode допускают локальное обновление существующего +1 по метаданным, но
реальный debug → RC1 release upgrade **NOT VERIFIED**. Не выдаётся за physical PASS.

На Samsung оставлен прежний проверенный debug APK +1. Native preferences
перед работой и после неё совпали побайтно: completed lesson IDs и результат
практикума сохранены. Это доказывает отсутствие изменения текущих данных
в этом сеансе, а не сохранность после ещё не выполненной установки RC1.
Uninstall, pm clear, downgrade и изменение системных настроек не выполнялись.
Release-вариант не debuggable; прежний способ чтения через run-as после его
установки может стать недоступным. План физической приёмки должен это учитывать.

Полный физический прогон курса/кейсов, upgrade/native persistence именно RC1,
release-mode TalkBack/крупный шрифт и 16 KB runtime остаются **MANUAL QA REQUIRED**.
Из R19.3B.2 сохранены положительное подтверждение владельца и native semantics
проверки debug baseline. Самостоятельный исторический «0» остаётся UNCONFIRMED;
точной записи речи в том ретесте не было. Полный accessibility checklist не закрыт.
Независимое профильное safety review содержания также не подтверждено.

## Проверки и следующий контрольный шаг

| Проверка | Результат |
|---|---|
| dart format lib test | 143 файла, 0 изменений |
| dart format --output=none --set-exit-if-changed lib test | exit 0, 143 файла, 0 изменений |
| flutter pub get | успешно; lockfile не изменён |
| flutter analyze | No issues found! |
| flutter test --reporter expanded | 1467 PASS, All tests passed! |
| APK/AAB release builds 1/2 | все exit 0 |
| APK signatures / zipalign / 64-bit ELF alignment | проверены |
| bundletool validate / JarFile payload signatures | оба AAB прошли |
| git diff --check | exit 0 |
| lib/test/assets/android/pubspec.lock | diff относительно 65b7f9d пустой |

Четыре generated registrants получили только переводы строк после Flutter tools:
эквивалентность проверена, checkout line endings восстановлены. Чужие изменения
не откатывались, lint/tests не ослаблялись. JBR native-access/Unsafe warnings
не скрывались; сборки завершились успешно.

Оставшиеся blockers: production signing, встроенные локальные пути,
независимая воспроизводимость, физическая приёмка release и обновления,
полная accessibility QA и профильное ревью. Изменения build pipeline/signing
и дальнейшая приёмка требуют отдельных задач; RC1 не помечен READY FOR PUBLIC RELEASE.

Новые локальные изменения R19.4 ограничены pubspec.yaml, README.md и этим отчётом.
После docs commit ожидается чистый R19 с двумя локальными commits впереди origin.
Новые commits RC1/артефакты не публикуются, теги/GitHub Release/Google Play не создаются.
Git history не переписана; reset/clean/rebase/удаление worktree не выполнялись.

**STOP после R19.4.**
