"""Read-only full R11 preservation, SVG/PNG and optional APK audit.

Run from repo root: python tools/audit_obd_module.py [--apk path]
Existing Pillow development tooling only; no Flutter dependency.
"""
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image, ImageFont
from audit_obd_pilot import ASSETS, NS, ROOT, git


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk')
    args = parser.parse_args()
    baseline = '081135e'
    # Includes all old modules, all four pilots, all nine pilot image pairs,
    # production Dart, lock and pubspec. Only modules.json is extended.
    protected = git('ls-tree', '-r', '--name-only', baseline, '--', 'assets', 'lib', 'pubspec.lock', 'pubspec.yaml').splitlines()
    protected.remove('assets/course/modules.json')
    protected.remove('assets/images/obd/README.md')  # New provenance appended.
    for path in protected:
        assert git('hash-object', f'--path={path}', path) == git('rev-parse', f'{baseline}:{path}'), path
    modules = json.loads((ROOT / 'assets/course/modules.json').read_text(encoding='utf-8'))
    old = json.loads(git('show', f'{baseline}:assets/course/modules.json'))
    assert modules[:-1] == old
    assert len(modules) == 8 and modules[-1]['id'] == 'stage_7'
    lessons = []
    for module in modules:
        folder = ROOT / 'assets/course' / module['id']
        index = json.loads((folder / 'lessons.json').read_text(encoding='utf-8'))
        for summary in index:
            lesson = json.loads((folder / summary['file']).read_text(encoding='utf-8'))
            assert lesson['moduleId'] == module['id']
            for field in ['id', 'order', 'title', 'description', 'estimatedMinutes']:
                assert lesson[field] == summary[field]
            lessons.append(lesson)
    assert len(lessons) == len({v['id'] for v in lessons}) == 72
    assert sum(len(v['blocks']) for v in lessons) == 909
    current = [v for v in lessons if v['moduleId'] == 'stage_7']
    assert [v['order'] for v in current] == list(range(1, 11))
    assert sum(len(v['blocks']) for v in current) == 145
    assert sum(b['type'] in ('question', 'calculation') for v in current for b in v['blocks']) == 55
    images = {b['asset'] for v in current for b in v['blocks'] if b['type'] == 'image'}
    assert len(images) == 14
    sources = sorted((ASSETS / 'source').glob('*.svg'))
    assert len(sources) == 14
    labels = 0
    for source in sources:
        root = ET.parse(source).getroot()
        width, height = int(root.get('width')), int(root.get('height'))
        assert width == 320 and root.get('viewBox') == f'0 0 320 {height}'
        for node in root.findall('s:text', NS):
            size = int(node.get('font-size'))
            assert size >= 18
            font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', size)
            length = font.getlength(node.text or '')
            x, y = float(node.get('x')), float(node.get('y'))
            if node.get('text-anchor') == 'middle':
                x -= length / 2
            assert 0 <= x and x + length <= width, (source.name, node.text, x, x + length)
            assert size <= y <= height
            labels += 1
        with Image.open(ASSETS / f'{source.stem}.png') as image:
            image.load()
            assert image.size == (width * 3, height * 3)
    print(f'8 modules / 72 lessons / 909 blocks; module8=145 blocks/55 tasks; 14 SVG/PNG pairs/{labels} labels; {len(protected)} baseline files unchanged')
    if args.apk:
        apk = ROOT / args.apk
        with zipfile.ZipFile(apk) as archive:
            files = [p for p in (ROOT / 'assets/course').rglob('*.json')]
            files += [ROOT / value for value in sorted(images)]
            for path in files:
                name = path.relative_to(ROOT).as_posix()
                assert archive.read(f'assets/flutter_assets/{name}') == path.read_bytes(), name
            assert not any('/obd/source/' in name for name in archive.namelist())
        print(f'APK all course JSON + 14 PNG match; SVG excluded; bytes={apk.stat().st_size}; sha256={hashlib.sha256(apk.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
