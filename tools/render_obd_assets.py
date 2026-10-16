"""Original R11.2A SVG diagrams and 3x PNG; development tooling only.

Uses the existing resvg-py/Pillow environment; no Flutter dependency.
Run: python tools/render_obd_assets.py
"""
from html import escape
from pathlib import Path
import xml.etree.ElementTree as ET

from resvg_py import svg_to_bytes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/images/obd'
SOURCE = OUT / 'source'


def label(x, y, text, size=18, color='#122333', **attrs):
    extra = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<text x="{x}" y="{y}" font-family="Arial" font-size="{size}" fill="{color}" {extra}>{escape(text)}</text>'


def line(x1, y1, x2, y2, **attrs):
    extra = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#234b68" stroke-width="2" {extra}/>'


def box(x, y, width, height):
    return f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="6" fill="#eaf3fa" stroke="#234b68"/>'


def dot(x, y, **attrs):
    extra = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<circle cx="{x}" cy="{y}" r="4" fill="#155b8a" {extra}/>'


def write(stem, height, elements):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="{height}" viewBox="0 0 320 {height}">\n'
    svg += '<rect width="320" height="100%" fill="#ffffff"/>\n'
    svg += '\n'.join(elements) + '\n</svg>\n'
    (SOURCE / f'{stem}.svg').write_text(svg, encoding='utf-8')
    root = ET.fromstring(svg)
    root.set('width', '960')
    root.set('height', str(height * 3))
    (OUT / f'{stem}.png').write_bytes(svg_to_bytes(svg_string=ET.tostring(root, encoding='unicode')))
    print(stem, 960, height * 3)


