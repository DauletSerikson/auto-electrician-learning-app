"""Author original R13 educational SVG and 3x PNG using existing dev tooling.

Run in the existing resvg-py environment; no application dependency changes.
Geometry is schematic, not a fabrication drawing. See artwork README/plan.
"""
from pathlib import Path
from math import cos, sin, pi
import render_obd_assets as svg
from render_obd_assets import label, line, box, dot, write

OUT = Path(__file__).resolve().parents[1] / 'assets/images/wiring_repair'
svg.OUT = OUT
svg.SOURCE = OUT / 'source'


def line(x1, y1, x2, y2, **attrs):
    values = {'stroke': '#234b68', 'stroke-width': 2}
    values.update({k.replace('_', '-'): v for k, v in attrs.items()})
    extra = ' '.join(f'{k}="{v}"' for k, v in values.items())
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" {extra}/>'


def circle(x, y, radius, fill='#bf783f', **attrs):
    extra=' '.join(f'{k.replace("_", "-")}="{v}"' for k,v in attrs.items())
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="#234b68" {extra}/>'


def poly(points, **attrs):
    values={'fill':'none','stroke':'#234b68','stroke-width':3}
    values.update({k.replace('_','-'):v for k,v in attrs.items()})
    extra=' '.join(f'{k}="{v}"' for k,v in values.items())
    return f'<polyline points="{points}" {extra}/>'


def title(text, subtitle):
    return [label(16,32,text,21),label(16,64,subtitle,17)]


def footer(e, y, rows):
    for text in rows:
        e.append(label(16,y,text,18))
        y+=28
    return y+12


def process(stem, heading, rows, notes):
    e=title(heading,'Авторская учебная схема')
    y=100
    for a,b in rows:
        e += [box(16,y,288,64),label(26,y+25,a,19),label(26,y+50,b,17)]
        if y>100: e += [line(160,y-26,160,y),label(173,y-7,'↓')]
        y+=90
    write(stem,footer(e,y+4,notes),e)


def series(stem, heading, supply, nodes, contact, current, readings, after):
    """Connected loop with an explicit return rail; machine-readable node IDs."""
    e=title(heading,'ON • +20 °C • условные R')
    e += [label(16,100,supply,19),label(16,130,current,18)]
    x=95; ys=[180+i*110 for i in range(len(nodes))]
    for i,(node,detail) in enumerate(nodes):
        y=ys[i]
        if i: e += [line(x,ys[i-1],x,y)]
        e += [dot(x,y,id=f'node-{node}',data_node=node),label(22,y+7,node,20),
              box(112,y-23,190,61),label(122,y+2,detail[0],18),label(122,y+26,detail[1],17)]
        # Topology ID is attached to the actual drawn segment, not hidden JSON.
        if i and nodes[i-1][0]+node==contact:
            e += [label(48,y-50,'Rк',18),
                  f'<rect id="contact-{contact}" x="{x-9}" y="{y-73}" width="18" height="36" fill="#ffe3bb" stroke="#234b68" stroke-width="2"/>']
        elif i:
            edge = nodes[i-1][0]+node
            e += [label(42,y-50,'Rп' if node=='B' else 'Rн',18),
                  f'<rect id="resistor-{edge}" x="{x-9}" y="{y-73}" width="18" height="36" fill="#eaf3fa" stroke="#234b68" stroke-width="2"/>']
    bottom=ys[-1]+65
    e += [poly(f'{x},{ys[-1]} {x},{bottom} 8,{bottom} 8,240',id='return-negative'),
          poly(f'8,210 8,156 {x},156 {x},{ys[0]}',id='return-positive'),
          line(0,210,22,210,id='source-plus'),line(3,240,13,240,id='source-minus'),
          label(18,bottom+30,'N=0 V • общий возврат',18)]
    y=footer(e,bottom+66,readings)
    e += [box(12,y,296,90),label(22,y+25,'После ремонта',19),label(22,y+52,after[0],17),label(22,y+77,after[1],17)]
    write(stem,y+110,e)


