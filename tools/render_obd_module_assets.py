"""Render only five new R11 module compositions; pilot assets stay untouched.

Uses the existing development resvg-py environment and pilot SVG helpers.
"""
from render_obd_assets import SOURCE, box, card, label, line, write


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    card('diagnostic_chain', 'Диагностическая цепочка', ['Назначение каждого звена'], [
        ('Система автомобиля', 'Физический процесс'),
        ('ЭБУ', 'Наблюдение / расчёт'),
        ('Интерфейс / протокол', 'Доступные запросы'),
        ('Сканер / программа', 'Представление данных'),
        ('Специалист', 'Гипотезы и проверки'),
    ], ['Код не называет деталь.', 'OBD ≠ все блоки авто.'])
    e = [label(16, 32, 'DLC • лицевая розетка', 22),
         label(16, 64, 'Смотрим со стороны прибора'),
         label(16, 92, 'Широкая сторона сверху'),
         label(16, 120, 'Type A, легковой 12 V'),
         '<polygon points="16,170 304,170 286,300 34,300" fill="#f4f8fc" stroke="#234b68" stroke-width="3"/>']
    for number in range(1, 17):
        column, row = (number - 1) % 8, (number - 1) // 8
        x, y = (38 + column * 34 if row == 0 else 46 + column * 32), 210 + row * 54
        fill = '#ffe3ab' if number == 16 else '#c5e5d3' if number in (4, 5) else '#c6dff9' if number in (6, 14) else '#ffffff'
        e.append(f'<rect x="{x-14}" y="{y-22}" width="28" height="32" rx="3" fill="{fill}" stroke="#234b68"/>')
        e.append(label(x, y, str(number), text_anchor='middle', id=f'pin{number}'))
    for y, text in enumerate([
        'Верх: 1…8 слева направо', 'Низ: 9…16 слева направо',
        '16 — питание от АКБ', '4 — кузовная масса', '5 — сигнальная масса',
        '6 — CAN-H, 14 — CAN-L', 'Для CAN-реализации OBD',
        'Остальные: сверять схему.', 'Вид с проводов зеркальный.',
        'Не подавать питание', 'на неизвестный контакт.',
    ]):
        e.append(label(16, 343 + y * 30, text))
    write('dlc_front', 675, e)
    card('scanner_scope', 'Выбор инструмента', ['Покрытие проверяют по задаче'], [
        ('Generic reader', 'Emissions-данные OBD'),
        ('Адаптер + приложение', 'Зависит от реализации'),
        ('Мультимарочный / OEM', 'Покрытие модели / блока'),
        ('Чтение ≠ программирование', 'Разные сервисы и риски'),
    ], ['RPM не доказывает ABS.', 'Нет гарантии всех функций.'])
    card('dtc_status', 'Код, лампа и готовность', ['Не универсальный drive cycle'], [
        ('Pending', 'Пока без подтверждения'),
        ('Confirmed / stored', 'Запись ≠ текущая причина'),
        ('Permanent, где поддержан', 'Не удаляется обычным clear'),
        ('MIL', 'Индикатор неисправности'),
        ('Readiness', 'Завершённость мониторов'),
    ], ['Сначала сохранить данные.', 'Clear не является ремонтом.'])
    e = [label(16, 32, 'C • опора B−', 22),
         label(16, 64, 'Синтетические наблюдения'),
         label(16, 92, 'ХХ, стоянка, 90 °C'),
         label(16, 120, '750 rpm, load 35%, 0 km/h')]
    for ident, top, value, text in [
        ('battery', 198, 14.2, 'B+ / B− = 14,20 V'),
        ('ecuSupply', 308, 11.3, 'P_ECU / B− = 11,30 V'),
        ('ecuGround', 418, .1, 'G_ECU / B− = +0,10 V'),
    ]:
        e += [label(16, top-18, text), line(58, top+20, 288, top+20),
              f'<rect id="{ident}" x="58" y="{top}" width="{value*230/15}" height="20" fill="#155b8a"/>']
    e += [label(54, 474, '0'), label(264, 474, '15'), label(96, 506, 'Потенциал, V'),
          label(16, 552, 'U_ECU = P_ECU − G_ECU'), label(16, 582, '11,30 − 0,10 = 11,20 V'),
          label(16, 612, 'PID 42: 11,200 V'), label(16, 644, 'Не синхронные PID/DMM.'),
          label(16, 674, 'Устойчивый режим t=0…4 s')]
    write('compare_voltage', 698, e)


if __name__ == '__main__':
    main()
