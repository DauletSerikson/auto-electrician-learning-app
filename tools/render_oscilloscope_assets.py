"""Original R14 synthetic diagrams. Existing resvg-py dev tooling, no app package.

PYTHONPATH may point at the existing electrician-r10/build/asset-tools.
Time functions use milliseconds; each plot explicitly names its displayed unit.
"""
from pathlib import Path
from math import sin, pi, floor
from html import escape
import json
import textwrap
import xml.etree.ElementTree as ET
from resvg_py import svg_to_bytes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/images/oscilloscope'
SOURCE = OUT / 'source'
CATALOG = {}


def text(x, y, value, size=17, color='#122333'):
    return f'<text x="{x}" y="{y}" font-family="Arial" font-size="{size}" fill="{color}">{escape(str(value))}</text>'


def line(x1, y1, x2, y2, color='#abc1d0', width=1, extra=''):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}" {extra}/>'


def rows(e, y, values, size=17):
    for value in values:
        for row in textwrap.wrap(value, 29 if size == 17 else 24):
            e.append(text(16, y, row, size))
            y += 25
    return y


def samples(fn, end, count=800):
    return [(end*i/count, fn(end*i/count)) for i in range(count+1)]


def pulse(end, period=10, duty=.3, low=0, high=5, missing=None, phase=0):
    events = []
    for k in range(-1, int(end/period)+2):
        if k == missing:
            continue
        a = phase+k*period
        b = a+period*duty
        if 0 < a <= end:
            events += [(a, low), (a, high)]
        if 0 < b <= end:
            events += [(b, high), (b, low)]
    initial = high if phase == 0 and missing != 0 else low
    return [(0, initial)] + sorted(events, key=lambda p: p[0]) + [(end, events[-1][1] if events else initial)]


def hall(end, rpm):
    slot = 60000/rpm/12
    points = [(0, 5)]
    for k in range(int(end/slot)+1):
        if k % 12 == 11:
            continue
        start, stop = k*slot, k*slot+slot*.3
        if start > 0 and start <= end:
            points += [(start, 0), (start, 5)]
        if stop <= end:
            points += [(stop, 5), (stop, 0)]
    points += [(end, points[-1][1])]
    return points


def bits(end, bit_time, sequence, low, high):
    points = [(0, high if sequence[0] else low)]
    for i, bit in enumerate(sequence[1:], 1):
        t = i*bit_time
        if t > end:
            break
        previous = high if sequence[i-1] else low
        current = high if bit else low
        if current != previous:
            points += [(t, previous), (t, current)]
    return points+[(end, high if sequence[-1] else low)]


def plot(e, y, name, points, end, bottom, top, unit='ms', color='#155b8a'):
    # Geometry and units are attached to the actual visible polyline for audits.
    e.append(text(16, y, name, 18, color))
    y += 18
    x0, width, height = 46, 258, 160
    for i in range(11):
        e.append(line(x0+i*width/10, y, x0+i*width/10, y+height))
    for i in range(9):
        e.append(line(x0, y+i*height/8, 304, y+i*height/8))
    vdiv = (top-bottom)/8
    if bottom <= 0 <= top:
        z = y+height*(top/(top-bottom))
        e.append(line(x0, z, 304, z, '#566c7e', 1.5))
    coords = ' '.join(f'{x0+width*t/end:.5f},{y+height*(top-v)/(top-bottom):.5f}' for t,v in points)
    attrs = f'id="trace-{name.split()[0]}" data-window="{end}" data-unit="{unit}" data-reference="N" data-bottom="{bottom}" data-top="{top}" data-y="{y}" data-vdiv="{vdiv}"'
    e.append(f'<polyline {attrs} points="{coords}" fill="none" stroke="{color}" stroke-width="2.2"/>')
    e += [text(2, y+10, f'{top:g}', 12), text(2, y+height, f'{bottom:g}', 12), text(2, y-5, 'V', 12),
          text(x0, y+height+19, '0', 13), text(246, y+height+19, f'{end:g} {unit}', 13),
          text(16, y+height+45, f'{vdiv:g} V/div; {end/10:g} {unit}/div', 17)]
    return y+height+79


def graph(stem, title, panels, notes):
    e = []
    y = rows(e, 30, [title], 20)
    y = rows(e, y+2, ['Синтетическая модель', 'u относительно N = 0 V'])+18
    for panel in panels:
        y = plot(e, y, **panel)
    y = rows(e, y, notes)
    save(stem, y+15, e)


