"""Read-only content/preservation audit for the approved R10 module.

Run at repository root. No application dependencies or simulator changes.
The approved pilot Git object is the source for preservation comparisons.
"""
from collections import Counter
from pathlib import Path
import json
import math
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = 'e55541f'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

def preserve(path):
    original = git('rev-parse', f'{BASE}:{path}').decode().strip()
    current = git('hash-object', '--path', path, path).decode().strip()
    assert current == original, f'Approved content changed: {path}'

def main():
    modules = read('assets/course/modules.json')
    baseline = json.loads(git('show', f'{BASE}:assets/course/modules.json'))
    assert modules[:6] == baseline
    assert [m['id'] for m in modules] == [f'stage_{i}' for i in range(7)]
    assert [m['order'] for m in modules] == list(range(7))
    old_files = [p for p in git('ls-tree', '-r', '--name-only', BASE, 'assets/course').decode().splitlines()
                 if any(p.startswith(f'assets/course/stage_{i}/') for i in range(6))]
    for path in old_files: preserve(path)
    pilot_files = [f'assets/course/stage_6/lesson_{n:02}.json' for n in (3,4,6)]
    pilot_files += [p for p in git('ls-tree', '-r', '--name-only', BASE, 'assets/images/electronics').decode().splitlines()
                    if p.endswith(('.svg','.png'))]
    for path in pilot_files: preserve(path)
    for path in git('ls-tree','-r','--name-only',BASE,'lib').decode().splitlines(): preserve(path)
    preserve('pubspec.lock')
    preserve('pubspec.yaml')  # Directories were already registered in the pilot.
    ids=[];course_blocks=0;module_types=Counter();image_refs=[]
    for module in modules:
        summaries = read(f"assets/course/{module['id']}/lessons.json")
        assert [s['order'] for s in summaries] == list(range(1,len(summaries)+1))
        for summary in summaries:
            lesson=read(f"assets/course/{module['id']}/{summary['file']}")
            assert lesson['moduleId']==module['id']
            for key in ('id','order','title','description','estimatedMinutes'): assert lesson[key]==summary[key]
            ids.append(lesson['id']);course_blocks+=len(lesson['blocks'])
            for block in lesson['blocks']:
                if block['type']=='image': assert (ROOT/block['asset']).is_file(), block['asset']
            if module['id']!='stage_6': continue
            assert lesson['completion']==({'type':'quiz','passingScore':80} if lesson['order']==10 else {'type':'lesson'})
            types=Counter(b['type'] for b in lesson['blocks'])
            assert set(types)<=set(('text','remember','warning','image','question','calculation'))
            module_types.update(types)
            for index,block in enumerate(lesson['blocks']):
                if block['type']=='question':
                    assert len(set(block['answers']))==len(block['answers'])==3
                    assert 0<=block['correctAnswer']<3
                    assert block['explanation'].strip()
                if block['type']=='image':
                    image_refs.append(block['asset'])
                    following=[]
                    for b in lesson['blocks'][index+1:]:
                        if b['type']=='image': break
                        following.append(b['type'])
                    assert 'question' in following
            print(f"{lesson['id']}: {len(lesson['blocks'])} blocks; {dict(types)}")
    assert len(ids)==len(set(ids))==62
    assert course_blocks==764
    assert sum(module_types.values())==167
    assert module_types['question']==62 and module_types['calculation']==8
    assert len(image_refs)==27 and len(set(image_refs))==19
    expected={3:[5*500/(2000+500)],4:[1000/5,100*8/10],5:[100*(10-4)/10],6:[5-.2,2.5+.2],7:[3.5-1.5,120*120/(120+120)]}
    for order,values in expected.items():
        tasks=[b for b in read(f'assets/course/stage_6/lesson_{order:02}.json')['blocks'] if b['type']=='calculation']
        assert len(tasks)==len(values)
        for b,value in zip(tasks,values): assert math.isclose(b['correctValue'],value,abs_tol=1e-9)
    quiz=read('assets/course/stage_6/lesson_10.json')
    assert len([b for b in quiz['blocks'] if b['type']=='question'])==15
    assert len([b for b in quiz['blocks'] if b['type']=='calculation'])==0
    print(f'Preserved {len(old_files)} old course files, {len(pilot_files)} pilot files, all lib/, pubspec and lock')
    print(f'7 modules / 62 lessons / {course_blocks} course blocks; stage_6: {dict(module_types)}')
    print('Eight calculations, image task coverage, IDs and quiz metadata OK')

if __name__=='__main__': main()
