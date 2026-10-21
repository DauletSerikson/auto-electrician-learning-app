"""R15 original schematic geometry; uses existing resvg-py development tooling.

PYTHONPATH=../electrician-r10/build/asset-tools python tools/render_body_electronics_assets.py
No vehicle pinouts, OEM artwork, application dependencies or circuit solver.
"""
from pathlib import Path
from html import escape
import json
import textwrap
import xml.etree.ElementTree as ET
from resvg_py import svg_to_bytes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/images/body_electronics'
SOURCE = OUT / 'source'
CATALOG = {}
INK = '#193b53'
BLUE = '#17618b'
RED = '#ad392f'


def text(x, y, value, size=17, color=INK):
    return f'<text x="{x}" y="{y}" font-family="Arial" font-size="{size}" fill="{color}">{escape(str(value))}</text>'


def line(x, y, xx, yy, color=INK, extra=''):
    return f'<line x1="{x}" y1="{y}" x2="{xx}" y2="{yy}" stroke="{color}" stroke-width="2" {extra}/>'


def box(x, y, w, h, label, fill='#eaf3f9'):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="5" fill="{fill}" stroke="{INK}"/>' + text(x+8, y+h/2+6, label)


def rows(e, y, values):
    for value in values:
        for row in textwrap.wrap(value, 30):
            e.append(text(14, y, row))
            y += 24
        y += 6
    return y


def node(x, y, name, voltage=None, label=None):
    attrs = f'id="node-{name}" data-node="{name}"'
    if voltage is not None:
        attrs += f' data-voltage="{voltage}"'
    return f'<circle cx="{x}" cy="{y}" r="4" fill="{BLUE}" {attrs}/>' + text(x+10, y-9, label or name)


def wire(x, y, xx, yy, a, b):
    return line(x, y, xx, yy, extra=f'data-from="{a}" data-to="{b}"')


def write(stem, title, e, bottom, notes):
    title_rows=textwrap.wrap(title,27)
    top = [text(14, 25+i*22, row, 19) for i,row in enumerate(title_rows)]
    top.append(text(14, 72, 'Авторская учебная схема', 16))
    height = rows(e, bottom, notes)+12
    src = (f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="{height}" '
           f'viewBox="0 0 320 {height}"><rect width="320" height="{height}" fill="white"/>'
           + ''.join(top+e)+'</svg>')
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE/f'{stem}.svg').write_text(src, encoding='utf-8')
    root=ET.fromstring(src)
    root.set('width','960')
    root.set('height',str(height*3))
    (OUT/f'{stem}.png').write_bytes(svg_to_bytes(svg_string=ET.tostring(root,encoding='unicode'), font_files=['C:/Windows/Fonts/arial.ttf']))
    CATALOG[stem] = [960, height*3]


def process(stem, title, steps, notes):
    e=[]; y=85
    for i, label in enumerate(steps):
        e.append(box(24,y,272,48,label))
        if i:
            e.append(line(160,y-20,160,y,extra='marker-end="url(#arrow)"'))
        y+=70
    e.insert(0,'<defs><marker id="arrow" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6" fill="#193b53"/></marker></defs>')
    write(stem,title,e,y+10,notes)


def lock(stem, faulty):
    e=[box(55,90,210,60,'Дверной мост'),node(90,180,'DA',12),node(230,180,'DB',0),
       wire(90,150,90,180,'bridge','DA'),wire(230,150,230,180,'bridge','DB')]
    if faulty:
        e += [wire(90,180,90,222,'DA','break'),wire(90,246,90,300,'break','A'),
              line(78,222,102,246,RED),line(78,246,102,222,RED),text(105,237,'обрыв',17,RED)]
    else:
        e.append(wire(90,180,90,300,'DA','A'))
    e += [wire(230,180,230,300,'DB','B'),node(90,300,'A',0 if faulty else 12),node(230,300,'B',0),
          wire(90,300,135,300,'A','motor'),wire(185,300,230,300,'motor','B'),
          '<circle cx="160" cy="300" r="25" fill="#eef6fb" stroke="#193b53"/>',text(151,306,'M',20),
          text(24,360,'B+ → F → VM; N = 0 V'),text(24,390,'LOCK: DA=12 V; DB=0 V')]
    write(stem,'K1 • обрыв ветви' if faulty else 'Дверной привод',e,430,
          ['Источник 12 V; LOCK 300 ms.','Окно записи 100–200 ms.',
           'A/B — выводы мотора.','DA/DB — выходы моста.',
           'I=0; U(DA,A)=12 V.' if faulty else 'LOCK: ток A → M → B.',
           'Механика ещё не проверена.' if faulty else 'UNLOCK: полярность обратная.'])


