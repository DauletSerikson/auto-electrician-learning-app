"""Audit R13 course integration, protected baseline and optionally APK bytes.

Run: python tools/audit_wiring_repair_module.py [--apk build/.../app-debug.apk]
Uses only Python stdlib and local Git; no application dependency.
"""
import argparse
import hashlib
import json
import struct
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
BASELINE = '0725a11'
SCORED = {'question', 'calculation', 'measurement', 'voltageDrop',
          'currentMeasurement', 'diagnosticCase', 'diagnosticChoice'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path)
    args = parser.parse_args()
    protected = git('ls-tree', '-r', '--name-only', BASELINE, '--',
                    'lib', 'assets/course', 'assets/images', 'pubspec.lock',
                    'android/app/build.gradle.kts').decode().splitlines()
    checked = 0
    for name in protected:
        if name == 'assets/course/modules.json':
            continue
        actual = (ROOT/name).read_bytes()
        if Path(name).suffix in ('.dart', '.json', '.md', '.svg', '.lock', '.kts'):
            actual = actual.replace(b'\r\n', b'\n')
        assert actual == git('show', f'{BASELINE}:{name}'), name
        checked += 1
    modules = read(ROOT/'assets/course/modules.json')
    old = json.loads(git('show', f'{BASELINE}:assets/course/modules.json'))
    assert modules[:9] == old
    assert [m['id'] for m in modules] == [f'stage_{i}' for i in range(10)]
    ids, blocks, tasks, new_blocks, new_tasks, images = [], 0, 0, 0, 0, set()
    for order, module in enumerate(modules):
        assert module['order'] == order
        folder = ROOT/'assets/course'/module['id']
        for n, summary in enumerate(read(folder/'lessons.json'), 1):
            lesson = read(folder/summary['file'])
            for key in ('id', 'order', 'title', 'description', 'estimatedMinutes'):
                assert lesson[key] == summary[key], (module['id'], key)
            assert lesson['order'] == n and lesson['moduleId'] == module['id']
            ids.append(lesson['id'])
            count = sum(b['type'] in SCORED for b in lesson['blocks'])
            blocks += len(lesson['blocks']); tasks += count
            if order != 9:
                continue
            new_blocks += len(lesson['blocks']); new_tasks += count
            assert lesson['id'] == f'wiring_repair_{n:02}'
            assert lesson['completion'] == ({'type': 'quiz', 'passingScore': 80}
                                             if n == 10 else {'type': 'lesson'})
            if n == 10:
                assert count == 15
            for b in lesson['blocks']:
                assert b['type'] in {'text', 'image', 'question', 'calculation', 'warning', 'remember'}
                if b['type'] == 'question':
                    assert len(set(b['answers'])) == len(b['answers'])
                    assert 0 <= b['correctAnswer'] < len(b['answers'])
                    assert b['explanation']
                elif b['type'] == 'calculation':
                    assert b['tolerance'] > 0 and b['correctValue'] >= 0 and b['unit']
                elif b['type'] == 'image':
                    images.add(b['asset'])
    assert len(ids) == len(set(ids)) == 92
    assert blocks-new_blocks == 1043 and tasks-new_tasks == 424
    assert (new_blocks, new_tasks, len(images)) == (150, 67, 15)
    pngs = {p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/images/wiring_repair').glob('*.png')}
    assert images == pngs, 'Every new PNG must have a lesson purpose'
    for name in images:
        png = (ROOT/name).read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        source = ROOT/name.replace('/wiring_repair/', '/wiring_repair/source/').replace('.png', '.svg')
        svg = ET.parse(source).getroot()
        w,h = int(svg.attrib['width']),int(svg.attrib['height'])
        assert w == 320 and struct.unpack('>II', png[16:24]) == (w*3,h*3)
        assert not svg.findall('.//{http://www.w3.org/2000/svg}image')
    print(f'{len(modules)} modules / {len(ids)} lessons / {blocks} blocks / {tasks} tasks')
    print(f'module 10: {new_blocks} blocks / {new_tasks} tasks / {len(images)} SVG-PNG pairs')
    print(f'{checked} baseline files unchanged (text normalized to Git LF, binary exact)')
    if args.apk:
        with ZipFile(args.apk) as apk:
            names = set(apk.namelist())
            assets = list((ROOT/'assets/course').rglob('*.json'))
            assets += list((ROOT/'assets/images').rglob('*.png'))
            for path in assets:
                packaged = 'assets/flutter_assets/'+path.relative_to(ROOT).as_posix()
                assert apk.read(packaged) == path.read_bytes(), packaged
            assert not any('/wiring_repair/source/' in name for name in names)
        print(f'APK: {len(assets)} JSON/PNG files match; new SVG sources excluded')
        print('APK SHA256:', hashlib.sha256(args.apk.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
