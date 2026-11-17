"""Download the pinned LEALLA snapshot, checking upstream Git/LFS hashes."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import hashlib
import json
import urllib.request

model = 'setu4993/LEALLA-small'
revision = '8fadf81fe3979f373ba9922ab616468a4184b266'
root = Path(__file__).resolve().parents[1] / '.model-cache' / 'lealla-base'
root.mkdir(parents=True, exist_ok=True)
meta = json.load(urllib.request.urlopen(f'https://huggingface.co/api/models/{model}/revision/{revision}?blobs=true', timeout=30))
names = {'README.md', 'model.safetensors', 'vocab.txt', 'config.json',
         'tokenizer.json', 'tokenizer_config.json', 'special_tokens_map.json'}
files = [f for f in meta['siblings'] if f['rfilename'] in names]
if {f['rfilename'] for f in files} != names:
    raise ValueError('Pinned snapshot does not contain the expected files.')
large = next(f for f in files if f['rfilename'] == 'model.safetensors')

def get_small(f):
    name = f['rfilename']
    target = root / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        with urllib.request.urlopen(f'https://huggingface.co/{model}/resolve/{revision}/{name}?download=true', timeout=30) as response:
            target.write_bytes(response.read())
    if target.stat().st_size != f['size']:
        raise ValueError('Wrong size: ' + name)
    if 'lfs' in f and hashlib.sha256(target.read_bytes()).hexdigest() != f['lfs']['sha256']:
        raise ValueError('Hash mismatch: ' + name)
    if 'lfs' not in f:
        data = target.read_bytes()
        git_hash = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
        if git_hash != f['blobId']:
            raise ValueError('Git blob hash mismatch: ' + name)
    print('Verified ' + name, flush=True)

for f in files:
    if f is not large:
        get_small(f)

existing = root / 'model.safetensors'
if existing.is_file():
    with existing.open('rb') as stream:
        valid = hashlib.file_digest(stream, 'sha256').hexdigest() == large['lfs']['sha256']
    if valid:
        (root / 'download-manifest.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
        print('Existing pinned encoder SHA256 verified.', flush=True)
        raise SystemExit(0)

size = large['size']
chunk = 2 * 1024 * 1024
parts = Path(__file__).resolve().parents[1] / '.model-cache' / 'lealla-parts'
parts.mkdir(parents=True, exist_ok=True)

def fetch(index):
    start, end = index * chunk, min(size - 1, (index + 1) * chunk - 1)
    target = parts / str(index)
    if target.exists() and target.stat().st_size == end - start + 1:
        return target.stat().st_size
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                f'https://huggingface.co/{model}/resolve/{revision}/model.safetensors?download=true&part={index}',
                headers={'Range': f'bytes={start}-{end}'})
            with urllib.request.urlopen(request, timeout=40) as response:
                if response.status != 206 or response.headers.get('Content-Range') != f'bytes {start}-{end}/{size}':
                    raise ValueError('Server did not honor requested range')
                data = response.read()
            if len(data) != end - start + 1:
                raise ValueError('Incomplete range')
            target.write_bytes(data)
            return len(data)
        except Exception:
            if attempt == 2:
                raise

done_bytes = 0
with ThreadPoolExecutor(max_workers=8) as pool:
    jobs = [pool.submit(fetch, i) for i in range((size + chunk - 1) // chunk)]
    for completed in as_completed(jobs):
        done_bytes += completed.result()
        if done_bytes % (10 * chunk) == 0 or done_bytes == size:
            print(f'Encoder: {done_bytes / 1048576:.0f}/{size / 1048576:.0f} MiB', flush=True)
destination = root / 'model.safetensors'
with destination.open('wb') as output:
    for i in range(len(jobs)):
        output.write((parts / str(i)).read_bytes())
with destination.open('rb') as source:
    digest = hashlib.file_digest(source, 'sha256').hexdigest()
if digest != large['lfs']['sha256']:
    raise ValueError('Encoder SHA256 mismatch; do not train')
(root / 'download-manifest.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
print('Verified encoder SHA256 at pinned revision ' + revision, flush=True)