def bridge():
    e=[wire(60,100,260,100,'VM','VM'),wire(60,390,260,390,'N','N'),
       text(80,90,'B+ → F → VM = 12 V'),text(125,420,'N = 0 V')]
    for x,prefix in [(75,'A'),(245,'B')]:
        for y,name,start,end in [(150,'H',100,240),(320,'L',240,390)]:
            e += [wire(x,start,x,y-16,'VM' if name=='H' else prefix,'Q'+prefix+name),
                  wire(x,y+16,x,end,'Q'+prefix+name,prefix if name=='H' else 'N'),
                  box(x-18,y-16,36,32,'',fill='#fff0d2'),text(100 if x==75 else 185,y+6,'Q'+prefix+name,16)]
    e += [node(75,240,'A'),node(245,240,'B'),wire(75,240,133,240,'A','motor'),wire(187,240,245,240,'motor','B'),
          '<circle cx="160" cy="240" r="27" fill="white" stroke="#193b53"/>',text(150,247,'M',22)]
    for i,(state,closed,a,b) in enumerate([
        ('forward','QAH QBL',12,0),('reverse','QBH QAL',0,12),
        ('brakeLow','QAL QBL',0,0),('brakeHigh','QAH QBH',12,12),('coast','',None,None)]):
        values='не заданы' if a is None else f'A={a}, B={b}, U={a-b} V'
        e.append(f'<g id="state-{state}" data-closed="{closed}" data-a="{a}" data-b="{b}">'+text(14,460+i*28,values,17)+'</g>')
    write('h_bridge','M1 • полный мост',e,625,
          ['Ход A→B: QAH + QBL.','Ход B→A: QBH + QAL.','Торможение: QAL + QBL.','Hi-Z: все ключи открыты.',
           'В Hi-Z потенциалы не заданы.','Одна стойка: H и L вместе запрещены.','Это схема, не pinout драйвера.'])


def park(stem, faulty):
    e=[text(18,90,'Силовой путь: 12 V'),box(35,110,250,44,'B+ → F → выход → P'),
       line(160,154,160,185),box(85,185,150,44,'Мотор → N'),
       text(18,270,'Отдельный вход park: 5 V'),text(190,310,'+5 V'),line(230,318,230,344),
       box(210,344,40,42,'',fill='#fff0d2'),text(130,370,'10 kΩ'),line(230,386,230,420),node(230,420,'S',5 if faulty else 0),
       node(65,420,'K',0),line(65,420,65,480),line(65,480,65,510),line(65,510,100,510),
       text(108,515,'N; park замкнут'),text(18,560,'Kpark: контакт K → N')]
    if faulty:
        e += [wire(65,420,130,420,'K','break'),wire(155,420,230,420,'break','S'),
              line(130,408,155,432,RED),line(130,432,155,408,RED)]
    else:
        e.append(wire(65,420,230,420,'K','S'))
    write(stem,'K4 • сигнал не дошёл' if faulty else 'W1 • парковочный вход',e,600,
          ['В park: K=0 V.', 'S=5 V при обрыве K–S.' if faulty else 'Исправный провод: S=0 V.',
           'Вне park контакт открыт.','Классический самоподхват контактом — другая схема.',
           'Здесь OFF → ход до park.','Нет park → OFF через 2 s.','Тайм-аут задан моделью.'])