def card(stem, title, context, rows, footer):
    elements = [label(16, 32, title, 22)]
    y = 65
    for text in context:
        elements.append(label(16, y, text))
        y += 27
    y += 8
    for i, (name, value) in enumerate(rows):
        elements.extend([box(12, y, 296, 61), label(22, y + 23, name), label(22, y + 48, value, 19)])
        y += 70
    y += 12
    for text in footer:
        elements.append(label(16, y, text))
        y += 27
    write(stem, y + 12, elements)


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    write('dtc_structure', 540, [
        label(16, 34, 'DTC: пример P0102', 22),
        label(16, 68, 'Не готовый диагноз'),
        box(16, 92, 288, 62), label(30, 132, 'P  |  0  1  0  2', 26),
        label(16, 188, 'P — силовой агрегат'), label(16, 220, 'B — кузов'),
        label(16, 252, 'C — шасси'), label(16, 284, 'U — сеть'),
        label(16, 330, 'Области SAE/OEM:'), label(16, 358, 'сверять по таблицам'),
        label(16, 386, 'и документации авто.'),
        line(22, 412, 298, 412), label(16, 447, 'Код → условия → проверка'),
        label(16, 482, 'Причину нужно подтвердить.'), label(16, 516, 'Авторская учебная схема'),
    ])
    common = ['Синтетические данные', 'Работает, ХХ, стоянка']
    card('freeze_a', 'FF-A • P0102', common + ['Бензиновый 1,6 L'], [
        ('Температура ECT', '88 °C'), ('RPM / скорость', '800 rpm / 0 km/h'),
        ('Расчётная нагрузка', '22%'), ('Напряжение ECU', '14,180 V'),
        ('MAP absolute', '36 kPa'), ('MAF / STFT / LTFT', 'N/A / N/A / N/A'),
    ], ['До текущего LD-C', 'Clock timestamp неизвестен', 'Поддержка полей — условие'])
    card('freeze_b', 'FF-B • P0171', common + ['Бензиновый 1,6 L, CL'], [
        ('Температура ECT', '90 °C'), ('RPM / скорость', '780 rpm / 0 km/h'),
        ('Расчётная нагрузка', '24%'), ('Напряжение ECU', '14,200 V'),
        ('MAP absolute / MAF', '42 kPa / 2,80 g/s'),
        ('STFT / LTFT, bank 1', '+18,8% / +12,5%'),
    ], ['Событие B до LD-A', 'Clock timestamp неизвестен', 'CL = closed loop'])
    card('freeze_c', 'FF-C • P0562', common + ['1,6 L; свет + вентилятор'], [
        ('Температура ECT', '90 °C'), ('RPM / скорость', '750 rpm / 0 km/h'),
        ('Расчётная нагрузка', '35%'), ('Напряжение ECU', '10,800 V'),
        ('MAP absolute', '40 kPa'), ('MAF / STFT / LTFT', 'N/A / N/A / N/A'),
    ], ['ECU работает по условию.', 'Clock timestamp неизвестен', 'Это не порог P0562.'])
    for stem, title, window, values in [
        ('live_a', 'LD-A • ХХ', 't приёма: 0…2 s', ['90 / 25 °C', '800 rpm / 0 km/h', '24%', '42 kPa', '2,80 g/s', '12,5%', '14,200 V', '+18,8 / +12,5%']),
        ('live_b', 'LD-B • без нагрузки', 't приёма: 30…32 s', ['91 / 26 °C', '2500 rpm / 0 km/h', '18%', '32 kPa', '8,20 g/s', '18,0%', '14,180 V', '+3,1 / +12,5%']),
    ]:
        names = ['05/0F: ECT / IAT', '0C/0D: RPM / скорость', '04: расчётная нагрузка', '0B: MAP absolute', '10: MAF', '11: дроссель', '42: напряжение ECU', '06/07: STFT / LTFT B1']
        card(stem, title, ['Синтетические данные', 'Бензиновый 1,6 L, CL', 'Стоянка; воздух 20 °C', window], list(zip(names, values)), ['Режим устойчив ≥10 s.', 'PID опрошены по очереди.', 'Поддержка полей — условие'])
    e = [label(16, 32, 'LD-A/B: две сводки', 22), label(16, 64, 'Стоянка, CL; синтетика')]
    for name, top, maximum, values, ticks in [
        ('RPM, rpm', 120, 3000, [800, 2500], [0, 1500, 3000]),
        ('STFT B1, %', 400, 25, [18.8, 3.1], [0, 12.5, 25]),
    ]:
        bottom = top + 140
        e.append(label(16, top - 20, name, 20))
        for tick in ticks:
            y = bottom - tick / maximum * 140
            e.extend([line(62, y, 294, y, stroke_dasharray='3 4'), label(8, y + 6, str(tick).replace('.', ','))])
        e.extend([line(62, top, 62, bottom), line(62, bottom, 294, bottom)])
        for time, value, window in zip([1, 31], values, ['A', 'B']):
            x = 62 + time / 32 * 232
            y = bottom - value / maximum * 140
            ident = ('rpm' if name.startswith('RPM') else 'stft') + window
            e.append(dot(x, y, id=ident))
            # Value annotations stay inside canvas at both ends.
            e.append(label(x + (6 if window == 'A' else -56), y - 12, str(value).replace('.', ',')))
        e.extend([label(58, bottom + 28, '0'), label(262, bottom + 28, '32'), label(68, bottom + 56, 't приёма, s')])
    e.extend([label(16, 632, 'Точки: центры окон 1/31 s.'), label(16, 660, 'Между окнами данных нет.'), label(16, 688, 'Линии не интерполируются.')])
    write('live_graphs', 712, e)
    write('maf_circuit', 810, [
        label(16, 30, 'K • аналоговый MAF', 22), label(16, 60, 'Синтетическая схема, 12 V'),
        label(174, 93, 'B+'), dot(160, 80), line(160, 80, 160, 110),
        box(40, 110, 240, 45), label(55, 138, 'Питающий путь'),
        line(160, 155, 160, 190), label(170, 180, 'P'),
        box(40, 190, 240, 90), label(70, 226, 'Датчик MAF'), label(60, 256, 'Выход S; возврат G'),
        dot(80, 280), label(44, 310, 'S'), line(80, 280, 80, 330),
        dot(80, 330), label(96, 337, 'X1'), line(80, 330, 80, 450, stroke_dasharray='6 4'),
        label(96, 383, 'W + оконцевания'), label(96, 412, 'Проверяемый путь'),
        dot(80, 450), label(96, 457, 'X2'), line(80, 450, 80, 490), label(44, 482, 'E'),
        box(40, 490, 240, 80), label(110, 520, 'ECU'), label(58, 550, 'E: слабая pull-down'),
        line(270, 280, 300, 280), line(300, 280, 300, 600), label(268, 310, 'G'),
        line(200, 570, 200, 600), line(40, 600, 300, 600), label(42, 630, 'B−: вывод АКБ'),
        label(16, 670, 'Пунктир — границы пути,'), label(16, 698, 'не место повреждения.'),
        label(16, 728, 'Возвраты/питание не идеальны.'),
        label(16, 756, 'ECU питается отдельно.'), label(16, 786, 'Точки измерений: S/G, E/G'),
    ])
    card('diagnostic_path', 'K • логика проверки', ['Последовательный разбор'], [
        ('1. Код и режим', 'Несколько гипотез'), ('2. Питание / масса', 'Под рабочей нагрузкой'),
        ('3. Сравнить S и E', 'Разные → разделить причины'), ('4. Изолировать W', 'OFF, нет напряжения'),
        ('5. W >1 MΩ, норма ≤1 Ω', 'Путь / оконцевания'), ('6. После ремонта', 'Повторить рабочий контроль'),
    ], ['Точная точка ещё неизвестна.', 'Нельзя заменить ECU по коду.'])


if __name__ == '__main__':
    main()
