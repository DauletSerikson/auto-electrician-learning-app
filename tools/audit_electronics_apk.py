"""Verify that the debug APK includes the complete offline electronics module."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    apk=ROOT/'build/app/outputs/flutter-apk/app-debug.apk'
    prefix='assets/flutter_assets/'
    with zipfile.ZipFile(apk) as archive:
        def bundled(path):
            data=archive.read(prefix+path)
            assert data==(ROOT/path).read_bytes(), f'APK differs from source: {path}'
            return json.loads(data) if path.endswith('.json') else data
        modules=bundled('assets/course/modules.json')
        assert len(modules)==7
        lessons=0;ids=[];block_count=0
        for module in modules:
            index=bundled(f"assets/course/{module['id']}/lessons.json")
            for summary in index:
                lesson=bundled(f"assets/course/{module['id']}/{summary['file']}")
                ids.append(lesson['id']);lessons+=1;block_count+=len(lesson['blocks'])
        assert lessons==len(set(ids))==62 and block_count==764
        images=sorted((ROOT/'assets/images/electronics').glob('*.png'))
        assert len(images)==19
        for image in images: bundled(image.relative_to(ROOT).as_posix())
        assert not any(name.startswith(prefix+'assets/images/electronics/source/') for name in archive.namelist())
        quiz=bundled('assets/course/stage_6/lesson_10.json')
        assert quiz['completion']=={'type':'quiz','passingScore':80}
        assert sum(b['type']=='question' for b in quiz['blocks'])==15
    result=dict(apk=apk.relative_to(ROOT).as_posix(),bytes=apk.stat().st_size,
                sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),modules=7,lessons=62,blocks=764,electronics_png=19)
    (ROOT/'build/r10-module7-apk-audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))
    print('All course JSON and 19 electronics PNG match the APK byte-for-byte; SVG sources excluded')

if __name__=='__main__': main()