def blower():
    e=[text(18,95,'B+ 12 V → F → мотор'),line(160,108,160,145),box(100,145,120,50,'M'),
       line(160,195,160,230),node(160,230,'C',12),line(40,230,280,230)]
    for x,label,value in [(40,'LOW','1 Ω'),(160,'MED','0,5 Ω'),(280,'HIGH','обход')]:
        closed=label=='LOW'
        e += [line(x,230,x,275),text(max(10,x-25),260,label,15),
              line(x,275,x if closed else x+13,295,extra=f'id="selector-{label}" data-closed="{str(closed).lower()}"'),line(x,295,x,300)]
        if label!='HIGH':
            e += [box(x-17,300,34,50,''),text(max(10,x-20),380,value,16),line(x,350,x,410)]
        else:
            e += [line(x,300,x,540),text(225,390,'напрямую',14)]
    e += [line(40,410,160,410),line(100,410,100,455),
          line(100,455,100,475),line(88,475,112,495,RED),line(88,495,112,475,RED),
          line(100,495,100,540),text(120,485,'T: OL',18,RED),line(100,540,280,540),text(170,572,'N = 0 V')]
    write('blower_steps','K5 • ступени вентилятора',e,615,
          ['Показан LOW: MED/HIGH открыты.','Селектор замыкает только одну ветвь; OFF — разрыв.','LOW/MED: общий T разорван.','HIGH обходит R и T.',
           'LOW/MED: C=12 V, I=0.','HIGH: C=0 V, I=6 A.','T нельзя шунтировать.','Электронный регулятор — иная архитектура.'])


def lamp():
    e=[text(20,90,'K3 • постоянный свет, ON')]
    ys=[140,250,370,490]
    for name,y,v in [('B+',140,12),('P',250,11.7),('G',370,2.7),('N',490,0)]:
        e.append(node(75,y,name,v))
        e.append(text(175,y+7,f'{v:g} V'))
    for a,b,y,yy,r in [('B+','P',140,250,.1),('P','G',250,370,3),('G','N',370,490,.9)]:
        e += [wire(75,y,75,(y+yy)/2-15,a,'R'+b),wire(75,(y+yy)/2+15,75,yy,'R'+b,b),
              f'<rect id="resistor-{a}-{b}" data-resistance="{r}" x="62" y="{(y+yy)/2-15}" width="26" height="30" fill="#fff0d2" stroke="{INK}"/>',
              text(106,(y+yy)/2+5,f'{r:g} Ω')]
    write('case_lamp','K3 • потери обратного пути',e,535,
          ['B+ → F/реле → P → лампа → G → N.','F и реле включены, идеальны.','I=3 A; U(P,G)=9 V.',
           'Плюс: 0,3 V; масса: 2,7 V.','3 Ω — эквивалент нити в этой рабочей точке, не LED.',
           'OFF: G/N=0 при I=0.'])


