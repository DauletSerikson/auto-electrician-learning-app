"""R16 original SVG geometry and PNG. Existing resvg-py dev environment only.

PYTHONPATH=../electrician-r10/build/asset-tools python tools/render_safety_systems_assets.py
No vehicle pinouts, OEM graphics, actuation procedures or runtime dependencies.
"""
from pathlib import Path
from math import sin, cos, pi
import json
import render_body_electronics_assets as frame

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/images/safety_systems'
frame.OUT = OUT
frame.SOURCE = OUT/'source'
frame.CATALOG = {}
text, line, box, node, wire = frame.text, frame.line, frame.box, frame.node, frame.wire
write, process = frame.write, frame.process


def arrow(x,y,xx,yy):
    # Triangular direction marker on a functional connection, not a terminal.
    return line(x,y,xx,yy)+f'<path d="M{xx-4},{yy-8} L{xx+4},{yy-8} L{xx},{yy} Z" fill="#193b53"/>'


def rows_table(e, y, heading, labels, records, prefix):
    e.append(text(14,y,heading,18)); y+=34
    xs=[14,80,140,200,260]
    for x,label in zip(xs,labels): e.append(text(x,y,label,15))
    for k,(name,values,attrs) in enumerate(records):
        y+=34
        extra=' '.join(f'data-{key}="{value}"' for key,value in attrs.items())
        e.append(f'<g id="{prefix}-{k}" {extra}>')
        for x,value in zip(xs,[name,*values]): e.append(text(x,y,value,15))
        e.append('</g>')
    return y+45


def plot(e, y, title, points, end, low, high, unit, ident):
    e.append(text(14,y,title,17));y+=25
    x0,w,h=45,255,120
    for i in range(11):e.append(line(x0+i*w/10,y,x0+i*w/10,y+h,'#d5e2eb'))
    for i in range(9):e.append(line(x0,y+i*h/8,300,y+i*h/8,'#d5e2eb'))
    coords=' '.join(f'{x0+w*t/end:.6f},{y+h*(high-v)/(high-low):.6f}' for t,v in points)
    e.append(f'<polyline id="trace-{ident}" data-end="{end}" data-low="{low}" data-high="{high}" data-y="{y}" data-unit="{unit}" points="{coords}" fill="none" stroke="#17618b" stroke-width="2"/>')
    e += [text(5,y+7,f'{high:g}',13),text(5,y+h,f'{low:g}',13),text(45,y+h+23,'0',14),text(246,y+h+23,f'{end:g} ms',14)]
    return y+h+65


def pulse(end, low, high):
    pts=[(0,high)]
    for k in range(int(end/10)):
        pts.extend([(k*10+5,high),(k*10+5,low),((k+1)*10,low)])
        if (k+1)*10<end:pts.append(((k+1)*10,high))
    return pts


