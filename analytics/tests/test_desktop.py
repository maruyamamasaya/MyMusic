from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app
from desktop import LocalServer, desktop_data_root, desktop_settings


class DesktopConfigurationTests(unittest.TestCase):
    def test_windows_data_root_prefers_local_app_data(self):
        root = desktop_data_root(
            system="Windows",
            environment={"LOCALAPPDATA": r"C:\Users\tester\AppData\Local"},
            home=Path(r"C:\Users\tester"),
        )
        self.assertEqual(root, Path(r"C:\Users\tester\AppData\Local\MyMusic Analytics"))

    def test_macos_data_root_uses_application_support(self):
        root = desktop_data_root(system="Darwin", environment={}, home=Path("/Users/tester"))
        self.assertEqual(root, Path("/Users/tester/Library/Application Support/MyMusic Analytics"))

    def test_explicit_data_root_override_is_cross_platform(self):
        root = desktop_data_root(
            system="Windows",
            environment={"MYMUSIC_ANALYTICS_DESKTOP_ROOT": "portable-data"},
            home=Path("unused"),
        )
        self.assertEqual(root, Path("portable-data"))

    def test_desktop_settings_keep_database_and_imports_under_app_root(self):
        root = Path("app-data")
        settings = desktop_settings(root, token="secret")
        self.assertEqual(settings.database_path, root / "data" / "analytics.sqlite3")
        self.assertEqual(settings.imports_dir, root / "imports")
        self.assertEqual(settings.desktop_token, "secret")

    def test_desktop_token_protects_api_and_sets_session_cookie(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = desktop_settings(Path(temporary), token="secret")
            with TestClient(create_app(settings)) as client:
                self.assertEqual(client.get("/api/health").status_code, 403)
                response = client.get("/?desktopToken=secret")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(client.get("/api/health").status_code, 200)

    def test_local_server_uses_an_available_port_and_stops(self):
        with tempfile.TemporaryDirectory() as temporary:
            server = LocalServer(desktop_settings(Path(temporary), token="secret"))
            try:
                server.start()
                self.assertGreater(server.port, 0)
                self.assertTrue(server._thread.is_alive())
            finally:
                server.stop()
            self.assertFalse(server._thread.is_alive())


if __name__ == "__main__":
    unittest.main()
