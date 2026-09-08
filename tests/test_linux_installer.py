"""Installer integration tests using disposable game, Steam and Proton fixtures."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('linux_installer', Path(__file__).resolve().parents[1] / 'install-linux.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.root = self.base / 'checkout'
        (self.root / 'mod').mkdir(parents=True)
        (self.root / 'mod/lovely.toml').write_text('test mod')

    def library(self, root):
        game = root / 'steamapps/common/Balatro'
        game.mkdir(parents=True)
        (game / 'Balatro.exe').write_bytes(b'test game')
        (game / 'lua51.dll').write_bytes(b'test lua')
        prefix = root / 'steamapps/compatdata/2379780/pfx'
        save = prefix / 'drive_c/users/steamuser/AppData/Roaming/Balatro'
        save.mkdir(parents=True)
        (save / 'profile.jkr').write_bytes(b'original save')
        return game.resolve(), save.resolve(), prefix.resolve()

    def archive(self):
        archive = self.root / '.cache/lovely-v0.9.0.zip'
        archive.parent.mkdir()
        with zipfile.ZipFile(archive, 'w') as packed:
            packed.writestr('version.dll', b'test loader')
        return installer.digest(archive)

    def test_default_steam(self):
        game, save, _ = self.library(self.home / '.local/share/Steam')
        self.assertEqual(installer.locate(self.home), (game, save))

    def test_flatpak(self):
        game, save, _ = self.library(self.home / '.var/app/com.valvesoftware.Steam/.local/share/Steam')
        self.assertEqual(installer.locate(self.home), (game, save))

    def test_external_library_with_spaces(self):
        game, save, _ = self.library(self.base / 'external disk/SteamLibrary')
        steamapps = self.home / '.local/share/Steam/steamapps'
        steamapps.mkdir(parents=True)
        (steamapps / 'libraryfolders.vdf').write_text('"libraryfolders" { "1" { "path" "' + str(game.parent.parent.parent).replace('\\', '\\\\') + '" } }')
        self.assertEqual(installer.locate(self.home), (game, save))

    def test_ambiguous_prefix_requires_explicit_choice(self):
        game, save, prefix = self.library(self.home / '.local/share/Steam')
        self.library(self.home / '.var/app/com.valvesoftware.Steam/.local/share/Steam')
        with self.assertRaisesRegex(ValueError, 'Proton prefix'):
            installer.locate(self.home, str(game))
        self.assertEqual(installer.locate(self.home, str(game), str(prefix)), (game, save))

    def test_uninitialized_prefix(self):
        with self.assertRaisesRegex(ValueError, 'Proton prefix'):
            game, _, _ = self.library(self.base / 'custom')
            installer.locate(self.home, str(game), str(self.base / 'missing'))

    def test_full_install_preserves_and_backs_up(self):
        game, save, _ = self.library(self.home / '.local/share/Steam')
        with patch.object(installer, 'ARCHIVE_HASH', self.archive()):
            installer.install(game, save, self.root)
        self.assertEqual((game / 'version.dll').read_bytes(), b'test loader')
        self.assertEqual((save / 'Mods/Yubalatro/lovely.toml').read_text(), 'test mod')
        self.assertEqual((save / 'profile.jkr').read_bytes(), b'original save')
        backup = next((self.root / 'backups').iterdir())
        self.assertEqual((backup / 'game/Balatro.exe').read_bytes(), b'test game')
        self.assertEqual((backup / 'save/profile.jkr').read_bytes(), b'original save')
        self.assertTrue((self.root / 'installation-linux.txt').is_file())
        with self.assertRaisesRegex(ValueError, 'already installed'):
            installer.install(game, save, self.root)

    def test_rejects_existing_loader_and_bad_download(self):
        game, save, _ = self.library(self.home / '.local/share/Steam')
        (game / 'version.dll').write_bytes(b'other loader')
        with self.assertRaisesRegex(ValueError, 'existing version.dll'):
            installer.install(game, save, self.root)
        self.assertEqual((game / 'version.dll').read_bytes(), b'other loader')
        (game / 'version.dll').unlink()
        self.archive()
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            installer.install(game, save, self.root)
        self.assertFalse((game / 'version.dll').exists())
        self.assertFalse((save / 'Mods').exists())

    def test_repository_inside_game_is_rejected(self):
        game, save, _ = self.library(self.home / '.local/share/Steam')
        with self.assertRaisesRegex(ValueError, 'outside the game'):
            installer.install(game, save, game / 'checkout')

    def test_update_preserves_settings_loader_and_old_mod_backup(self):
        game, save, _ = self.library(self.home / '.local/share/Steam')
        with patch.object(installer, 'ARCHIVE_HASH', self.archive()):
            installer.install(game, save, self.root)
        (save / 'yubalatro-settings.txt').write_text('dollars=123')
        (self.root / 'mod/lovely.toml').write_text('updated mod')
        installer.update_mod(game, save, self.root)
        self.assertEqual((save / 'Mods/Yubalatro/lovely.toml').read_text(), 'updated mod')
        self.assertEqual((save / 'yubalatro-settings.txt').read_text(), 'dollars=123')
        self.assertEqual((save / 'profile.jkr').read_bytes(), b'original save')
        self.assertEqual((game / 'version.dll').read_bytes(), b'test loader')
        backup = next((self.root / 'backups').glob('linux-mod-update-*'))
        self.assertEqual((backup / 'Yubalatro/lovely.toml').read_text(), 'test mod')


if __name__ == '__main__':
    unittest.main()
