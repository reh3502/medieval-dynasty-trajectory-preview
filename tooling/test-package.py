#!/usr/bin/env python3
"""Check archive layout, release defaults, and reproducibility."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import zipfile
import shutil

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

with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    archive = module.build(directory, bundled=True)
    original = archive.read_bytes()
    assert module.build(directory, bundled=True).read_bytes() == original
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        names = bundle.namelist()
        root = 'Medieval_Dynasty/Binaries/Win64/'
        assert sorted(name for name in names if name.endswith('.dll')) == [root + 'dwmapi.dll', root + 'ue4ss/UE4SS.dll']
        assert root + 'ue4ss/LICENSE' in names
        assert root + 'ue4ss/THIRD-PARTY-NOTICES.txt' in names
        settings = bundle.read(root + 'ue4ss/UE4SS-settings.ini').decode()
        assert 'ConsoleEnabled = 0' in settings and 'GuiConsoleEnabled = 0' in settings
        assert not any(name.endswith(('.pdb', 'mods.txt', 'mods.json', 'preferences.ini')) for name in names)
        assert not any('/Mods/' in name and '/Mods/TrajectoryPreview/' not in name for name in names)
        bundle.extractall(directory / 'game')
    # Fresh install has both loader and mod at the paths the game discovers.
    game = directory / 'game/Medieval_Dynasty/Binaries/Win64'
    assert (game / 'dwmapi.dll').read_bytes()[:2] == b'MZ'
    assert (game / 'ue4ss/UE4SS.dll').read_bytes()[:2] == b'MZ'
    assert (game / 'ue4ss/Mods/TrajectoryPreview/enabled.txt').is_file()
    # Mod-only upgrades must preserve an existing loader and other mods.
    sentinel = game / 'ue4ss/UE4SS-settings.ini'
    sentinel.write_text('existing settings')
    existing = game / 'ue4ss/Mods/OtherMod/enabled.txt'
    existing.parent.mkdir(parents=True)
    existing.write_text('existing mod')
    with zipfile.ZipFile(module.build(directory)) as bundle:
        bundle.extractall(directory / 'game')
    assert sentinel.read_text() == 'existing settings'
    assert existing.read_text() == 'existing mod'
    # Refuse a changed dependency rather than publishing an unpinned DLL.
    saved_root = module.ROOT
    try:
        module.ROOT = directory / 'tampered'
        shutil.copytree(saved_root / 'vendor', module.ROOT / 'vendor')
        (module.ROOT / 'vendor/ue4ss/dwmapi.dll').write_bytes(b'changed')
        try:
            module.runtime_files()
        except ValueError as error:
            assert 'checksum mismatch' in str(error)
        else:
            raise AssertionError('Unverified loader accepted')
    finally:
        module.ROOT = saved_root
print('PASS bundled install, pinned runtime, licenses, reproducibility and mod-only upgrades')
