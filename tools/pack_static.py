#!/usr/bin/env python3
"""Optionally split a Web export for static hosts with small per-file limits."""
from pathlib import Path
import gzip
import hashlib
import json
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent
CHUNK_SIZE = 4 * 1024 * 1024
LIMIT = 25 * 1024 * 1024
sha = lambda data: hashlib.sha256(data).hexdigest()

def build(source, out):
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError('Output folder must be empty; use a fresh folder for each build.')
    page = (source / 'index.html').read_text()
    config = json.loads(re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', page).group(1))
    release = json.loads((source / 'release.json').read_text())
    assert config['mainPack'] == release['pack']
    manifest = {}
    for name, mime in [(config['executable']+'.wasm','application/wasm'),(config['mainPack'],'application/octet-stream')]:
        data = (source / name).read_bytes()
        if name == release['pack']:
            assert sha(data) == release['sha256']
        parts = []
        for offset in range(0, len(data), CHUNK_SIZE):
            raw = data[offset:offset+CHUNK_SIZE]
            compressed = gzip.compress(raw, compresslevel=9, mtime=0)
            digest = sha(compressed)
            filename = f'part-{digest[:20]}.gz'
            assert len(compressed) < LIMIT
            assert gzip.decompress(compressed) == raw
            (out / filename).write_bytes(compressed)
            parts.append({'url':filename,'size':len(raw),'downloadSize':len(compressed),'downloadSha256':digest})
        manifest[name] = {'size':len(data),'sha256':sha(data),'type':mime,'parts':parts}
        assert b''.join(gzip.decompress((out/p['url']).read_bytes()) for p in parts) == data
    assets = re.findall(r'<(?:script|img|link)\b[^>]*?(?:src|href)="([^"@]+)"', page)
    for name in assets + ['index.js','index.audio.worklet.js','index.audio.position.worklet.js','LICENSE','LICENSE-ASSETS.md','THIRD_PARTY_NOTICES.md','CC-BY-4.0.txt','GODOT-LICENSE.txt','GODOT-THIRD-PARTY.txt']:
        if name.startswith(('http:','https:','/')):
            raise ValueError('Unexpected external asset')
        if name.endswith('.js') and name.startswith('vila-js-'):
            shell = (source/name).read_text()
            shell = shell.replace('await engine.startGame({onProgress(current, total) {','await window.ValeDownloads.start(engine, (current, total) => {')
            assert 'await window.ValeDownloads.start' in shell
            shell = shell.replace('      }});','      });')
            new_name = f'vila-js-{sha(shell.encode())[:12]}.js'
            (out/new_name).write_text(shell)
            page = page.replace(name,new_name)
        else:
            shutil.copyfile(source/name,out/name)
    transport = (ROOT/'transport.js').read_text().replace('__VALE_MANIFEST__',json.dumps(manifest,separators=(',',':')))
    transport_name = f'download-{sha(transport.encode())[:12]}.js'
    (out/transport_name).write_text(transport)
    page = page.replace('  <script src="vila-js-',f'  <script src="{transport_name}" onerror="showShellLoadError()"></script>\n  <script src="vila-js-')
    (out/'index.html').write_text(page)
    (out/'download-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    release['web_shell_sha256'] = sha(page.encode())
    release['download_bytes'] = sum(p['downloadSize'] for f in manifest.values() for p in f['parts'])
    (out/'release.json').write_text(json.dumps(release,indent=2)+'\n')
    (out/'_headers').write_text('''/
  Cache-Control: no-cache
/index.html
  Cache-Control: no-cache
/release.json
  Cache-Control: no-cache
/part-*.gz
  Cache-Control: public, max-age=31536000, immutable
  Content-Type: application/octet-stream
/vila-*
  Cache-Control: public, max-age=31536000, immutable
/download-*.js
  Cache-Control: public, max-age=31536000, immutable
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
''')
    for file in out.iterdir():
        assert file.is_file() and file.stat().st_size < LIMIT
    print(json.dumps({'build':release['build'],'download_bytes':release['download_bytes'],'pack_sha256':release['sha256'],'files':len(list(out.iterdir()))},indent=2))

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve())
