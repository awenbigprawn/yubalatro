#!/usr/bin/env python3
"""Install Yubalatro for Steam Proton on Linux (Python 3.8+, stdlib only)."""
import argparse
from datetime import datetime
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent
URL = 'https://github.com/ethangreen-dev/lovely-injector/releases/download/v0.9.0/lovely-x86_64-pc-windows-msvc.zip'
ARCHIVE_HASH = '40b994a055ee75e5f2aba81e7ae06f2c17460e18cc346483089921899fadd1f7'
LAUNCH_OPTIONS = 'WINEDLLOVERRIDES="version=n,b" %command%'


def unique(paths):
    return list(dict.fromkeys(p.expanduser().resolve() for p in paths))


def libraries(home):
    roots = unique([
        home / '.local/share/Steam', home / '.steam/steam', home / '.steam/root',
        home / '.var/app/com.valvesoftware.Steam/.local/share/Steam',
        home / '.var/app/com.valvesoftware.Steam/.steam/steam',
    ])
    result = list(roots)
    for root in roots:
        vdf = root / 'steamapps/libraryfolders.vdf'
        if vdf.is_file():
            for path in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(encoding='utf-8')):
                result.append(Path(path.replace('\\\\', '\\')))
    return unique(result)


def locate(home, game_dir=None, prefix_dir=None):
    libs = libraries(home)
    games = unique([Path(game_dir)]) if game_dir else unique([
        lib / 'steamapps/common/Balatro' for lib in libs
        if (lib / 'steamapps/common/Balatro/Balatro.exe').is_file()
    ])
    if len(games) != 1:
        raise ValueError('Expected one Balatro installation. Pass --game-dir with the directory shown by Steam > Manage > Browse local files.')
    game = games[0]
    if not (game / 'Balatro.exe').is_file() or not (game / 'lua51.dll').is_file():
        raise ValueError('Windows Balatro files not found. Enable Proton in Steam > Properties > Compatibility, launch once, then close the game.')
    # A non-default Steam library normally owns its own compatdata directory.
    possible = unique([Path(prefix_dir)]) if prefix_dir else unique([
        lib / 'steamapps/compatdata/2379780/pfx'
        for lib in [game.parent.parent.parent] + libs
        if (lib / 'steamapps/compatdata/2379780/pfx/drive_c').is_dir()
    ])
    if len(possible) != 1 or not (possible[0] / 'drive_c').is_dir():
        raise ValueError('Expected one initialized Proton prefix. Launch Balatro through Proton once, or pass --prefix with its compatdata/2379780/pfx directory.')
    prefix = possible[0]
    roaming = prefix / 'drive_c/users/steamuser/AppData/Roaming'
    if not roaming.is_dir():
        raise ValueError('Proton steamuser AppData/Roaming directory is missing. Launch the game once first.')
    return game, roaming / 'Balatro'


def digest(path):
    with path.open('rb') as source:
        result = hashlib.sha256()
        for block in iter(lambda: source.read(1024 * 1024), b''):
            result.update(block)
        return result.hexdigest()


def inside(path, parent):
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def install(game, save, root=ROOT):
    destination = save / 'Mods/Yubalatro'
    dll = game / 'version.dll'
    record = root / 'installation-linux.txt'
    if destination.exists() or destination.is_symlink() or record.exists():
        raise ValueError('Yubalatro is already installed. See README for updating or uninstalling.')
    if dll.exists() or dll.is_symlink():
        raise ValueError('An existing version.dll was found. Follow the README manual installation instructions to preserve your current loader.')
    if any(inside(root, path) for path in (game, save)) or inside(game, save) or inside(save, game):
        raise ValueError('Keep this repository outside the game and save directories so backups cannot include themselves.')
    source = root / 'mod'
    if not (source / 'lovely.toml').is_file():
        raise ValueError('Missing mod/lovely.toml. Download and extract the whole repository first.')
    archive = root / '.cache/lovely-v0.9.0.zip'
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.is_file():
        print('Downloading Lovely 0.9.0...', flush=True)
        with urllib.request.urlopen(URL, timeout=60) as response, archive.open('wb') as output:
            shutil.copyfileobj(response, output)
    if digest(archive) != ARCHIVE_HASH:
        raise ValueError('Lovely archive hash mismatch. Remove .cache/lovely-v0.9.0.zip and retry.')
    with zipfile.ZipFile(archive) as packed:
        loader = packed.read('version.dll')
    backup = root / 'backups' / ('linux-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True)
    print('Backing up game and saves to ' + str(backup), flush=True)
    shutil.copytree(game, backup / 'game', symlinks=True)
    if save.exists():
        shutil.copytree(save, backup / 'save', symlinks=True)
    # Write recovery locations before changing the game or mod directories.
    record.write_text('game=' + str(game) + '\nmod=' + str(destination) + '\nbackup=' + str(backup)
                      + '\nloader_sha256=' + hashlib.sha256(loader).hexdigest() + '\n', encoding='utf-8')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)
    with dll.open('xb') as output:
        output.write(loader)
    print('Installed: ' + str(destination))


def update_mod(game, save, root=ROOT):
    destination = save / 'Mods/Yubalatro'
    source = root / 'mod'
    if not (destination / 'lovely.toml').is_file() or not (game / 'version.dll').is_file():
        raise ValueError('No installed Yubalatro/Lovely found. Run without --update to install first.')
    if not (source / 'lovely.toml').is_file():
        raise ValueError('Missing mod/lovely.toml in this repository.')
    if inside(root, destination) or inside(destination, root):
        raise ValueError('Keep the repository separate from the installed mod.')
    backup = root / 'backups' / ('linux-mod-update-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True)
    shutil.copytree(destination, backup / 'Yubalatro', symlinks=True)
    # Overlay source files only; save/config files and the Lovely DLL stay intact.
    shutil.copytree(source, destination, dirs_exist_ok=True)
    print('Updated: ' + str(destination))
    print('Previous mod: ' + str(backup / 'Yubalatro'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir', help='Steam game directory containing Balatro.exe')
    parser.add_argument('--prefix', help='Proton prefix directory ending in compatdata/2379780/pfx')
    parser.add_argument('--check-only', action='store_true', help='Show detected paths without installing')
    parser.add_argument('--update', action='store_true', help='Back up and update an existing mod; preserve saves, settings and loader')
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.exit(1, 'This installer is for Linux Steam + Proton. On Windows use install.ps1.\n')
    try:
        game, save = locate(Path.home(), args.game_dir, args.prefix)
        print('Balatro: ' + str(game))
        print('Save/config: ' + str(save))
        if not args.check_only:
            running = subprocess.run(['pgrep', '-ix', r'Balatro(\.exe)?'], stdout=subprocess.DEVNULL)
            if running.returncode != 1:
                raise ValueError('Close Balatro before installing (process check must succeed).')
            if args.update:
                update_mod(game, save)
            else:
                install(game, save)
        print('Steam > Properties > General > Launch Options:\n' + LAUNCH_OPTIONS)
    except (OSError, ValueError, zipfile.BadZipFile, KeyError) as error:
        parser.exit(1, 'Installation stopped: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
