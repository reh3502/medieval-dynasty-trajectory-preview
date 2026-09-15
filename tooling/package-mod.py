#!/usr/bin/env python3
"""Build a deterministic, installable archive from distributable files."""
import hashlib
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build(output=None):
    version = (ROOT / 'VERSION').read_text().strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('VERSION must contain major.minor.patch')
    output = Path(output) if output else ROOT / 'dist'
    output.mkdir(parents=True, exist_ok=True)
    files = {}
    source = ROOT / 'mod/TrajectoryPreview'
    prefix = 'Medieval_Dynasty/Binaries/Win64/ue4ss/Mods/TrajectoryPreview/'
    for directory, suffix in [('Scripts', '*.lua'), ('Textures', '*.png')]:
        for path in sorted((source / directory).glob(suffix)):
            files[prefix + path.relative_to(source).as_posix()] = path.read_bytes()
    files[prefix + 'enabled.txt'] = b''
    for line in (ROOT / 'assets/SHA256SUMS').read_text().splitlines():
        digest, name = line.split()
        if name not in {'MDTrajectoryThread_P.pak', 'MDTrajectoryOutline_P.pak'}:
            raise ValueError('Unexpected material asset: ' + name)
        data = (ROOT / 'assets' / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Material checksum mismatch: ' + name)
        files['Medieval_Dynasty/Content/Paks/' + name] = data
    if len([name for name in files if name.endswith('.pak')]) != 2:
        raise ValueError('Both material paks are required')
    files['README.md'] = (ROOT / 'README.md').read_bytes()
    archive = output / f'TrajectoryPreview-{version}.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, data)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
    return archive


if __name__ == '__main__':
    print(build())