def main():
    process('bcm_arch','B1 • управление функцией',['Кнопка / датчик','Вход BCM / запрос','Разрешения и логика','Драйвер / реле','Исполнительный узел','Обратная связь → вход'],
            ['B+ → Flogic → BCM.','B+ → Fpower → драйвер.','Массы обоих узлов → N.','Сеть не передаёт мощность мотору.'])
    process('bcm_io','Входы ≠ силовые выходы',['Контакт / 5-V датчик','Логический вход BCM','Решение + защита','High-side / low-side','Лампа / реле / мотор'],
            ['High-side: B+→ключ→нагрузка→N.','Low-side: B+→нагрузка→ключ→N.','Допустимость входа задаёт документация.'])
    lock('door_lock',False)
    bridge()
    e=[box(35,90,250,200,''),'<rect x="55" y="115" width="210" height="120" fill="#d9edf5" stroke="#193b53"/>',
       text(88,180,'СТЕКЛО'),line(155,250,155,330),text(170,310,'↑ / ↓'),box(90,330,140,45,'Мотор A/B')]
    write('window','Стеклоподъёмник',e,420,['Кнопка → дверной модуль → мост → мотор.','Датчик/оценка хода → модуль.','Препятствие ≠ только отказ мотора.',
          'Anti-pinch не отключают.','Проверка частью тела запрещена.','Положение и обучение зависят от конструкции.'])
    e=[]
    for y,label,path in [(100,'Релейный канал','Реле → лампа → G → N'),
                         (230,'High-side канал','Ключ → лампа → G → N'),
                         (360,'LED с драйвером','LED-драйвер → LED')]:
        e += [text(14,y,label,19),text(14,y+28,'Своё B+ → F →'),box(16,y+45,288,45,path)]
    write('lighting','Разные цепи освещения',e,495,
          ['Три независимые схемы.','Первые две: обычная лампа.','LED: возврат и управление определяет схема драйвера.',
           'Enable/PWM — команда, не обязательно мощность.','Критерии LED задаёт его схема.'])
    e=[text(16,95,'P1: ключ → R=6 Ω → N'),text(16,125,'Идеальный high-side, 12 V')]
    points=[]
    for n in range(4):
        x=45+n*62
        points += [(x,200),(x+24.8,200),(x+24.8,340),(x+62,340)]
        if n<3: points.append((x+62,200))
    e += [line(45,180,45,340),line(45,340,300,340),text(9,205,'12',14),text(20,344,'0',14),text(43,368,'0',14),text(260,368,'40 ms',14),
          '<polyline id="trace-P1" data-window-ms="40" data-low="0" data-high="12" data-period-ms="10" data-duty="0.4" points="'+ ' '.join(f'{x:g},{y:g}' for x,y in points)+'" fill="none" stroke="#17618b" stroke-width="3"/>']
    write('pwm_power','P1 • среднее и RMS',e,410,['ON 4 ms / T=10 ms; 100 Hz.','DOn=DHigh=40%.','Среднее 4,8 V; RMS 7,59 V.','Pср=9,6 W на резисторе.',
          'Это не динамика мотора.','SCOPE1 отдельно: 0/5 V, 30%, среднее 1,5 V.'])
    park('wiper_park',False)
    process('mirror_seat','Одна ось привода',['Переключатель / память','Цель положения → модуль','Мост → A/B двигателя','Датчик → обратная связь'],
            ['Другие оси имеют свои цепи.','Нет постоянной массы мотора.','Ход и ток ограничиваются.','SRS / присутствие пассажира исключены из измерений.'])
    process('hvac_flap','HVAC • привод заслонки',['Температура → контроллер','Цель положения → драйвер','Мотор → заслонка','Датчик 0–5 V → HVAC'],
            ['Здесь линейный датчик: 2,5 V — 50% диапазона.','Не универсальные 50% угла.','Ступенчатый / LIN-привод — иные конструкции.'])
    blower()
    process('network','N1 • запрос и действие',['Кнопка → локальный ECU','CAN ↔ BCM','LIN ↔ локальный узел','Выход → механизм','Обратная связь → ECU'],
            ['Стрелки CAN/LIN — информация.','Питание мотору идёт отдельно.','Типовая модель, не карта всех машин.','Запрос ≠ разрешение ≠ действие.'])
    lock('case_lock',True)
    e=[]
    for y,title,a,b,current in [(95,'DOWN: движение',12,0,2),(300,'UP: движения нет',0,0,0)]:
        e += [text(16,y,title,19),node(45,y+65,'A-'+str(y),a,label='A'),node(270,y+65,'B-'+str(y),b,label='B'),line(45,y+65,125,y+65),
              box(125,y+40,70,50,'M'),line(195,y+65,270,y+65),text(30,y+110,f'A/N={a} V; B/N={b} V'),text(30,y+145,f'U(A,B)={a-b} V; I={current} A')]
    write('case_window','K2 • только одно направление',e,510,['VM=12 V; запрос UP принят.','Окно 100–200 ms после команды.','0/0 V не даёт единственный диагноз.',
          'Нужны разрешения, защита, ранняя запись U и тока.'])
    lamp()
    park('case_park',True)
    (SOURCE/'catalog.json').write_text(json.dumps(CATALOG,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'README.md').write_text('''# Авторские схемы модуля 12

16 SVG originals в source/, PNG runtime ×3. Геометрия создана для проекта
tools/render_body_electronics_assets.py; рендер существующим resvg-py dev tool.
Сторонние схемы, изображения и логотипы не копировались. Авторский вклад —
схемы/композиции и учебные модели, MIT как документация проекта.
Arial используется локальным рендерером, файл шрифта не распространяется.

Это условные узлы, не OEM-pinout. Источники принципов и применимость:
docs/roadmap/R15_MODULE_12_PLAN.md §10. Все числа и дефекты — синтетические.
Схемы не являются инструкцией подключения к автомобилю.
PNG имеет непрозрачный белый фон для обеих тем; существенные условия
повторены в Flutter captions. Catalog хранит только размеры, не ответы.
''',encoding='utf-8')
    print(f'{len(CATALOG)} original SVG/PNG pairs')


if __name__=='__main__': main()
