import importlib.util
import pathlib
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('signing', pathlib.Path(__file__).with_name('check-signing.py'))
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def test_rejects_adhoc_candidate(self):
        with patch.object(signing, 'stable', return_value=False):
            with self.assertRaisesRegex(ValueError, 'unstable'):
                signing.check(pathlib.Path('candidate'), pathlib.Path('installed'))

    def test_accepts_changed_binary_with_same_requirement(self):
        with patch.object(signing, 'stable', return_value=True), \
             patch.object(pathlib.Path, 'exists', return_value=True), \
             patch.object(signing, 'requirement', return_value='identifier "app.lilt.reader.dev" and anchor H"abc"'), \
             patch.object(signing, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            signing.check(pathlib.Path('candidate'), pathlib.Path('installed'))
            self.assertTrue(run.call_args.args[-2].startswith('-R='))
            self.assertIn('anchor H"abc"', run.call_args.args[-2])

    def test_blocks_certificate_change_without_explicit_migration(self):
        with patch.object(signing, 'stable', return_value=True), \
             patch.object(pathlib.Path, 'exists', return_value=True), \
             patch.object(signing, 'requirement', return_value='old requirement'), \
             patch.object(signing, 'run', return_value=subprocess.CompletedProcess([], 1)), \
             patch.dict(signing.os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'Signing identity changed'):
                signing.check(pathlib.Path('candidate'), pathlib.Path('installed'))


if __name__ == '__main__':
    unittest.main()
