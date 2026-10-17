"""Author R12 SVG and 3x PNG using existing resvg-py tooling, no app dependencies.

Run from repository root: python tools/render_starting_charging_assets.py
All geometry/data are synthetic teaching models documented in the R12 plan.
"""
from pathlib import Path
import render_obd_assets as svg
from render_obd_assets import label, line, box, dot, write, card

OUT = Path(__file__).resolve().parents[1] / 'assets/images/starting_charging'
svg.OUT = OUT
svg.SOURCE = OUT / 'source'


def chain(stem, title, context, nodes, footer):
    """Vertical wired diagram, with endpoints labelled independently of colour."""
    e = [label(16, 32, title, 22), label(16, 64, context)]
    y = 100
    for i, (name, detail) in enumerate(nodes):
        if i:
            e += [line(160, y-30, 160, y), label(174, y-8, '↓')]
        e += [box(20, y, 280, 60), label(30, y+24, name, 19), label(30, y+48, detail)]
        y += 90
    for row in footer:
        e.append(label(16, y, row))
        y += 28
    write(stem, y+12, e)


def main():
    svg.SOURCE.mkdir(parents=True, exist_ok=True)
    e = [label(16, 32, 'B1 • свинцовая АКБ', 22), label(16, 64, 'Условный разрез, не вскрывать'),
         label(16, 104, 'N (−)'), label(250, 104, 'P (+)'), line(42, 112, 42, 140), line(278, 112, 278, 140)]
    for n in range(6):
        x = 20 + n*48
        e += [box(x, 140, 40, 120), label(x+13, 166, str(n+1)), line(x+12, 180, x+12, 235), line(x+25, 180, x+25, 235)]
        if n < 5:
            e.append(line(x+40, 152, x+48, 152))
    e += [label(16, 292, '6 элементов последовательно'), label(16, 324, 'Пластины / сепараторы'),
          label(16, 356, 'Электролит участвует в реакции'), label(16, 404, 'Flooded / EFB: жидкость'),
          label(16, 436, 'AGM: стекловолоконный мат'), label(16, 480, '12 V — номинал системы'),
          label(16, 512, 'SOC ≠ SOH ≠ Ah ≠ CCA')]
    write('battery_structure', 536, e)
    card('battery_test_context', 'B2 • контекст проверки', ['Синтетика • +20 °C'], [
        ('Напряжение АКБ', 'Щупы на полюсах P / N'),
        ('Контакт под током', 'Полюс / клемма отдельно'),
        ('Одинаковое E покоя', '12,60 V у двух моделей'),
        ('Импульс 100 A: r=6 mΩ', 'U=12,00 V'),
        ('Импульс 100 A: r=12 mΩ', 'U=11,40 V'),
    ], ['Подготовка и температура', 'нужны до сравнения.', 'Не норматив CCA / SOH.'])
    chain('starter_power', 'S1 • силовая ветвь', 'Ток мотора: сверху вниз', [
        ('P • полюс АКБ+', 'Источник E, r внутри АКБ'),
        ('R+ • кабель и контакты', 'P → A'),
        ('A • вход 30', 'До контактов тягового реле'),
        ('K • силовые контакты', 'A → M, только при включении'),
        ('M → мотор → G', 'G — корпус стартера'),
        ('R− • возврат массы', 'G → N'),
        ('N • полюс АКБ−', 'Возврат к источнику'),
    ], ['Отдельно: управление 50.', 'Не замыкать силовые выводы.'])
    e = [label(16, 32, 'S2 • управление', 22), label(16, 64, 'Запрос ≠ разрешение ≠ ток')]
    for y, name, detail in [(100, 'Запрос START', 'Вход в ECU'), (220, 'Условия разрешения', 'P/N, сцепление, иммобилайзер'), (340, 'ECU: разрешение', 'Логика, не силовое питание')]:
        e += [box(16, y, 288, 68), label(26, y+26, name, 20), label(26, y+52, detail)]
        e.append(line(160, y+68, 160, y+120, stroke_dasharray='5 5'))
    e += [box(16, 460, 288, 70), label(26, 487, 'Реле / драйвер'), label(26, 514, 'Защищённое питание → S (50)'),
          line(160, 530, 160, 575), box(16, 575, 288, 68), label(26, 602, 'Тяговое реле'), label(26, 629, 'Управляет K в схеме S1'),
          label(16, 682, 'Опора U(S,G): корпус G'), label(16, 714, 'Логика: пунктир'), label(16, 746, 'Питание: сплошная линия'), label(16, 778, 'Блокировки не обходить.')]
    write('starter_control', 800, e)
    card('starter_drop_points', 'S3 • падения при START', ['Сначала красный щуп,', 'после косой черты — чёрный.', 'Один кадр • +20 °C • 200 A'], [
        ('P / A • плюсовой путь', 'S1 и G: +0,40 V'),
        ('A / M • контакты K', 'S1 и G: +0,20 V'),
        ('G / N • возврат', 'S1: +0,20 V; G: +1,20 V'),
        ('M / G • мотор', 'S1: 10,60 V; G: 9,60 V'),
        ('G / N • без START', '0 V не доказывает массу'),
    ], ['U(M,G)=V(M)−V(G)', 'Все потенциалы к N.', 'Ток после ремонта изменится.'])
    chain('alternator_structure', 'A1 • генератор', 'Механическая энергия → ток', [
        ('Ременной привод', 'Вращает ротор'),
        ('Ротор • магнитное поле', 'Возбуждение от регулятора'),
        ('Статор • три фазы', 'Переменное напряжение AC'),
        ('Диодный выпрямитель', 'AC → DC'),
        ('B+ / корпус', 'Выход к сети / возврат'),
    ], ['Регулятор меняет возбуждение.', 'Паспортный ток ≠ ток всегда.', 'Осмотр привода: остановить.'])
    e = [label(16, 32, 'A2 • зарядный контур', 22), label(16, 64, 'Условная схема C'),
         box(16, 100, 288, 62), label(28, 126, 'H • генератор B+'), label(28, 151, 'U(H,G) — выход'),
         line(160, 162, 160, 212), label(175, 193, 'Iген ↓'), box(16, 212, 288, 58), label(28, 237, 'Rc+ • H → P'), label(28, 261, 'Потеря U(H,P)>0'),
         line(160, 270, 160, 310), dot(160, 310), label(176, 317, 'P'),
         line(160, 310, 70, 310), line(70, 310, 70, 350), line(160, 310, 250, 310), line(250, 310, 250, 350),
         box(10, 350, 130, 72), label(20, 378, 'АКБ', 20), label(20, 404, '+I: заряд ↓'),
         box(170, 350, 140, 72), label(180, 378, 'Нагрузки', 20), label(180, 404, 'Iпотреб ↓'),
         line(70, 422, 70, 455), line(250, 422, 250, 455), line(70, 455, 250, 455), dot(160, 455), label(176, 482, 'N'),
         line(160, 455, 160, 510), box(16, 510, 288, 62), label(28, 536, 'Rc− • N → G'), label(28, 561, 'Потеря U(N,G)>0'),
         line(160, 572, 160, 615), box(16, 615, 288, 58), label(28, 643, 'G • корпус генератора'),
         label(16, 708, 'G соединён с источником H.'), label(16, 740, 'V(G) к N при зарядке < 0.'),
         label(16, 772, 'Iген = Iпотреб + IАКБ')]
    write('charging_power', 796, e)
    chain('charging_control', 'A3 • управление зарядкой', 'Пунктир: данные / команда', [
        ('IBS • датчик батареи', 'Ток, температура, U'),
        ('ECU • стратегия', 'SOC / нагрузка / режим'),
        ('Запрос регулятору', 'Связь зависит от модели'),
        ('Регулятор', 'Меняет возбуждение ротора'),
    ], ['Силовой путь — схема A2.', 'Локальный вариант:', 'уставку задаёт регулятор.', 'IBS нельзя обходить.', '14,4 V не обязательны всегда.'])
    # Mark these connections as data, not a second power circuit.
    source = svg.SOURCE / 'charging_control.svg'
    content = source.read_text(encoding='utf-8').replace('stroke-width="2"', 'stroke-width="2" stroke-dasharray="5 5"')
    source.write_text(content, encoding='utf-8')
    # Re-export source after style change, retaining the editable source as truth.
    import xml.etree.ElementTree as ET
    from resvg_py import svg_to_bytes
    tree = ET.fromstring(content)
    tree.set('width', '960'); tree.set('height', str(int(tree.attrib['height'])*3))
    (OUT/'charging_control.png').write_bytes(svg_to_bytes(svg_string=ET.tostring(tree, encoding='unicode')))
    # Two voltage traces: x maps t=0..3 s, y maps U=0..14 V.
    e = [label(16, 32, 'B • ответ на импульс', 22), label(16, 64, 'U полюсов, V • +20 °C'),
         line(50, 100, 50, 310), line(50, 310, 290, 310)]
    for v in [0, 7, 14]:
        y = 310-v*15
        e += [label(12, y+5, str(v)), line(50, y, 290, y, stroke_dasharray='3 4')]
    for ident, r, dash in [('battery6', .006, ''), ('battery12', .012, '7 4')]:
        values = [(0,12.6),(1,12.6),(1,12.6-100*r),(2,12.6-100*r),(2,12.6),(3,12.6)]
        pts = ' '.join(f'{50+t*80},{310-v*15}' for t,v in values)
        e.append(f'<polyline id="{ident}" points="{pts}" fill="none" stroke="#155b8a" stroke-width="3" stroke-dasharray="{dash}"/>')
    e += [label(44, 342, '0'), label(124, 342, '1'), label(204, 342, '2'), label(284, 342, '3'), label(118, 372, 't, s'),
          label(16, 412, '100 A только на [1,2) s'), label(16, 444, 'Сплошная: 6 mΩ → 12,00 V'), label(16, 476, 'Пунктир: 12 mΩ → 11,40 V'),
          label(16, 508, 'Линейная учебная модель'), label(16, 540, 'Не инструкция нагрузки.')]
    write('battery_pulse', 562, e)
    e = [label(16, 32, 'T0 / T1 • засыпание', 22), label(16, 64, 'Общий ток, A • +20 °C'),
         line(50, 100, 50, 340), line(50, 340, 290, 340)]
    for v in [0, 1, 2, 3, 4]:
        y=340-v*60
        e += [label(14,y+6,str(v)), line(50,y,290,y,stroke_dasharray='3 4')]
    for ident, extra, dash in [('T0',0,''),('T1',.8,'7 4')]:
        points=[(0,3+extra),(2,3+extra),(2,.6+extra),(10,.6+extra),(10,.15+extra),(30,.15+extra),(30,.03+extra),(40,.03+extra)]
        pts=' '.join(f'{50+t*6},{340-i*60}' for t,i in points)
        e.append(f'<polyline id="{ident}" points="{pts}" fill="none" stroke="#155b8a" stroke-width="3" stroke-dasharray="{dash}"/>')
    e += [label(44,370,'0'),label(104,370,'10'),label(224,370,'30'),label(276,370,'40'),label(120,404,'t, min'),
          label(16,446,'Сплошная T0: sleep 0,03 A'),label(16,478,'Пунктир T1: sleep 0,83 A'),label(16,510,'T1 = T0 + 0,80 A'),label(16,542,'Время условное, не норма.')]
    write('sleep_profiles', 564, e)
    e=[label(16,32,'T2 • повторный wake-up',22),label(16,64,'Общий ток, A • +20 °C'),line(50,100,50,340),line(50,340,290,340)]
    for v in [0,.75,1.5]:
        y=340-v*140
        e += [label(4,y+5,str(v).replace('.',',')),line(50,y,290,y,stroke_dasharray='3 4')]
    # Half-open [40,100): six 60-second pulses, plus baseline to endpoint.
    points=[]
    for t in range(40,100,10):
        points += [(t,.03),(t,1.5),(t+1,1.5),(t+1,.03)]
    points.append((100,.03))
    pts=' '.join(f'{50+(t-40)*4},{340-i*140}' for t,i in points)
    e.append(f'<polyline id="T2" points="{pts}" fill="none" stroke="#155b8a" stroke-width="2"/>')
    for t in [40,60,80,100]: e.append(label(50+(t-40)*4-10,374,str(t)))
    e += [label(116,408,'t, min'),label(16,450,'6 × 60 s по 1,50 A'),label(16,482,'54 min по 0,03 A'),label(16,514,'Средний ток: 0,177 A'),label(16,546,'База уже внутри 1,50 A.'),label(16,578,'Штатность: проверить OEM.')]
    write('wake_profile', 600, e)
    chain('parasitic_search', 'P1 • поиск потребления', 'Не изменять дефект измерением', [
        ('Состояние АКБ и условия', 'SOC / SOH / температура'),
        ('Общий ток во времени', 'Sleep / события / пики'),
        ('Выбор ветви по данным', 'Клещи / mV / схема'),
        ('Проверка причины', 'Команда / нагрузка / связь'),
        ('Контроль после ремонта', 'Повторный sleep и журнал'),
    ], ['Изоляция ветви ≠ диагноз.', 'Дверь может разбудить сеть.'])
    e=[label(16,32,'P • параллельные ветви',22),label(16,64,'Sleep • +20 °C • условно'),
       label(24,106,'P • АКБ+'),line(40,120,280,120),line(70,120,70,174),line(250,120,250,174),
       box(10,174,130,64),label(22,201,'Fq'),label(22,226,'Штатная'),box(172,174,138,64),label(184,201,'Fd'),label(184,226,'Доп. свет'),
       line(70,238,70,285),line(250,238,250,285),box(10,285,130,60),label(20,311,'Нагрузки'),label(20,336,'0,03 A'),box(172,285,138,60),label(182,311,'Светильник'),label(182,336,'0,80 A'),
       line(70,345,70,390),line(250,345,250,390),line(40,390,280,390),label(24,430,'N • АКБ−'),
       label(16,474,'Общий ток: 0,83 A'),label(16,506,'Площадки Fd: U=8,0 mV'),label(16,538,'Таблица Fd: только задача'),label(16,570,'После изоляции и sleep:'),label(16,602,'всего 0,03 A')]
    write('parasitic_branches', 626, e)
    chain('wake_network', 'W • сеть пробуждается', 'Силовая ветвь P → Fw → N', [
        ('Fw • телематика', 'В импульсе 0,50 A'),
        ('Связь с gateway', 'События по линии данных'),
        ('Другие блоки', 'В импульсе ещё 1,00 A'),
        ('Общий ток при wake-up', '0,50 + 1,00 = 1,50 A'),
    ], ['Между событиями: 0,03 A.', 'Стрелки — ход события,', 'не последовательная нагрузка.', 'Виновник требует проверки.'])
    card('meter_current_safety', 'P2 • выбор токового метода', ['Виртуальная карточка прибора'], [
        ('Только учебный прибор', '10 A: до 30 s'),
        ('Длительный предел', '3 A по его инструкции'),
        ('Пики неизвестны', 'Выбрать подходящие клещи'),
        ('A-вход поперёк АКБ', 'ЗАПРЕЩЕНО: замыкание'),
        ('START через мультиметр', 'ЗАПРЕЩЕНО: перегрузка'),
    ], ['Нет универсального лимита.', 'Разрыв питания меняет sleep.', 'Не шунтировать защиту.'])


if __name__ == '__main__':
    main()
