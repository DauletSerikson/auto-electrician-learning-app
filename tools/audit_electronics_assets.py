"""Audit SVG/PNG geometry and plotted signal parameters; development only.

Run from repository root with Pillow and Windows Arial fonts available.
This checks the actual exported plots, not a simulator or application code.
"""

from pathlib import Path
import math
import xml.etree.ElementTree as ET

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/images/electronics'
NS = {'s': 'http://www.w3.org/2000/svg'}


def close(actual, expected):
    assert math.isclose(actual, expected, abs_tol=1e-5), (actual, expected)


def points(stem, identifier):
    svg = ET.parse(ASSETS / 'source' / f'{stem}.svg').getroot()
    node = svg.find(f"s:polyline[@id='{identifier}']", NS)
    assert node is not None, identifier
    return [tuple(map(float, p.split(','))) for p in node.get('points').split()]


def pulse(stem, identifier, top, period, high, frequency, duty):
    # All signal plots use x=54..290 for 0..20 ms; y=top..top+130 for 5..0 V.
    data = points(stem, identifier)
    rises, falls = [], []
    for first, second in zip(data, data[1:]):
        if first[0] == second[0] and first[1] != second[1]:
            t = (first[0] - 54) * 20 / 236
            close(min(first[1], second[1]), top)
            close(max(first[1], second[1]), top + 130)
            (rises if second[1] < first[1] else falls).append(t)
    assert len(rises) >= 2
    assert len(rises) == len(falls)
    for a, b in zip(rises, rises[1:]): close(b-a, period)
    for a, b in zip(rises, falls): close(b-a, high)
    close(1000 / period, frequency)
    close(100 * high / period, duty)
    average = 5 * high / period
    print(f'{identifier}: T={period:g} ms, tH={high:g} ms, f={frequency:g} Hz, D={duty:g}%, ideal mean={average:g} V')


def main():
    labels = 0
    sources = sorted((ASSETS / 'source').glob('*.svg'))
    assert len(sources) == 11
    for source in sources:
        svg = ET.parse(source).getroot()
        width, height = (int(svg.get(key)) for key in ('width', 'height'))
        assert width == 320
        assert svg.get('viewBox') == f'0 0 320 {height}'
        for text in svg.findall('s:text', NS):
            size = int(text.get('font-size'))
            assert size >= 18
            filename = 'arialbd.ttf' if text.get('font-weight') == 'bold' else 'arial.ttf'
            font = ImageFont.truetype(f'C:/Windows/Fonts/{filename}', size)
            length = font.getlength(''.join(text.itertext()))
            x, y = float(text.get('x')), float(text.get('y'))
            anchor = text.get('text-anchor')
            left = x-length if anchor == 'end' else x-length/2 if anchor == 'middle' else x
            assert 0 <= left and left+length <= width, (source.name, text.text)
            assert size <= y <= height
            labels += 1
        with Image.open(ASSETS / f'{source.stem}.png') as png:
            png.load()
            assert png.size == (width*3, height*3)
            assert len(png.convert('RGB').getcolors(png.width * png.height)) > 10
    print(f'11 SVG/PNG pairs, {labels} labels: dimensions, decode and text bounds OK')
    pulse('pulse_frequency', 'pulse_100', 125, 10, 5, 100, 50)
    pulse('pulse_frequency', 'pulse_200', 432, 5, 2.5, 200, 50)
    for top, high, duty in [(145,2,20),(420,5,50),(695,8,80)]:
        pulse('pwm_duty', f'pwm_{duty}', top, 10, high, 100, duty)
    pulse('same_average', 'average_100', 415, 10, 5, 100, 50)
    pulse('same_average', 'average_200', 690, 5, 2.5, 200, 50)
    for x, y in points('same_average','constant_2_5'):
        assert 54 <= x <= 290
        close(y, 130+130/2)
    discrete = points('discrete_states', 'discrete_time')
    expected = [(0,5),(1,5),(1,0),(3,0),(3,5),(4,5)]
    assert len(discrete) == len(expected)
    for (x,y),(time,voltage) in zip(discrete, expected):
        close((x-54)*4/236, time)
        close((255-y)*5/130, voltage)
    for stem, name, top, xmax in [('analog_pressure_graph','pressure_transfer',130,100),
                                   ('analog_pressure_graph','analog_time',415,2)]:
        data = points(stem,name)
        assert len(data) >= 2
        for x,y in data:
            axis = (x-54)*xmax/236
            pressure = axis if xmax == 100 else 50*axis
            voltage = (top+130-y)*5/130
            close(voltage, .5+.04*pressure)
    close(5*6000/(2000+6000),3.75)
    close(5*500/(2000+500),1)
    close(5-.2,4.8)
    close(2.5+.2,2.7)
    print('Discrete active-low timing, analog axes/transfer and NTC/reference balances OK')


if __name__ == '__main__':
    main()