def main():
    e=[text(14,105,'Активная безопасность',19),box(20,125,280,52,'ABS / ESC'),
       text(22,210,'Помощь управлению'),text(22,238,'до столкновения.'),
       text(14,300,'Пассивная безопасность',19),box(20,320,280,52,'Ремни / SRS'),
       text(22,405,'Снижение последствий'),text(22,433,'при столкновении.')]
    write('safety_overview','Безопасность: разные роли',e,485,['SRS дополняет ремень.','Электроника связана с механикой/гидравликой.','Нет гарантии защиты при любых условиях.'])

    process('abs_arch','ABS • данные и давление',['Вращение четырёх колёс','Датчики → входы ECU','Оценка тенденции блокировки','Клапаны / насос','Давление → колёсный тормоз'],
            ['Верхние стрелки: информация.','Нижние: управление/результат.','Механика и сцепление важны.','Это функциональная цепочка, не процедура ремонта.'])

    e=[]
    for k,(mode,vi,vo) in enumerate([('Нарастание','open','closed'),('Удержание','closed','closed'),('Уменьшение','closed','open')]):
        y=110+k*200
        e.append(f'<g id="hydraulic-{k}" data-inlet="{vi}" data-outlet="{vo}">')
        e += [text(14,y,mode,19),text(14,y+32,'M → VI → W → VO → R',17),
              line(25,y+75,295,y+75),box(65,y+57,65,36,'VI'),box(187,y+57,65,36,'VO'),
              text(60,y+119,'открыт' if vi=='open' else 'закрыт',16),text(182,y+119,'открыт' if vo=='open' else 'закрыт',16)]
        for x,state in [(65,vi),(187,vo)]:
            if state=='closed': e.append(line(x+32,y+57,x+32,y+93,'#ad392f'))
        e.append('</g>')
    write('hydraulic_modes','H1 • фазы модуляции',e,730,['M — источник давления.','W — колёсный объём.','R — аккумулятор низкого давления.','Возвратный насос: R → M.','Нет слива наружу.','Состояние насоса задаёт контроллер, не эта таблица.'])

    e=['<circle cx="160" cy="180" r="58" fill="#eaf3f9" stroke="#193b53"/>']
    for k in range(48):
        a=2*pi*k/48
        e.append(line(round(160+58*cos(a),3),round(180+58*sin(a),3),round(160+68*cos(a),3),round(180+68*sin(a),3),extra=f'data-tooth="{k}"'))
    e += [box(252,153,45,55,''),text(250,240,'датчик',14),text(125,185,'48',22),
          wire(274,153,274,100,'coil','A'),node(274,100,'A'),wire(297,180,305,180,'coil','B'),wire(305,180,305,275,'B','B'),wire(305,275,290,275,'B','B'),node(290,275,'B'),
          text(18,320,'Изолированная обмотка A/B'),text(18,352,'Нет отдельного питания.')]
    write('passive_sensor','P1 • пассивный датчик',e,400,['48 зубьев → 48 волн/оборот.','125 rpm → 100 Hz.','uAB=4 sin(2π·100t) V.','A=4 V; Vpp=8 V.','Амплитуда 4 V — допущение.','Зазор/форма/нагрузка влияют на реальный сигнал.'])

    e=[]
    for k in range(96):
        a,b=2*pi*k/96,2*pi*(k+1)/96
        x1,y1=160+65*cos(a),175+65*sin(a)
        x2,y2=160+65*cos(b),175+65*sin(b)
        e.append(f'<path data-pole="{k}" d="M160,175 L{x1:.5f},{y1:.5f} A65,65 0 0,1 {x2:.5f},{y2:.5f} Z" fill="{"#aacbdc" if k%2 else "#284f70"}"/>')
    e += ['<circle cx="160" cy="175" r="37" fill="white"/>',text(125,180,'48 пар',17),
          text(14,280,'96 полюсов N/S, 1 цикл/пару'),text(14,315,'Петля A1: источник 12 V'),node(85,355,'S+',12),
          wire(85,355,85,385,'S+','sensor'),box(45,385,110,55,'датчик'),wire(85,440,85,470,'sensor','S-'),
          node(85,470,'S-',1.4,label='S−'),wire(85,470,85,510,'S-','Rs'),box(62,510,46,50,''),
          text(130,538,'Rs=100 Ω'),wire(85,560,85,595,'Rs','N'),node(85,595,'N',0),
          text(175,395,'i ↓ 7/14 mA',16),text(175,425,'к приёмнику',16)]
    write('active_sensor','A1 • токовый интерфейс',e,640,['S− не равно N.','UR low/high=0,7/1,4 V.','Uдатчика=11,3/10,6 V.','Rs — часть учебного приёмника, не совет ставить резистор.','Не универсальный стандарт ABS.'])

    e=[];y=105
    for title,a,f,name in [('P1: 125 rpm, V',4,100,'P1'),('P1-2: 250 rpm, V',8,200,'P1fast')]:
        pts=[(40*i/800,a*sin(2*pi*f*(40*i/800)/1000)) for i in range(801)]
        y=plot(e,y,title,pts,40,-8,8,'V',name)
    y=plot(e,y,'A1: 125 rpm, mA',pulse(40,7,14),40,0,16,'mA','A1current')
    y=plot(e,y,'A1: приёмник, V',pulse(40,.7,1.4),40,0,1.6,'V','A1receiver')
    write('sensor_signals','Разные физические величины',e,y,['Пассивный: разность A−B.','Активный: ток петли; напряжение только на Rs.','Удвоение амплитуды P1 задано моделью, не нормой.'])

    e=[]
    y=rows_table(e,105,'L0 / L1 • km/h, valid',['режим','FL','FR','RL','RR'],[
        ('покой',['0','0','0','0'],dict(fl=0,fr=0,rl=0,rr=0)),
        ('прямо',['30','30','30','30'],dict(fl=30,fr=30,rl=30,rr=30)),
        ('влево',['19,07','22,17','18,40','21,60'],dict(fl=19.0672494083,fr=22.1711524283,rl=18.4,rr=21.6)),
    ],'live')
    write('wheel_live_data','Четыре скорости колёс',e,y,['Одинаковая окружность 2 m.','Поворот: Rцентра=10 m,','колея 1,6 m; база 2,5 m.','Центр задней оси: 20 km/h.','Общие метки; без slip.','Разница на повороте ожидаема.'])

    process('esc_arch','ESC • сравнение движения',['Угол руля: запрос водителя','Скорости / рыскание / ay','ECU: сопоставление данных','Коррекция торможения','Запрос момента двигателю'],['Это функции, не точный OEM-алгоритм.','Действия зависят от условий.','Сцепление и физические пределы сохраняются.'])

    e=[box(130,130,60,110,'',fill='#e0eef6'),text(149,188,'авто',14),line(160,130,160,100),
       text(175,110,'x вперёд'),line(130,185,35,185),text(14,165,'y влево'),text(16,285,'z вверх; +r — влево'),
       text(16,330,'δSW — угол руля, не колеса'),text(16,375,'E1: 36 km/h = 10 m/s'),text(16,410,'r=0,20 rad/s=11,46 deg/s'),
       text(16,445,'ay≈v·r=2,00 m/s²')]
    write('esc_axes','E1 • оси и единицы',e,500,['Плоский установившийся режим без бокового slip.','Не диагностический порог.','У другого ECU знаки/оси могут быть иными.'])

    e=[box(20,105,280,55,'B+ → F → логика ABS'),box(20,195,280,55,'G → N: обратный путь'),
       box(20,285,280,55,'CAN ↔ другие ECU'),box(20,375,280,55,'Сообщение ≠ действие')]
    write('abs_network','Питание ≠ связь',e,475,['Карточки показывают разные пути.','Силовые ветви насоса/клапанов отдельны по схеме.','Потеря связи не доказывает отказ CAN.','Без pinout и принудительного включения.'])

    e=[box(20,105,280,55,'Данные события / пассажира'),
       arrow(160,160,160,195),box(20,195,280,55,'SRS: оценка условий'),
       line(160,250,160,280),line(85,280,235,280),arrow(85,280,85,315),arrow(235,280,235,415),
       box(15,315,140,65,'Защита'),box(165,415,140,65,'Диагностика'),
       box(15,525,290,55,'Функция резерва энергии')]
    write('srs_concept','S0 • только функции SRS',e,625,['Это смысловые связи функций.','Резерв относится к системе в целом.','Подушки дополняют ремни.','Нет проводов, точек подключения или процедур.'])

    e=[box(20,105,280,100,'Fault / readiness'),text(30,244,'Сообщает о неисправности'),
       box(20,295,280,100,'Passenger status'),text(30,434,'Сообщает статус пассажира')]
    write('indicators','Разные индикаторы',e,485,['Это условные карточки.','Не универсальные символы, цвета или тайминги.','Нужен owner manual.','Погасшая лампа не проверяет все механические узлы.'])

    e=[];y=rows_table(e,105,'K1 • остальные valid=30',['t, s','RL','статус'],[
        ('0,0',['30','valid'],dict(time=0,speed=30,valid='true')),('0,1',['30','valid'],dict(time=.1,speed=30,valid='true')),('0,2',['0*','invalid'],dict(time=.2,speed=0,valid='false')),
        ('0,3',['75','valid'],dict(time=.3,speed=75,valid='true')),('0,4',['30','valid'],dict(time=.4,speed=30,valid='true')),
    ],'case1')
    write('case_speed','K1 • тракт RL подозрителен',e,y,['*0 — placeholder, не остановка.','Прямо 30 km/h, без slip.','200–300 ms: ток постоянен 7 mA; UR=0,7 V.','Питание датчика 11,3 V.','Причина и raw→data неизвестны.'])

    e=[text(14,105,'25 оборотов, ECU ждёт Z=48')]
    for y,label,count in [(165,'до',1200),(275,'после',1100)]:
        e += [text(14,y,label),f'<rect id="events-{label}" data-count="{count}" x="65" y="{y-22}" width="{count/1200*225}" height="35" fill="#aacbdc"/>',
              text(85,y+5,str(count))]
    write('case_hub','K2 • события и обороты',e,365,['После: 1100/25=44 событий.','Это эффективное число, не доказанные 44 пары кольца.','6 s: 183,333 Hz → 27,5 km/h.','12 s: 91,667 Hz → 13,75 km/h.','Нужно различить детали, монтаж, пропуски и обработку.'])

    e=[];y=rows_table(e,105,'K3 • цифровые параметры',['режим','v','δSW','r','ay'],[
        ('покой',['0','0','6','0'],dict(v=0,steering=0,yaw=6,ay=0)),
        ('влево',['36','30','17,46','2'],dict(v=36,steering=30,yaw=17.46,ay=2)),
    ],'esc-record')
    write('case_esc','K3 • противоречие данных',e,y,['v: km/h; δSW: °; r: deg/s.','ay: m/s²; ax=0.','Общие метки, valid=true.','Калибровка не подтверждена.','Покой не согласуется с +6 deg/s.','Корреляция не называет неисправную деталь.'])

    e=[];y=rows_table(e,105,'K4 • синхронно, V',['окно','B+/N','P/N','G/N','P/G'],[
        ('до',['12,6','12,5','0,1','12,4'],dict(source=12.6,p=12.5,g=.1,local=12.4)),
        ('сбой',['12,6','8,6','0,1','8,5'],dict(source=12.6,p=8.6,g=.1,local=8.5)),
        ('после',['12,6','12,5','0,1','12,4'],dict(source=12.6,p=12.5,g=.1,local=12.4)),
    ],'power-record')
    write('case_communication','K4 • питание и связь',e,y,['P: вход питания ABS, G: возврат, N: минус источника.','Сбой: B+/P=4,0 V.','4,0+8,5+0,1=12,6 V.','Связь пропала в том же окне.','Ток и причина reset не заданы.','Нельзя приговорить CAN/ECU.'])

    e=[box(20,105,280,48,'Готовый отчёт специалиста'),text(18,205,'A: после ДТП'),text(18,238,'Запись события присутствует.'),
       text(18,271,'Есть текущая неисправность.'),text(18,333,'B: после работ салона'),text(18,366,'Occupant information:'),text(18,399,'текущая неисправность.')]
    write('case_srs','K5 • только сообщения',e,455,['Лампа fault остаётся ON.','Passenger status не подтверждён.','Состояние компонентов неизвестно.','Сохранить контекст/отчёт.','OEM-оценка специалистом.','Никаких измерений и reset ради погасшей лампы.'])

    (frame.SOURCE/'catalog.json').write_text(json.dumps(frame.CATALOG,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'README.md').write_text('''# Авторские иллюстрации модуля 13

17 оригинальных SVG в source/, PNG runtime ×3. Созданы инструментом
tools/render_safety_systems_assets.py с общими графическими helpers R15.
Не копируют OEM-рисунки, логотипы и pinout. Авторская геометрия/модели —
документация проекта, MIT. Каталог содержит только размеры, не ответы.
Проверенные источники принципов и допущения: docs/roadmap/R16_MODULE_13_PLAN.md.
Числа/дефекты синтетические, не замеры автомобиля и не нормы ремонта.
SRS изображена только функциональными блоками, без исполнительных цепей.
Белый непрозрачный фон, существенные условия дублируются Flutter captions.
Arial применяется локальным рендерером; файл шрифта не распространяется.
''',encoding='utf-8')
    print(f'{len(frame.CATALOG)} original SVG/PNG pairs')


if __name__=='__main__':main()
