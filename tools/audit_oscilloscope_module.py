"""Read-only R14 integration/protected-baseline audit; Python standard library.

python tools/audit_oscilloscope_module.py [--apk build/.../app-debug.apk]
"""
import argparse
import io
import json
from pathlib import Path
import struct
import subprocess
import tarfile
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
BASELINE='04e880c'
SCORED={'question','calculation','measurement','voltageDrop','currentMeasurement','diagnosticCase','diagnosticChoice','oscilloscope'}


def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def normalized(data):return data.replace(b'\r\n',b'\n')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--apk',type=Path)
    args=parser.parse_args()
    # Batch baseline reads, preserving every old lesson, image, simulator and ID.
    raw=subprocess.check_output(['git','archive','--format=tar',BASELINE,'lib','assets','pubspec.lock','pubspec.yaml','android/app/build.gradle.kts'],cwd=ROOT)
    protected=0
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for member in archive.getmembers():
            if not member.isfile():continue
            original=archive.extractfile(member).read()
            actual=(ROOT/member.name).read_bytes()
            if member.name=='assets/course/modules.json':
                assert read(member.name)[:10]==json.loads(original)
            elif member.name=='pubspec.yaml':
                without_new=normalized(actual).decode().replace('    - assets/course/stage_10/\n','').replace('    - assets/images/oscilloscope/\n','')
                assert without_new==normalized(original).decode(),'unexpected pubspec edit'
            else:
                text=Path(member.name).suffix in {'.dart','.json','.md','.svg','.lock','.kts','.txt'}
                assert (normalized(actual)==normalized(original) if text else actual==original),member.name
                protected+=1
    modules=read('assets/course/modules.json')
    assert [m['id'] for m in modules]==[f'stage_{i}' for i in range(11)]
    ids=[];blocks=tasks=new_blocks=new_tasks=0
    interactive=[];scopes=0;bundle={'assets/course/modules.json'};images=set()
    for index,module in enumerate(modules):
        assert module['order']==index
        folder=f"assets/course/{module['id']}"
        bundle.add(folder+'/lessons.json')
        for order,summary in enumerate(read(folder+'/lessons.json'),1):
            path=folder+'/'+summary['file'];bundle.add(path)
            lesson=read(path)
            for key in ['id','order','title','description','estimatedMinutes']:
                assert lesson[key]==summary[key],path
            assert lesson['order']==order and lesson['moduleId']==module['id']
            ids.append(lesson['id'])
            blocks+=len(lesson['blocks']);tasks+=sum(b['type'] in SCORED for b in lesson['blocks'])
            if index==10:
                new_blocks+=len(lesson['blocks']);new_tasks+=sum(b['type'] in SCORED for b in lesson['blocks'])
                assert '???' not in json.dumps(lesson,ensure_ascii=False)
                if any(b['type']=='oscilloscope' for b in lesson['blocks']):interactive.append(order)
                scopes+=sum(b['type']=='oscilloscope' for b in lesson['blocks'])
                assert lesson['completion']==({'type':'quiz','passingScore':80} if order==10 else {'type':'lesson'})
                if order==10:assert sum(b['type'] in SCORED for b in lesson['blocks'])==15
            for b in lesson['blocks']:
                if b['type']=='image':
                    assert (ROOT/b['asset']).is_file(),b['asset']
                    bundle.add(b['asset'])
                    if index==10:images.add(b['asset'])
    assert len(ids)==len(set(ids))==102
    assert (blocks,tasks,new_blocks,new_tasks)==(1339,557,146,66)
    assert (interactive,scopes)==([3,4,5,9,10],7)
    catalog=read('assets/images/oscilloscope/source/catalog.json')
    assert len(images)==len(catalog)==18
    for stem,dimensions in catalog.items():
        png=(ROOT/f'assets/images/oscilloscope/{stem}.png').read_bytes()
        assert png[:8]==b'\x89PNG\r\n\x1a\n'
        assert list(struct.unpack('>II',png[16:24]))==dimensions
        svg=ET.parse(ROOT/f'assets/images/oscilloscope/source/{stem}.svg').getroot()
        assert svg.attrib['width']=='320'
        assert [int(svg.attrib['width'])*3,int(svg.attrib['height'])*3]==dimensions
        for curve in svg.findall('{http://www.w3.org/2000/svg}polyline'):
            a=curve.attrib
            assert a['data-unit'] in ['ms','µs'] and a['data-reference']=='N'
            assert abs((float(a['data-top'])-float(a['data-bottom']))/8-float(a['data-vdiv']))<1e-10
            coords=[tuple(map(float,p.split(','))) for p in a['points'].split()]
            assert all(46-1e-4<=x<=304+1e-4 for x,y in coords)
            assert all(coords[i][0]>=coords[i-1][0]-1e-6 for i in range(1,len(coords)))
    if args.apk:
        with ZipFile(args.apk) as apk:
            for path in bundle:
                assert apk.read('assets/flutter_assets/'+path)==(ROOT/path).read_bytes(),path
            assert not any('assets/images/oscilloscope/source/' in name for name in apk.namelist())
        print(f'{len(bundle)} referenced JSON/PNG bundled byte-exact; new SVG sources excluded')
    print(f'11 modules / 102 lessons / {blocks} blocks / {tasks} tasks')
    print(f'module 11: {new_blocks} blocks / {new_tasks} tasks / 18 SVG-PNG pairs / 7 scopes in 5 lessons')
    print(f'{protected} baseline files unchanged; module prefix and pubspec asset-only registration verified')


if __name__=='__main__':main()
