"""Create a local disposable build with isolated saves and a runtime test driver."""
from pathlib import Path
import os
import shutil
import sys
import zipfile
from verify import ROOT, GAME, patched_sources

qa = ROOT / '.qa'
qa.mkdir(exist_ok=True)
sources = patched_sources()
if '--lovely' in sys.argv:
    with zipfile.ZipFile(GAME / 'Balatro.exe') as original_zip:
        sources = {n: original_zip.read(n) for n in original_zip.namelist() if n.endswith('.lua')}
    shutil.copy2(GAME / 'version.dll', qa / 'version.dll')
sources['conf.lua'] += b"\nlocal original_conf = love.conf\nfunction love.conf(t) original_conf(t); t.identity = 'YubalatroQA'; t.window.title = 'Yubalatro QA'; end\n"
driver = 'scoring.lua' if '--scoring' in sys.argv else 'runtime.lua'
first_case = next((int(a.split('=', 1)[1]) for a in sys.argv if a.startswith('--qa-from=')), 1)
sources['main.lua'] += f'\nYUBALATRO_QA_FROM = {first_case}\n'.encode()
sources['main.lua'] += b'\n' + (ROOT / 'tests' / driver).read_bytes()
for p in GAME.iterdir():
    if p.is_file() and p.suffix.lower() in ('.dll', '.txt') and p.name != 'version.dll':
        shutil.copy2(p, qa / p.name)
original = (GAME / 'Balatro.exe').read_bytes()
with zipfile.ZipFile(GAME / 'Balatro.exe') as source:
    prefix = original[:min(i.header_offset for i in source.infolist())]
    exe = qa / 'Balatro.exe'
    exe.write_bytes(prefix)
    with zipfile.ZipFile(exe, 'a', compression=zipfile.ZIP_DEFLATED) as target:
        for info in source.infolist():
            target.writestr(info.filename, sources.get(info.filename, source.read(info.filename)))
        save = Path(os.environ['APPDATA']) / 'Balatro'
        for path in save.rglob('*.jkr'):
            if 'Mods' not in path.relative_to(save).parts:
                target.write(path, 'qa_save/' + path.relative_to(save).as_posix())
print('QA build:', exe)
