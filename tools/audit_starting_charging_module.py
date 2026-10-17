"""R12 content/unchanged-baseline audit; optionally verify packaged APK bytes.

Run: python tools/audit_starting_charging_module.py [--apk path/to/app-debug.apk]
No Flutter or third-party Python dependencies. Baseline must be available in git.
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
BASELINE = '5c5981e'
NS = {'s': 'http://www.w3.org/2000/svg'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path)
    args = parser.parse_args()
    protected = git('ls-tree', '-r', '--name-only', BASELINE, '--',
                    'lib', 'assets/course', 'assets/images').decode().splitlines()
    checked = 0
    for name in protected:
        if name == 'assets/course/modules.json':
            continue
        actual = (ROOT/name).read_bytes()
        # This Windows checkout uses core.autocrlf. Compare text in Git's LF
        # representation, binary image bytes remain exact.
        if Path(name).suffix in ('.dart', '.json', '.md', '.svg'):
            actual = actual.replace(b'\r\n', b'\n')
        assert actual == git('show', f'{BASELINE}:{name}'), name
        checked += 1
    modules = json.loads((ROOT/'assets/course/modules.json').read_text(encoding='utf-8'))
    old = json.loads(git('show', f'{BASELINE}:assets/course/modules.json'))
    assert modules[:8] == old
    assert [m['id'] for m in modules] == [f'stage_{n}' for n in range(9)]
    ids, count, tasks, new_blocks, new_tasks, images = [], 0, 0, 0, 0, set()
    for mi, module in enumerate(modules):
        assert module['order'] == mi
        folder = ROOT/'assets/course'/module['id']
        index = json.loads((folder/'lessons.json').read_text(encoding='utf-8'))
        for order, summary in enumerate(index, 1):
            lesson = json.loads((folder/summary['file']).read_text(encoding='utf-8'))
            for key in ('id', 'title', 'description', 'estimatedMinutes', 'order'):
                assert lesson[key] == summary[key], (module['id'], key)
            assert lesson['order'] == order and lesson['moduleId'] == module['id']
            ids.append(lesson['id'])
            blocks = lesson['blocks']
            scored = sum(b['type'] in ('question', 'calculation', 'measurement', 'voltageDrop', 'currentMeasurement', 'diagnosticCase', 'diagnosticChoice') for b in blocks)
            count += len(blocks); tasks += scored
            if mi != 8:
                continue
            assert lesson['id'] == f'starting_charging_{order:02}'
            assert lesson['completion'] == ({'type': 'quiz', 'passingScore': 80} if order == 10 else {'type': 'lesson'})
            new_blocks += len(blocks); new_tasks += scored
            if order == 10:
                assert scored == 15 and sum(b['type'] == 'question' for b in blocks) == 15
            for b in blocks:
                assert b['type'] in ('text', 'remember', 'warning', 'image', 'question', 'calculation')
                if b['type'] == 'image':
                    images.add(b['asset'])
                if b['type'] == 'question':
                    assert 0 <= b['correctAnswer'] < len(b['answers'])
                    assert b['explanation'] and len(set(b['answers'])) == len(b['answers'])
                if b['type'] == 'calculation':
                    assert b['tolerance'] > 0 and b['unit'] and b['explanation']
    assert len(ids) == len(set(ids)) == 82
    assert count-new_blocks == 909
    assert (new_blocks, new_tasks, len(images)) == (134, 60, 15)
    for asset in images:
        png = (ROOT/asset).read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        source = ROOT/asset.replace('/starting_charging/', '/starting_charging/source/').replace('.png', '.svg')
        svg = ET.parse(source).getroot()
        w, h = int(svg.attrib['width']), int(svg.attrib['height'])
        assert struct.unpack('>II', png[16:24]) == (w*3, h*3)
        assert w == 320
    print(f'{len(modules)} modules / {len(ids)} lessons / {count} blocks / {tasks} tasks')
    print(f'module 9: {new_blocks} blocks / {new_tasks} tasks / {len(images)} SVG-PNG pairs')
    print(f'{checked} baseline files unchanged (text normalized to Git LF; binary exact)')
    if args.apk:
        with ZipFile(args.apk) as apk:
            assets = [p for p in (ROOT/'assets/course').rglob('*.json')]
            assets += [p for p in (ROOT/'assets/images').rglob('*.png')]
            for p in assets:
                name = 'assets/flutter_assets/'+p.relative_to(ROOT).as_posix()
                assert apk.read(name) == p.read_bytes(), name
            assert not any('/starting_charging/source/' in n for n in apk.namelist())
        print(f'APK: {len(assets)} JSON/PNG files match sources; R12 SVG sources excluded')
        print('APK SHA256:', hashlib.sha256(args.apk.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
