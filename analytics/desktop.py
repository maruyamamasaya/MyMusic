from __future__ import annotations

import os
import platform
import secrets
import socket
import sys
import threading
import time
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

import uvicorn

from app.config import Settings
from app.main import create_app


APP_NAME = "MyMusic Analytics"


def desktop_data_root(
    system: str | None = None,
    environment: dict[str, str] | None = None,
    home: Path | None = None,
) -> Path:
    system = system or platform.system()
    environment = environment or os.environ
    home = home or Path.home()
    override = environment.get("MYMUSIC_ANALYTICS_DESKTOP_ROOT")
    if override:
        return Path(override)
    if system == "Windows":
        base = environment.get("LOCALAPPDATA") or environment.get("APPDATA")
        if not base:
            base = str(home / "AppData" / "Local")
        return Path(base) / APP_NAME
    if system == "Darwin":
        return home / "Library" / "Application Support" / APP_NAME
    return Path(environment.get("XDG_DATA_HOME", home / ".local" / "share")) / "mymusic-analytics"


def desktop_settings(root: Path | None = None, token: str | None = None) -> Settings:
    root = root or desktop_data_root()
    data_dir = root / "data"
    return Settings(
        data_dir=data_dir,
        imports_dir=root / "imports",
        database_path=data_dir / "analytics.sqlite3",
        desktop_token=token,
    )


class LocalServer:
    def __init__(self, settings: Settings):
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.bind(("127.0.0.1", 0))
        self._socket.listen(128)
        self.port = self._socket.getsockname()[1]
        config = uvicorn.Config(
            create_app(settings), host="127.0.0.1", port=self.port,
            log_level="warning", access_log=False,
        )
        self._server = uvicorn.Server(config)
        self._thread = threading.Thread(
            target=self._server.run, kwargs={"sockets": [self._socket]},
            name="mymusic-analytics-server", daemon=True,
        )

    def start(self, timeout: float = 10.0) -> None:
        self._thread.start()
        deadline = time.monotonic() + timeout
        while not self._server.started and self._thread.is_alive():
            if time.monotonic() >= deadline:
                self.stop()
                raise TimeoutError("MyMusic Analytics server did not start in time.")
            time.sleep(0.02)
        if not self._server.started:
            raise RuntimeError("MyMusic Analytics server stopped during startup.")

    def stop(self, timeout: float = 5.0) -> None:
        self._server.should_exit = True
        if self._thread.is_alive():
            self._thread.join(timeout)
        try:
            self._socket.close()
        except OSError:
            pass


def main() -> int:
    if "--smoke-test" in sys.argv:
        token = secrets.token_urlsafe(32)
        server = LocalServer(desktop_settings(token=token))
        try:
            server.start()
            url = f"http://127.0.0.1:{server.port}/?desktopToken={quote(token)}"
            with urlopen(url, timeout=5) as response:
                if response.status != 200 or b"MyMusic Analytics" not in response.read():
                    raise RuntimeError("Desktop application did not serve its UI.")
        except Exception:
            return 1
        finally:
            server.stop()
        return 0

    import webview

    token = secrets.token_urlsafe(32)
    server = LocalServer(desktop_settings(token=token))
    server.start()
    url = f"http://127.0.0.1:{server.port}/?desktopToken={quote(token)}"
    webview.create_window(APP_NAME, url, width=1280, height=820, min_size=(960, 640))
    try:
        if platform.system() == "Windows":
            webview.start(gui="edgechromium", private_mode=False)
        else:
            webview.start(private_mode=False)
    finally:
        server.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