def main():
    svg.SOURCE.mkdir(parents=True,exist_ok=True)
    e=title('W01 • устройство провода','Схематично • не в масштабе')
    e += [box(28,110,264,70),'<rect x="28" y="122" width="175" height="46" fill="#c5dff3" stroke="#234b68"/>']
    for yy in [130,141,152,163]:
        e += [line(44,yy,275,yy,stroke='#a65d22',stroke_width='4')]
    e += [line(128,180,128,216),label(30,244,'Изоляция разделяет цепи',19),
          line(252,169,252,270),label(30,300,'Жила передаёт ток',19),
          circle(160,410,64,'#c5dff3')]
    for k in range(7):
        x,y=(160,410) if k==0 else (160+30*cos((k-1)*pi/3),410+30*sin((k-1)*pi/3))
        e += [circle(round(x,2),round(y,2),14,data_strand=k)]
    h=footer(e,510,['Отдельные проволоки жилы','не являются изоляцией.','Медь — выбранный материал.'])
    write('wire_anatomy',h,e)

    e=title('W02 • площадь и жгут','A — металл, без изоляции')
    e += [circle(82,145,48,'#c5dff3')]
    for k in range(7):
        x,y=(82,145) if k==0 else (82+23*cos((k-1)*pi/3),145+23*sin((k-1)*pi/3))
        e += [circle(round(x,2),round(y,2),10,data_strand=k)]
    e += [label(150,140,'A = Σ Aᵢ',21),label(150,170,'Aᵢ = πdᵢ²/4',18),
          label(16,224,'Наружный диаметр ≠ A',19),box(22,274,276,114)]
    for yy in [297,325,353]:
        e += [line(30,yy,290,yy,stroke='#3979a5',stroke_width='8')]
    e += ['<rect x="145" y="267" width="28" height="129" rx="4" fill="#e3d9b5" stroke="#234b68"/>',
          line(159,396,159,430),label(24,460,'Клипса удерживает маршрут',18)]
    write('strand_area_harness',footer(e,505,['Оболочка защищает группу.','Жилы — отдельные цепи.']),e)

    e=title('W03 • полный путь тока','Медь • +20 °C • A=1,5 mm²')
    e += [poly('56,130 264,130 264,350 56,350 56,130'),
          '<rect x="225" y="204" width="78" height="72" fill="#eaf3fa" stroke="#234b68"/>',
          label(236,233,'Rload',17),label(236,259,'Q → T',16),
          '<rect x="22" y="203" width="70" height="74" fill="#fff2cd" stroke="#234b68"/>',
          label(29,232,'12,60',17),label(46,258,'V',17)]
    for node,x,y in [('P',56,130),('Q',264,130),('T',264,350),('N',56,350)]:
        e += [dot(x,y,id=f'node-{node}'),label(x-7,y-13,node,19)]
    e += [label(101,113,'3 m →',18),label(101,387,'← 3 m',18)]
    write('length_area_resistance',footer(e,429,['Rpath = 0,06896 Ω','I = 5 A • ΔU = 0,3448 V','Pпроводов = 1,724 W','Нагрузка: 2,45104 Ω','Возврат задан проводом.']),e)

    e=title('W04 • разъём','Условный продольный разрез')
    e += [box(38,110,246,155),box(91,155,160,47),
          line(251,178,305,178,stroke='#a65d22',stroke_width='6'),
          '<rect x="263" y="147" width="17" height="62" rx="5" fill="#a8d9c5" stroke="#234b68"/>',
          poly('110,155 125,138 153,138 153,155'),box(164,116,21,45),
          label(16,310,'Корпус: ключ и cavities',18),label(16,341,'Terminal: контактная пара',18),
          label(16,372,'Первичный фиксатор',18),label(16,403,'Вторичная фиксация',18),label(16,434,'Seal: путь влаги',18)]
    # Leader lines tie labels to distinct actual parts.
    for x,y,end in [(48,245,302),(112,178,333),(128,139,364),(175,125,395),(273,209,426)]:
        e += [poly(f'{x},{y} 10,{y} 10,{end}')]
    write('connector_anatomy',footer(e,484,['Замок корпуса отдельно','удерживает половины.','Вид зависит от системы.']),e)

    e=title('W05 • зоны терминала','От контакта к проводу')
    e += [box(24,130,88,48),box(112,130,75,48),box(187,130,75,48),line(262,154,304,154,stroke_width='7'),
          label(33,160,'Контакт',17),label(124,160,'Жила',17),label(195,160,'Изол.',17)]
    e += [label(16,224,'1. Сопряжение пары',19),label(16,256,'2. Обжим проводника',19),label(16,288,'3. Поддержка изоляции',19)]
    e += [box(26,338,108,54),poly('32,365 60,365 60,356 114,356'),
          line(176,362,261,362,stroke='#2a775b',stroke_width='3'),label(147,414,'Адаптер по допуску',17)]
    write('terminal_and_probe',footer(e,470,['Толстый щуп не вдавливать.','Не разжимать гнездо.','Pin view нужно сверить.']),e)

    e=title('W06 • критерии обжима','Зоны: продольная схема')
    for y,good in [(130,True),(290,False)]:
        e += [poly(f'44,{y+4} 162,{y+4} 162,{y+45} 44,{y+45} 44,{y+4}'),
              '<rect x="173" y="%s" width="118" height="42" fill="#c5dff3" stroke="#234b68"/>'%(y+5)]
        for k in range(3):
            e += [line(64,y+15+k*8,205,y+15+k*8,stroke='#a65d22',stroke_width='4')]
        if not good:
            e += ['<rect x="113" y="%s" width="80" height="42" fill="#c5dff3" stroke="#234b68"/>'%(y+5),
                  poly(f'70,{y+11} 90,{y-14} 156,{y-14}',stroke='#a65d22')]
        e += [label(16,y-24,'Критерии соблюдены' if good else 'Дефекты показаны явно',19),
              label(16,y+83,'Все проволоки внутри' if good else 'Проволока снаружи',18),
              label(16,y+110,'Изоляция вне зоны жилы' if good else 'Изоляция в зоне жилы',18)]
    write('crimp_criteria',footer(e,468,['Не допуск по фотографии.','Высота / усилие —','по спецификации изделия.']),e)

    e=title('W07 • splice и разгрузка','Принцип, не рецепт монтажа')
    e += [line(24,152,296,152,stroke='#a65d22',stroke_width='8'),box(115,132,90,40),
          '<rect x="82" y="114" width="154" height="76" rx="10" fill="#8cc7dc" fill-opacity=".45" stroke="#234b68"/>',
          label(16,233,'Гильза: электрический путь',18),label(16,267,'Оболочка: защита',18),
          line(42,306,282,306),'<rect x="45" y="294" width="22" height="25" fill="#dbcda8"/>',
          '<rect x="258" y="294" width="22" height="25" fill="#dbcda8"/>',
          label(16,354,'Крепление без натяжения',18)]
    write('splice_strain_relief',footer(e,410,['Не в зоне постоянного изгиба.','Припой может создать','жёсткий переход.','Метод — по процедуре.']),e)

    process('protection_layers','W08 • слои защиты',[
        ('Изоляция соединения','Не контакт металла с кузовом'),('Seal / клеевой слой','Влага: по заданной системе'),
        ('Оболочка жгута','Трение и организация'),('Клипса / штатный маршрут','Без кромок и натяжения')],
        ['Не запечатывать воду.','Сохранить штатный дренаж.'])

    e=title('W09 • разные повреждения','Сначала гипотеза, потом тест')
    e += [line(25,126,120,126,stroke_width='6'),line(153,126,296,126,stroke_width='6'),label(16,167,'Обрыв: нет полного пути',18),
          line(25,226,296,226,stroke_width='7'),poly('128,226 128,268 250,268'),label(16,306,'Перетирание: риск касания',18),
          box(65,355,194,48)]
    for xx,yy in [(110,375),(150,387),(202,369)]: e += [circle(xx,yy,8,'#6d9d68')]
    e += [label(16,442,'Коррозия: осмотр + данные',18)]
    write('harness_damage',footer(e,490,['Цвет не задаёт R.','Срабатывание F ≠ место КЗ.']),e)

    e=title('C2 • прерывание A–B','5 V reference • запись ON')
    e += [poly('42,130 276,130 276,305 42,305 42,130'),box(18,197,48,45),label(24,225,'5 V',17),box(232,192,70,54),label(237,223,'249 Ω',17),
          box(113,110,88,40),label(122,136,'A–B',19)]
    for node,x,y in [('P',42,130),('Q',276,130),('G',276,305),('N',42,305)]:
        e += [dot(x,y,id=f'node-{node}'),label(x-8,y-14,node,19)]
    e += [label(65,174,'R(A,B)=1 Ω / обрыв',17),label(57,278,'N / G = 0 V',18),
          label(16,356,'P=5 V в обеих фазах',19),label(16,389,'Q=4,98 V / 0 V',19),
          label(16,422,'I=20 mA / 0 A',19),line(20,450,300,450),label(16,484,'Отдельный тест Ω:',19),
          poly('46,542 116,542 147,526'),poly('175,542 269,542'),dot(46,542,id='isolated-A'),dot(269,542,id='isolated-B'),
          label(30,573,'A',19),label(259,573,'B',19)]
    write('open_localization',footer(e,620,['Питание снято и проверено.','Оба конца изолированы.','1 Ω / OL • S не задан.']),e)

    process('repair_verification','W11 • восстановление',[
        ('Допуск и объём','Документация / осмотр'),('Провод / terminal / tool','Совместимость комплекта'),
        ('Место / защита / маршрут','Без натяжения и воды'),('Контроль под нагрузкой','Функция + посадка + запись')],
        ['БИП не доказывает ресурс.','Без допуска — остановиться.'])

    series('headlamp_contact','C1 • фара и контакт','Us=12,60 V • F идеален',[
        ('A',('До Rwire','12,60 V к N')),('B',('После 0,05 Ω','12,40 V к N')),
        ('C',('После X1: 0,55 Ω','10,20 V к N')),('D',('После фары 2,55 Ω','0 V к N'))],
        'BC','I=4 A • возврат идеальный',
        ['Красный B / чёрный C','U(B,C)=+2,20 V','P(X1)=8,80 W ≠ температура'],['R(X1)=0,005 Ω','I≈4,837 A • Uк≈0,0242 V'])
    series('wet_ground_connector','C3 • контакт возврата','Us=12 V • источник идеален',[
        ('A',('До нагрузки','12,00 V к N')),('T',('После 5,20 Ω','1,60 V к N')),
        ('N',('После X3: 0,80 Ω','0 V • возврат'))],
        'TN','ON • I=2 A',
        ['Красный T / чёрный N','U(T,N)=+1,60 V','P(X3)=3,20 W','OFF: 0 V не доказывает','массу под рабочим током.'],['R(X3)=0,020 Ω','I≈2,299 A • Uк≈0,0460 V'])

    e=title('C4 • повреждение изоляции','Две отдельные схемы')
    e += [label(16,108,'F открыт • рабочий I=0 A',18),poly('44,146 118,146 137,132'),poly('160,146 276,146 276,290 44,290 44,146'),
          box(239,206,61,46),label(245,235,'3 Ω',18),box(19,217,50,40),label(23,243,'12 V',16),dot(44,146,id='node-P'),label(27,132,'P',18),
          dot(190,146,id='node-A'),label(184,132,'A',18),dot(276,179,id='node-C'),label(281,177,'C',18),
          label(67,277,'N • 0 V',17),label(61,183,'P=12 V',17),label(61,214,'A/C=0 V',17),
          line(18,322,302,322),label(16,358,'Изолированная ветвь A–C',18),
          line(44,405,270,405),line(44,485,270,485),line(170,405,170,485,stroke_dasharray='5 5'),
          dot(44,405,id='isolated-A'),dot(270,405,id='isolated-C'),label(29,390,'A',18),label(262,390,'C',18),label(27,516,'N / кромка',18)]
    write('abrasion_isolation',footer(e,557,['Питание снято и проверено.','F, нагрузка, модули сняты.','C/N: 0,4 Ω при касании;','OL вне касания (>20 MΩ).','Ток / время КЗ не заданы.']),e)
    series('bad_splice_heating','C5 • дефектный splice','Us=12 V • Rwire=0,05 Ω',[
        ('A',('До splice','11,80 V к N')),('B',('После 0,25 Ω','10,80 V к N')),
        ('N',('После 2,70 Ω','0 V • возврат'))],
        'AB','ON • I=4 A',
        ['Красный A / чёрный B','U(A,B)=+1,00 V','P(splice)=4,00 W','Температура не определена.'],['Rsplice=0,010 Ω','I≈4,348 A • Pк≈0,189 W'])


if __name__ == '__main__':
    main()
