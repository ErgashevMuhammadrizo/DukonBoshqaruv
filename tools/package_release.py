"""Package source only. Databases, credentials, media and build outputs are excluded."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import argparse, os, tempfile
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=root.parent / 'DokonBoshqaruv_final.zip')
args = parser.parse_args()
out = args.output.resolve()
if out == root or root in out.parents:
    raise SystemExit('Choose an output path outside the source directory.')
excluded = {'.git', '.dart_tool', '.gradle', 'build', 'venv', '.venv', '__pycache__', 'node_modules', '.idea', 'media', 'backups', '.symlinks', 'Pods', 'ephemeral', '.pytest_cache', 'logs', '.vscode'}
blocked_names = {'local.properties', 'key.properties', '.flutter-plugins-dependencies', '.DS_Store'}
def allowed(path):
    rel = path.relative_to(root)
    if excluded.intersection(rel.parts) or path.is_symlink(): return False
    name = path.name.lower()
    if name in blocked_names: return False
    if (name.startswith('.env') or name.endswith('.env')) and name != '.env.example': return False
    if any(x.startswith('.env') and x != '.env.example' for x in rel.parts): return False
    if name.endswith(('.zip', '.apk', '.aab', '.db', '.sqlite', '.sqlite3', '.db-wal', '.db-shm', '.sqlite3-wal', '.sqlite3-shm', '.pyc', '.dump', '.jks', '.keystore', '.pem', '.key')): return False
    return path.is_file()
out.parent.mkdir(parents=True, exist_ok=True)
with tempfile.NamedTemporaryFile(dir=out.parent, suffix='.zip', delete=False) as temp:
    temp_path = Path(temp.name)
try:
    with ZipFile(temp_path, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob('*')):
            if allowed(path): archive.write(path, Path('DokonBoshqaruv') / path.relative_to(root))
    with ZipFile(temp_path) as archive:
        if archive.testzip() is not None: raise RuntimeError('ZIP integrity check failed')
    os.replace(temp_path, out)
finally:
    temp_path.unlink(missing_ok=True)
print(out)
