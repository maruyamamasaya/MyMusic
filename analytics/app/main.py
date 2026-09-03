from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, Query, Request, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import ROOT_DIR, Settings
from app.database import Database
from app.queries import AnalyticsQueries, LEGACY_PLAYBACK_CUTOFF
from importer.service import ImportService
from importer.schema import PlaybackPreferenceUpdate


def create_app(settings: Settings | None = None) -> FastAPI:
    configured = settings or Settings.from_environment()
    database = Database(configured.database_path)
    queries = AnalyticsQueries(database)
    importer = ImportService(database, configured.imports_dir)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        configured.ensure_directories()
        database.initialize()
        yield

    app = FastAPI(title="MyMusic Analytics", version="0.1.0", lifespan=lifespan)
    app.state.settings = configured
    app.mount("/static", StaticFiles(directory=ROOT_DIR / "web"), name="static")

    @app.get("/", include_in_schema=False)
    def index() -> FileResponse:
        return FileResponse(ROOT_DIR / "web" / "index.html")

    @app.get("/api/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/dashboard")
    def dashboard(
        period: str = Query("7d"), startDate: str | None = Query(None),
        endDate: str | None = Query(None),
    ):
        try:
            return queries.dashboard(period, startDate, endDate) | {
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF
            }
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/tracks")
    def tracks(
        period: str = Query("all"), search: str = Query("", max_length=200),
        startDate: str | None = Query(None), endDate: str | None = Query(None),
        title: str = Query("", max_length=200), artist: str = Query("", max_length=200),
        album: str = Query("", max_length=200), genre: str = Query("", max_length=200),
        sort: str = Query("playCount"), order: str = Query("desc"),
        page: int = Query(1, ge=1),
    ):
        try:
            result = queries.tracks(
                period, search.strip(), startDate, endDate, title.strip(), artist.strip(),
                album.strip(), genre.strip(), sort, order, page,
            )
            return {"tracks": result["items"], "total": result["total"], "page": page,
                    "pageSize": 200, "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/music-history")
    def music_history():
        return queries.music_history()

    @app.get("/api/insights")
    def insights(
        period: str = Query("7d"), startDate: str | None = Query(None),
        endDate: str | None = Query(None), quality: str = Query("analyzable"),
    ):
        try:
            return queries.insights(period, startDate, endDate, quality)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/insights/features")
    def feature_insights(
        feature: str = Query("dark"), period: str = Query("7d"),
        startDate: str | None = Query(None), endDate: str | None = Query(None),
        quality: str = Query("analyzable"),
    ):
        try:
            return queries.feature_insights(period, feature, startDate, endDate, quality)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/insights/recent-changes")
    def recent_changes(
        period: str = Query("7d"), startDate: str | None = Query(None),
        endDate: str | None = Query(None), quality: str = Query("analyzable"),
    ):
        try:
            return queries.recent_changes(period, startDate, endDate, quality)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/insights/advanced")
    def advanced_insights(
        period: str = Query("7d"), startDate: str | None = Query(None),
        endDate: str | None = Query(None), quality: str = Query("analyzable"),
    ):
        try:
            return queries.advanced_insights(period, startDate, endDate, quality)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/insights/recommendations")
    def recommendations(
        period: str = Query("7d"), startDate: str | None = Query(None),
        endDate: str | None = Query(None), quality: str = Query("analyzable"),
    ):
        try:
            return queries.recommendations(period, startDate, endDate, quality)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/rankings")
    def rankings(
        period: str = Query("30d"), dimension: str = Query("tracks"),
        metric: str = Query("plays"), startDate: str | None = Query(None),
        endDate: str | None = Query(None),
    ):
        try:
            return queries.rankings(period, dimension, metric, startDate, endDate)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    @app.get("/api/imports")
    def imports():
        return {"imports": queries.imports()}

    @app.get("/api/preferences/export")
    def export_preferences() -> JSONResponse:
        return JSONResponse(
            queries.export_preferences(),
            headers={"Content-Disposition":
                     'attachment; filename="MyMusic-Playback-Preferences.json"'},
        )

    @app.put("/api/preferences/{track_id}")
    def update_preference(track_id: str, update: PlaybackPreferenceUpdate):
        try:
            return queries.update_preference(track_id, update.playbackPreference, update.favorite)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.get("/api/sources/{data_kind}")
    def sources(
        data_kind: str, page: int = Query(1, ge=1), sort: str = Query("title"),
        order: str = Query("asc"),
    ):
        try:
            result = queries.sources(data_kind, page, sort=sort, order=order)
            return result | {"page": page, "pageSize": 200}
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.post("/api/import")
    async def import_json(request: Request, file: UploadFile = File(...)):
        if not (file.filename or "").lower().endswith(".json"):
            raise HTTPException(status_code=415, detail="JSONファイルを選択してください。")
        content = await file.read(configured.max_import_bytes + 1)
        if len(content) > configured.max_import_bytes:
            raise HTTPException(status_code=413, detail="ファイルは20 MB以下にしてください。")
        if not content:
            raise HTTPException(status_code=400, detail="ファイルが空です。")
        return importer.import_bytes(content, file.filename or "import.json")

    return app


app = create_app()
