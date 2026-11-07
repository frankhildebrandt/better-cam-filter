import subprocess
import unittest
from unittest.mock import patch

from import_signing import run
from release_version import release_version


class ReleaseConfigurationTests(unittest.TestCase):
    def test_release_and_prerelease_versions(self):
        for tag in ("v0.8.0", "0.8.0", "v0.8.0-beta.1"):
            self.assertEqual(release_version(tag, "3", "CURRENT_PROJECT_VERSION: '9'"), ("0.8.0", "12"))

    def test_untrusted_tag_is_rejected_before_it_reaches_shell_or_filenames(self):
        for tag in ("main", "v1.2", "v1.2.3/../../file", "v1.2.3;echo injected", "v1.2.3\nINJECT=1"):
            with self.assertRaises(ValueError):
                release_version(tag, "1", "CURRENT_PROJECT_VERSION: '9'")

    def test_invalid_build_cannot_be_published(self):
        for number in ("0", "bad", "10000"):
            with self.assertRaises(ValueError):
                release_version("v1.0.0", number, "CURRENT_PROJECT_VERSION: '9'")

    def test_failed_keychain_command_does_not_log_password_arguments(self):
        with patch("import_signing.subprocess.run", return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaises(SystemExit) as error:
                run(["security", "import", "certificate", "-P", "private-password"])
        self.assertNotIn("private-password", str(error.exception))


if __name__ == "__main__":
    unittest.main()
