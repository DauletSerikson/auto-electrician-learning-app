"""Read-only R11 pilot scope, original diagram geometry and APK audit.

Run from repo root; Pillow is existing development tooling, not an app dependency.
Optional: python tools/audit_obd_pilot.py --apk path/to/app-debug.apk
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/images/obd'
NS = {'s': 'http://www.w3.org/2000/svg'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk')
    args = parser.parse_args()
    sources = sorted((ASSETS / 'source').glob('*.svg'))
    assert len(sources) == 9
    labels = 0
    for source in sources:
        root = ET.parse(source).getroot()
        width, height = int(root.get('width')), int(root.get('height'))
        assert width == 320 and root.get('viewBox') == f'0 0 320 {height}'
        for text in root.findall('s:text', NS):
            size = int(text.get('font-size'))
            assert size >= 18
            font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size)
            x, y = float(text.get('x')), float(text.get('y'))
            length = font.getlength(text.text or '')
            assert 0 <= x and x + length <= width, (source.name, text.text, x + length)
            assert size <= y <= height
            labels += 1
        with Image.open(ASSETS / f'{source.stem}.png') as image:
            image.load()
            assert image.size == (3 * width, 3 * height)
    # All previously tracked course assets, production Dart, old tests and
    # lock must preserve Git's normalized content, independent of timestamps.
    protected = git('ls-tree', '-r', '--name-only', 'a2c7f46', '--', 'assets', 'lib', 'test', 'pubspec.lock').splitlines()
    for path in protected:
        assert git('hash-object', f'--path={path}', path) == git('rev-parse', f'a2c7f46:{path}'), path
    lessons = [json.loads((ROOT / f'assets/course/stage_7/lesson_{n:02}.json').read_text(encoding='utf-8')) for n in (4, 6, 7, 9)]
    # Independently reviewed display values: prevent source cards from drifting
    # away from FF/LD conditions even if rendering/dimensions still succeed.
    for stem, values in {
        'freeze_a': ['88 °C', '800 rpm / 0 km/h', '22%', '14,180 V', '36 kPa', 'N/A / N/A / N/A'],
        'freeze_b': ['90 °C', '780 rpm / 0 km/h', '24%', '14,200 V', '42 kPa / 2,80 g/s', '+18,8% / +12,5%'],
        'freeze_c': ['90 °C', '750 rpm / 0 km/h', '35%', '10,800 V', '40 kPa', 'N/A / N/A / N/A'],
        'live_a': ['90 / 25 °C', '800 rpm / 0 km/h', '24%', '42 kPa', '2,80 g/s', '12,5%', '14,200 V', '+18,8 / +12,5%'],
        'live_b': ['91 / 26 °C', '2500 rpm / 0 km/h', '18%', '32 kPa', '8,20 g/s', '18,0%', '14,180 V', '+3,1 / +12,5%'],
    }.items():
        root = ET.parse(ASSETS / 'source' / f'{stem}.svg').getroot()
        texts = [node.text for node in root.findall('s:text', NS)]
        for value in values:
            assert value in texts, (stem, value)
    assert sum(len(l['blocks']) for l in lessons) == 69
    assert sum(b['type'] in ('question', 'calculation') for l in lessons for b in l['blocks']) == 22
    image_refs = {b['asset'] for l in lessons for b in l['blocks'] if b['type'] == 'image'}
    assert len(image_refs) == 9
    assert len({l['id'] for l in lessons}) == 4
    for asset in image_refs:
        assert (ROOT / asset).is_file()
    print(f'{len(sources)} SVG/PNG pairs, {labels} labels >=18 px inside canvas; {len(protected)} protected files unchanged; 69 blocks / 22 tasks')
    if args.apk:
        apk = Path(args.apk)
        with zipfile.ZipFile(apk) as archive:
            for path in [*(f'assets/course/stage_7/lesson_{n:02}.json' for n in (4, 6, 7, 9)), *sorted(image_refs)]:
                assert archive.read(f'assets/flutter_assets/{path}') == (ROOT / path).read_bytes(), path
            assert not any('/obd/source/' in p for p in archive.namelist())
        print(f'APK pilot JSON/PNG match source; SVG excluded; bytes={apk.stat().st_size}; sha256={hashlib.sha256(apk.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