def save(stem, height, e):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="{height}" viewBox="0 0 320 {height}">\n<rect width="320" height="{height}" fill="white"/>\n'+ '\n'.join(e)+'\n</svg>\n'
    (SOURCE/f'{stem}.svg').write_text(svg, encoding='utf-8')
    root = ET.fromstring(svg)
    root.set('width', '960')
    root.set('height', str(height*3))
    (OUT/f'{stem}.png').write_bytes(svg_to_bytes(svg_string=ET.tostring(root, encoding='unicode')))
    CATALOG[stem] = [960, height*3]


def panel(name, points, end=40, bottom=-1.5, top=6.5, unit='ms', color='#155b8a'):
    return dict(name=name, points=points, end=end, bottom=bottom, top=top, unit=unit, color=color)


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    graph('instrument_compare', 'O01 • форма и среднее', [
        panel('PWM A', pulse(40)), panel('DC 1,5 V', [(0,1.5),(40,1.5)])],
        ['PWM: 0/5 V, 100 Hz, D=30%.', 'Средние равны: 1,5 V.', 'Это не одинаковые сигналы.'])

    e=[]
    y=rows(e,30,['O02 • общие земли'],20)
    y=rows(e,y+10,['Учебная схема: +12 V и N.', 'Зажимы A и B соединены', 'внутри прибора; PE связан', 'с общим. Это заданный тип.'])
    y+=25
    e += [line(50,y,270,y,'#155b8a',3), text(24,y-12,'+12 V'),
          line(50,y+150,270,y+150,'#155b8a',3),text(24,y+180,'N = 0 V'),
          line(240,y,240,y+150,'#b64726',4,'id="short-path"'),
          text(80,y+44,'зажим A → общий'),text(80,y+82,'общий → зажим B'),
          text(80,y+121,'КЗ через прибор!',18,'#b64726')]
    y=rows(e,y+225,['A на +12 V, B на N: нельзя.', 'Общие земли не подключают', 'к разным потенциалам.', 'PE не отключать. USB ≠', 'гарантия изоляции.'])
    save('common_ground',y+15,e)

    e=[]; y=rows(e,30,['O03 • разность A−B'],20)
    y=rows(e,y+8,['A и B — выводы датчика.', 'Нет общей точки с N:', 'нужен подходящий вход.'])
    e += [line(45,y+30,145,y+30,'#155b8a',3),line(45,y+110,145,y+110,'#b64726',3),
          text(20,y+25,'A'),text(20,y+105,'B'),
          f'<rect x="145" y="{y+5}" width="157" height="135" fill="#eaf3fa" stroke="#234b68"/>',
          text(158,y+37,'Дифф. вход'),text(158,y+72,'u = UA − UB'),text(158,y+109,'пределы?')]
    y=rows(e,y+195,['Допустимость определяется', 'паспортом комплекта.', 'CH1−CH2 не изолирует', 'общие земляные зажимы.', 'V/div не защищает вход.'])
    save('differential_input',y+15,e)

    sine=lambda t:4*sin(2*pi*t/10)
    graph('scale_axes','O04 • напряжение и время',[panel('S1 sine',samples(sine,40),bottom=-8,top=8)],
          ['A=4 V; Vpp=8 V; U0=0 V.', 'T=10 ms; f=100 Hz.', 'DC coupling; идеальный вход.'])
    graph('trigger_edges','O05 • фронты запуска',[panel('S3 PWM',pulse(40))],
          ['Уровень L=2,5 V:', 'рост 0→5 V; спад 5→0 V.', 'L=6 V не пересекается.', 'Нет события ≠ нет сигнала.'])
    graph('analog_ramp','O06 • плавное изменение',[panel('S2 ramp',samples(lambda t:1+3*t/100,100),end=100)],
          ['Питание датчика 5 V.', 'u=1+3t/100; t в ms.', '1→4 V за 100 ms.', 'Не период; T/f/D нет.'])
    graph('analog_noise','O07 • добавленная помеха',[panel('S2N zoom',samples(lambda t:2.5+.1*sin(2*pi*t),5),end=5,bottom=2.3,top=2.7)],
          ['Питание датчика 5 V.', 'U0=2,5 V; Aшума=0,1 V.', 'Период помехи 1 ms.', 'Источник шума не установлен.'])
    graph('missing_pulse','O08 • пропуск события',[panel('S4 pulse',pulse(40,missing=2))],
          ['Питание 5 V; u: 0/5 V.', 'Нет высокого: 20…23 ms.', 'Вне пропуска: 100 Hz, 30%.', 'У всей записи нет периода.'])
    graph('pwm_compare','O09 • ШИМ A и B',[panel('A PWM30',pulse(40)),panel('B PWM60',pulse(40,duty=.6),color='#b64726')],
          ['Оба: T=10 ms, 0/5 V.', 'A: tHigh=3 ms; D=30%.', 'B: tHigh=6 ms; D=60%.', 'Среднее: 1,5 V / 3 V.'])
    graph('inductive_speed','O10 • индуктивный датчик',[
        panel('A slow',samples(sine,40),bottom=-8,top=8),
        panel('B fast',samples(lambda t:8*sin(2*pi*t/5),40),bottom=-8,top=8,color='#b64726')],
        ['Здесь N — второй вывод B;', 'измеряется разность A−B.', '12 зубьев без пропуска;', 'скорость 500/1000 rpm.', 'A: 4 V, 100 Hz; B: 8 V,', '200 Hz. Условная модель;', 'амплитуда не универсальна.'])
    graph('hall_crank','O11 • учебный ДПКВ',[
        panel('A 600 rpm',hall(200,600),end=200),panel('B 1200 rpm',hall(200,1200),end=200,color='#b64726')],
        ['Hall, питание/pull-up 5 V.', '12 позиций, 1 без зуба.', 'Высокий: 30% позиции.', 'Опорный интервал длиннее.', 'Это не эталон всех моторов.'])
    graph('crank_cam','O12 • ДПКВ и ДПРВ',[
        panel('CKP 600 rpm',hall(200,600),end=200),
        panel('CMP 300 rpm',pulse(200,period=200,duty=.1,phase=25),end=200,color='#b64726')],
        ['Оба Hall 0/5 V к N.', 'CKP: 12−1, оборот 100 ms.', 'CMP: T=200 ms; high=20 ms.', 'CMP rising: 25 ms от начала', 'учебного цикла 720° CKP.', 'Фазы зависят от двигателя.'])
    low=[]
    for k in range(3):
        a=k*20
        if a>40:break
        if a>0: low += [(a,12),(a,0)]
        else:low=[(0,0)]
        if a+8<=40:low += [(a+8,0),(a+8,36),(a+8.5,36),(a+8.5,12)]
    low += [(40,0)]
    graph('actuator_low','O13 • ключ по минусу',[panel('Q to N',low,bottom=-5,top=75)],
          ['+12 V → катушка → Q → N.', 'R=12 Ω; L=24 mH.', 'ON 8 ms из 20 ms: 40%.', 'Q: 0 V ON; 36 V первые', '0,5 ms OFF, затем 12 V.', 'Clamp задан, не R/L solver.', 'Среднее Q=7,8 V; ток не дан.'])
    graph('actuator_high','O14 • ключ по плюсу',[panel('Load to N',pulse(40,period=20,duty=.4,high=12),bottom=-5,top=35)],
          ['+12 V → ключ → R=12 Ω → N.', 'Нагрузка резистивная.', '0/12 V; 50 Hz; DOn=40%.', 'Высокий=ON; среднее=4,8 V.', 'Выброс не моделируется.'])
    sequence=[0,0,1,1,0,1,0,0,1,1,1,0,1,0,0,0,1,0,1,0]
    for stem,title,delta in [('can_levels','O15 • HS-CAN уровни',1),('can_suspect','O17 • HS-CAN: сравнить',.5)]:
        # d=1 means dominant; sequence is a physical sketch, not a CAN frame.
        graph(stem,title,[panel('CANH',bits(40,2,sequence,2.5,2.5+delta),end=40,bottom=-1.5,top=6.5,unit='µs'),
            panel('CANL',bits(40,2,sequence,2.5,2.5-delta),end=40,bottom=-1.5,top=6.5,unit='µs',color='#b64726'),
            panel('H minus L',bits(40,2,sequence,0,2*delta),end=40,bottom=-1,top=3,unit='µs',color='#2a775b')],
            ['Питание PHY условно 5 V.', 'Общая N; два конца 120 Ω.', 'Бит 2 µs, 500 kbit/s.', f'Dominant: ΔU={2*delta:g} V.', 'Common-mode 2,5 V.', 'Не кадр; данные не декодируем.'])
    linseq=[1,1,0,0,0,1,0,1,1,0,1,0,1,1,1,0,0,1,0,1]
    for stem,title,low in [('lin_levels','O16 • LIN физика',0),('lin_suspect','O18 • LIN: сравнить',3)]:
        graph(stem,title,[panel('LIN to N',bits(2,.1,linseq,low,12),end=2,bottom=-4,top=16)],
              ['Питание/pull-up к 12 V.', f'Dominant {low:g} V; recessive 12 V.', 'Бит 100 µs, 10 kbit/s.', 'Произвольный набор битов,', 'не кадр LIN; периода нет.', 'Из формы не следует ECU.'])
    (SOURCE/'catalog.json').write_text(json.dumps(CATALOG,indent=2)+'\n',encoding='utf-8')
    print(f'{len(CATALOG)} SVG/PNG pairs')


if __name__ == '__main__':
    main()
