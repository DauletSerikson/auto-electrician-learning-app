"""Read-only R17 course/protected-baseline/APK audit; standard library only."""
import argparse
import io
import json
from pathlib import Path
import struct
import subprocess
import tarfile
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
SCORED={'question','calculation','measurement','voltageDrop','currentMeasurement','diagnosticCase','diagnosticChoice','oscilloscope'}


def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8'))
def normalized(data): return data.replace(b'\r\n',b'\n')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--apk',type=Path)
    args=parser.parse_args()
    raw=subprocess.check_output(['git','archive','--format=tar','7f4516c','lib','assets','pubspec.yaml','pubspec.lock','android/app/build.gradle.kts'],cwd=ROOT)
    protected=0
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for member in archive.getmembers():
            if not member.isfile(): continue
            original=archive.extractfile(member).read()
            actual=(ROOT/member.name).read_bytes()
            if member.name=='assets/course/modules.json':
                assert read(member.name)[:13]==json.loads(original)
            elif member.name=='pubspec.yaml':
                without=normalized(actual).decode().replace('    - assets/course/stage_13/\n','').replace('    - assets/images/hybrid_ev/\n','')
                assert without==normalized(original).decode(),'unexpected pubspec edit'
            else:
                is_text=Path(member.name).suffix in {'.dart','.json','.md','.svg','.lock','.kts','.txt'}
                assert (normalized(actual)==normalized(original) if is_text else actual==original),member.name
                protected+=1
    modules=read('assets/course/modules.json')
    assert [m['id'] for m in modules]==[f'stage_{i}' for i in range(14)]
    ids=[]; blocks=tasks=new_blocks=new_tasks=0
    images=set(); bundle={'assets/course/modules.json'}
    for i,module in enumerate(modules):
        assert module['order']==i
        folder=f"assets/course/{module['id']}"
        bundle.add(folder+'/lessons.json')
        for order,summary in enumerate(read(folder+'/lessons.json'),1):
            path=folder+'/'+summary['file']; bundle.add(path)
            lesson=read(path)
            for key in ['id','order','title','description','estimatedMinutes']:
                assert lesson[key]==summary[key],path
            assert lesson['moduleId']==module['id'] and lesson['order']==order
            ids.append(lesson['id'])
            n=len(lesson['blocks']); t=sum(b['type'] in SCORED for b in lesson['blocks'])
            blocks+=n; tasks+=t
            if i==13:
                new_blocks+=n; new_tasks+=t
                assert lesson['completion']==({'type':'quiz','passingScore':80} if order==10 else {'type':'lesson'})
                if order==10: assert t==15
            for b in lesson['blocks']:
                if b['type']=='image':
                    assert (ROOT/b['asset']).is_file()
                    bundle.add(b['asset'])
                    if i==13: images.add(b['asset'])
    assert len(ids)==len(set(ids))==132
    assert (blocks,tasks,new_blocks,new_tasks)==(1819,764,152,68)
    assert ids[121]=='safety_systems_10'
    catalog=read('assets/images/hybrid_ev/source/catalog.json')
    assert len(catalog)==len(images)==20
    for stem,size in catalog.items():
        png=(ROOT/f'assets/images/hybrid_ev/{stem}.png').read_bytes()
        assert list(struct.unpack('>II',png[16:24]))==size
    if args.apk:
        with ZipFile(args.apk) as apk:
            for path in bundle:
                assert apk.read('assets/flutter_assets/'+path)==(ROOT/path).read_bytes(),path
            assert not any('/hybrid_ev/source/' in name for name in apk.namelist())
        print(f'{len(bundle)} referenced JSON/PNG byte-exact in APK; new SVG sources excluded')
    print(f'14 modules / {len(ids)} lessons / {blocks} blocks / {tasks} tasks')
    print(f'module 14: {new_blocks} blocks / {new_tasks} tasks / {len(images)} SVG-PNG pairs')
    print(f'{protected} baseline files unchanged; modules prefix and pubspec asset-only additions verified')


if __name__=='__main__': main()
