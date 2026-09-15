#!/usr/bin/env python3
"""Check archive layout, release defaults, and reproducibility."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import zipfile

spec = importlib.util.spec_from_file_location('package_mod', Path(__file__).with_name('package-mod.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    archive = module.build(directory)
    first = archive.read_bytes()
    assert module.build(directory).read_bytes() == first
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        names = bundle.namelist()
        prefix = 'Medieval_Dynasty/Binaries/Win64/ue4ss/Mods/TrajectoryPreview/'
        assert prefix + 'enabled.txt' in names
        assert prefix + 'Scripts/main.lua' in names
        assert prefix + 'Textures/trajectory.png' in names
        assert prefix + 'Textures/world-box.png' in names
        assert b'telemetry=false' in bundle.read(prefix + 'Scripts/config.lua')
        assert 'Medieval_Dynasty/Content/Paks/MDTrajectoryThread_P.pak' in names
        assert 'Medieval_Dynasty/Content/Paks/MDTrajectoryOutline_P.pak' in names
        for name in names:
            assert '..' not in Path(name).parts and not name.startswith('/')
            assert name == 'README.md' or name.startswith('Medieval_Dynasty/')
            assert Path(name).suffix in {'.md', '.lua', '.png', '.pak', '.txt'}
            assert not name.endswith('preferences.ini')
    assert archive.with_suffix('.zip.sha256').read_text().split()[0] == hashlib.sha256(first).hexdigest()
print('PASS install layout, telemetry default, material checksums and reproducible archive')
