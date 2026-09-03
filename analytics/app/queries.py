from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
import json
from typing import Any
from uuid import UUID

from app.database import Database


PERIOD_DAYS = {"today": 0, "7d": 7, "30d": 30, "all": None}
JAPAN_TIMEZONE = timezone(timedelta(hours=9))
SQLITE_JAPAN_TIMEZONE = "+09:00"
LEGACY_PLAYBACK_CUTOFF = "2026-09-01"
DETAIL_EVENT_PREDICATE = (
    f"date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'"
)
EARLY_SKIP_PREDICATE = f"{DETAIL_EVENT_PREDICATE} AND skipped = 1 AND play_duration <= 30"
INSIGHT_FEATURES = {
    "dark": "Dark", "calm": "Calm", "aggressive": "Aggressive", "piano": "Piano",
    "electronic": "Electronic", "ambient": "Ambient", "drumAndBass": "Drum & Bass",
    "vocal": "Vocal", "instrumental": "Instrumental",
}
TRACK_SORT_COLUMNS = {
    "title": "c.title COLLATE NOCASE", "artist": "c.artist COLLATE NOCASE",
    "album": "c.album COLLATE NOCASE", "preference": "pp.playback_preference",
    "playCount": "playCount", "totalPlayTime": "totalPlayTime",
    "completionRate": "completionRate", "skipRate": "skipRate",
    "earlySkipCount": "earlySkipCount", "earlySkipRate": "earlySkipRate",
    "lastPlayedAt": "lastPlayedAt",
}
SOURCE_SORT_COLUMNS = {
    "title": "sr.title COLLATE NOCASE", "subtitle": "sr.subtitle COLLATE NOCASE",
    "linked": "linked", "importedAt": "sr.imported_at",
}
RANKING_DIMENSIONS = {
    "tracks": ("e.track_id", "e.track_title", "e.artist"),
    "artists": ("e.artist", "e.artist", ""),
    "albums": ("COALESCE(NULLIF(e.album, ''), 'アルバム不明')",
               "COALESCE(NULLIF(e.album, ''), 'アルバム不明')", "e.artist"),
    "genres": ("COALESCE(NULLIF(lt.genre, ''), '未分類')",
               "COALESCE(NULLIF(lt.genre, ''), '未分類')", ""),
}


def _period_where(
    period: str, start_date: str | None = None, end_date: str | None = None,
) -> tuple[str, list[Any]]:
    if period == "custom":
        try:
            start = date.fromisoformat(start_date or "")
            end = date.fromisoformat(end_date or "")
        except ValueError as exc:
            raise ValueError("期間指定には開始日と終了日をYYYY-MM-DD形式で指定してください") from exc
        if start > end:
            raise ValueError("開始日は終了日以前にしてください")
        return (f"WHERE date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= ? "
                f"AND date(played_at, '{SQLITE_JAPAN_TIMEZONE}') <= ?",
                [start.isoformat(), end.isoformat()])
    since = _since(period)
    return (f"WHERE date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= ?", [since]) if since else ("", [])


def _since(period: str) -> str | None:
    if period not in PERIOD_DAYS:
        raise ValueError("period must be today, 7d, 30d, or all")
    days = PERIOD_DAYS[period]
    if days is None:
        return None
    start = datetime.now(JAPAN_TIMEZONE).date()
    if days:
        start -= timedelta(days=days - 1)
    return start.isoformat()


def _insights_event_where(
    period: str, start_date: str | None, end_date: str | None, quality: str,
) -> tuple[str, list[Any]]:
    where, params = _period_where(period, start_date, end_date)
    if quality not in {"analyzable", "all"}:
        raise ValueError("quality must be analyzable or all")
    if quality == "analyzable":
        quality_clause = f"date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= ?"
        where = f"{where} AND {quality_clause}" if where else f"WHERE {quality_clause}"
        params.append(LEGACY_PLAYBACK_CUTOFF)
    return where, params


class AnalyticsQueries:
    def __init__(self, database: Database):
        self.database = database

    def dashboard(
        self, period: str, start_date: str | None = None, end_date: str | None = None,
    ) -> dict[str, Any]:
        where, params = _period_where(period, start_date, end_date)
        with self.database.connect() as connection:
            metrics = dict(connection.execute(
                f"""SELECT COUNT(*) play_count,
                    COUNT(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN 1 END) detail_event_count,
                    SUM(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN play_duration END) total_play_time,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN skipped END) * 100 skip_rate,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN completed END) * 100 completion_rate,
                    COALESCE(SUM(CASE WHEN {EARLY_SKIP_PREDICATE}
                        THEN 1 ELSE 0 END), 0) early_skip_count,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                        * 100 early_skip_rate
                    FROM playback_events {where}""", params).fetchone())
            library_metrics = dict(connection.execute(
                """SELECT COUNT(*) library_count,
                    0 favorite_count
                    FROM library_tracks WHERE is_present = 1""").fetchone())
            preference_metrics = dict(connection.execute(
                """SELECT
                    COALESCE(SUM(CASE WHEN playback_preference != 0 THEN 1 ELSE 0 END), 0) rated_count,
                    COALESCE(SUM(CASE WHEN playback_preference > 0 THEN 1 ELSE 0 END), 0) good_count,
                    COALESCE(SUM(CASE WHEN playback_preference < 0 THEN 1 ELSE 0 END), 0) bad_count
                    FROM playback_preferences pp
                    JOIN library_tracks lt ON lt.track_id = pp.track_id
                    WHERE lt.is_present = 1""").fetchone())
            metrics.update(library_metrics)
            metrics.update(preference_metrics)
            metrics["favorite_count"] = connection.execute(
                """SELECT COUNT(*) FROM library_tracks lt LEFT JOIN playback_preferences pp
                   ON lt.track_id=pp.track_id
                   WHERE lt.is_present=1 AND COALESCE(pp.favorite, lt.favorite)=1"""
            ).fetchone()[0]
            daily = [dict(row) for row in connection.execute(
                f"""SELECT date(played_at, '{SQLITE_JAPAN_TIMEZONE}') label, COUNT(*) value
                    FROM playback_events {where} GROUP BY label ORDER BY label""", params)]
            hourly = [dict(row) for row in connection.execute(
                f"""SELECT CAST(strftime('%H', played_at, '{SQLITE_JAPAN_TIMEZONE}') AS INTEGER) label, COUNT(*) value
                    FROM playback_events {where} GROUP BY label ORDER BY label""", params)]
            top_tracks = self._top(connection, where, params, "COUNT(*)", "plays")
            skipped_tracks = self._top(
                connection, where, params,
                f"SUM(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}' THEN skipped END)",
                "skips", "HAVING value > 0",
            )
            early_skipped_tracks = [dict(row) for row in connection.execute(
                f"""SELECT track_id trackId, MAX(track_title) title, MAX(artist) artist,
                    COUNT(*) totalPlayCount,
                    SUM(CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1 ELSE 0 END) earlySkipCount,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                        THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                        * 100 earlySkipRate
                    FROM playback_events {where} GROUP BY track_id
                    HAVING earlySkipCount > 0
                    ORDER BY earlySkipCount DESC, earlySkipRate DESC, title COLLATE NOCASE
                    LIMIT 50""", params)]
            artists = [dict(row) for row in connection.execute(
                f"""SELECT artist label, COUNT(*) value FROM playback_events {where}
                    GROUP BY artist ORDER BY value DESC, artist COLLATE NOCASE LIMIT 50""", params)]
            preference_distribution = [dict(row) for row in connection.execute(
                """SELECT bucket label, COUNT(*) value FROM (
                    SELECT CASE
                        WHEN pp.track_id IS NULL THEN '未評価'
                        WHEN pp.playback_preference > 0 THEN 'Good'
                        WHEN pp.playback_preference < 0 THEN 'Bad'
                        ELSE 'Neutral'
                    END bucket
                    FROM library_tracks lt
                    LEFT JOIN playback_preferences pp ON pp.track_id = lt.track_id
                    WHERE lt.is_present = 1
                ) GROUP BY bucket ORDER BY
                    CASE bucket WHEN 'Good' THEN 1 WHEN 'Neutral' THEN 2
                        WHEN 'Bad' THEN 3 ELSE 4 END""")]
        return {"period": period, "metrics": metrics, "daily": daily, "hourly": hourly,
                "topTracks": top_tracks, "skippedTracks": skipped_tracks,
                "earlySkippedTracks": early_skipped_tracks, "artists": artists,
                "preferenceDistribution": preference_distribution}

    def music_history(self) -> dict[str, Any]:
        """Return a compact, read-only monthly timeline in JST."""
        with self.database.connect() as connection:
            rows = connection.execute(
                f"""SELECT strftime('%Y-%m', played_at, '{SQLITE_JAPAN_TIMEZONE}') month,
                    track_id, track_title, artist,
                    CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= ?
                        THEN play_duration END detailed_duration
                    FROM playback_events ORDER BY played_at""", (LEGACY_PLAYBACK_CUTOFF,)
            ).fetchall()
        months: dict[str, dict[str, Any]] = {}
        for row in rows:
            month = months.setdefault(row["month"], {
                "month": row["month"], "playCount": 0, "totalPlayTime": 0,
                "detailEventCount": 0, "tracks": {}, "artists": {},
            })
            month["playCount"] += 1
            if row["detailed_duration"] is not None:
                month["detailEventCount"] += 1
                month["totalPlayTime"] += row["detailed_duration"]
            track = month["tracks"].setdefault(
                row["track_id"], {"title": row["track_title"], "artist": row["artist"], "value": 0}
            )
            track["value"] += 1
            month["artists"][row["artist"]] = month["artists"].get(row["artist"], 0) + 1
        result = []
        for month in reversed(months.values()):
            top_track = sorted(month.pop("tracks").values(),
                               key=lambda item: (-item["value"], item["title"].casefold()))[0]
            top_artist, artist_count = sorted(
                month.pop("artists").items(), key=lambda item: (-item[1], item[0].casefold())
            )[0]
            month["topTrack"] = top_track
            month["topArtist"] = {"name": top_artist, "value": artist_count}
            result.append(month)
        return {"months": result, "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    def insights(
        self, period: str, start_date: str | None = None, end_date: str | None = None,
        quality: str = "analyzable",
    ) -> dict[str, Any]:
        """Aggregate playback behavior without constraining source/type values."""
        where, params = _insights_event_where(period, start_date, end_date, quality)
        with self.database.connect() as connection:
            by_source = self._behavior_breakdown(connection, where, params, ["play_source"])
            by_selection = self._behavior_breakdown(
                connection, where, params, ["selection_type"]
            )
            combinations = self._behavior_breakdown(
                connection, where, params, ["play_source", "selection_type"]
            )
        return {"period": period, "quality": quality, "byPlaySource": by_source,
                "bySelectionType": by_selection, "combinations": combinations,
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    def feature_insights(
        self, period: str, feature: str, start_date: str | None = None,
        end_date: str | None = None, quality: str = "analyzable",
    ) -> dict[str, Any]:
        if feature not in INSIGHT_FEATURES:
            raise ValueError("unsupported insight feature")
        event_where, event_params = _insights_event_where(
            period, start_date, end_date, quality
        )
        event_condition = (
            event_where.removeprefix("WHERE ").replace("played_at", "e.played_at") or "1=1"
        )
        feature_path = f"$.features.{feature}"
        with self.database.connect() as connection:
            analysis_version = connection.execute(
                """SELECT MAX(CAST(json_extract(raw_json, '$.analysisVersion') AS INTEGER))
                   FROM source_records WHERE data_kind='track_features'
                   AND json_type(raw_json, '$.analysisVersion')='integer'"""
            ).fetchone()[0]
            rows = connection.execute(
                f"""WITH feature_tracks AS (
                    SELECT sr.track_id,
                        CAST(json_extract(sr.raw_json, ?) AS REAL) feature_value
                    FROM source_records sr
                    WHERE sr.data_kind='track_features' AND sr.track_id IS NOT NULL
                        AND json_type(sr.raw_json, '$.analysisVersion')='integer'
                        AND CAST(json_extract(sr.raw_json, '$.analysisVersion') AS INTEGER)=?
                        AND json_type(sr.raw_json, ?) IN ('integer', 'real')
                        AND json_extract(sr.raw_json, ?) BETWEEN 0.0 AND 1.0
                ), bins(binIndex, label, lowerBound, upperBound, upperInclusive) AS (
                    VALUES (0, '0.0–0.2', 0.0, 0.2, 0),
                           (1, '0.2–0.4', 0.2, 0.4, 0),
                           (2, '0.4–0.6', 0.4, 0.6, 0),
                           (3, '0.6–0.8', 0.6, 0.8, 0),
                           (4, '0.8–1.0', 0.8, 1.0, 1)
                )
                SELECT b.binIndex, b.label, b.lowerBound, b.upperBound, b.upperInclusive,
                    COUNT(DISTINCT ft.track_id) trackCount, COUNT(e.event_id) playCount,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE.replace('played_at', 'e.played_at')}
                        THEN e.completed END) * 100 completionRate,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE.replace('played_at', 'e.played_at')}
                        THEN e.skipped END) * 100 skipRate,
                    AVG(CASE WHEN {DETAIL_EVENT_PREDICATE.replace('played_at', 'e.played_at')}
                        THEN CASE WHEN {EARLY_SKIP_PREDICATE.replace('played_at', 'e.played_at').replace('skipped', 'e.skipped').replace('play_duration', 'e.play_duration')}
                            THEN 1.0 ELSE 0.0 END END) * 100 earlySkipRate
                FROM bins b
                LEFT JOIN feature_tracks ft ON ft.feature_value >= b.lowerBound
                    AND (ft.feature_value < b.upperBound
                        OR (b.upperInclusive=1 AND ft.feature_value <= b.upperBound))
                LEFT JOIN playback_events e ON e.track_id=ft.track_id
                    AND ({event_condition})
                GROUP BY b.binIndex ORDER BY b.binIndex""",
                (feature_path, analysis_version, feature_path, feature_path, *event_params),
            ).fetchall()
        return {"period": period, "quality": quality, "feature": feature,
                "featureLabel": INSIGHT_FEATURES[feature],
                "analysisVersion": analysis_version, "bins": [dict(row) for row in rows],
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    @staticmethod
    def _behavior_breakdown(
        connection: Any, where: str, params: list[Any], dimensions: list[str],
    ) -> list[dict[str, Any]]:
        aliases = {"play_source": "playSource", "selection_type": "selectionType"}
        dimension_sql = ", ".join(
            f"{column} {aliases[column]}" for column in dimensions
        )
        group_sql = ", ".join(dimensions)
        rows = connection.execute(
            f"""SELECT {dimension_sql}, COUNT(*) playCount,
                SUM(CASE WHEN {DETAIL_EVENT_PREDICATE} THEN play_duration END) totalPlayTime,
                AVG(CASE WHEN {DETAIL_EVENT_PREDICATE} THEN completed END) * 100 completionRate,
                AVG(CASE WHEN {DETAIL_EVENT_PREDICATE} THEN skipped END) * 100 skipRate,
                CASE WHEN COUNT(CASE WHEN {DETAIL_EVENT_PREDICATE} THEN 1 END) = 0 THEN NULL
                    ELSE SUM(CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1 ELSE 0 END)
                    END earlySkipCount,
                AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                    THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                    * 100 earlySkipRate,
                COUNT(CASE WHEN {DETAIL_EVENT_PREDICATE} THEN 1 END) detailEventCount
                FROM playback_events {where}
                GROUP BY {group_sql}
                ORDER BY playCount DESC, {group_sql} COLLATE NOCASE""", params
        ).fetchall()
        return [dict(row) for row in rows]

    def rankings(
        self, period: str, dimension: str, metric: str,
        start_date: str | None = None, end_date: str | None = None,
    ) -> dict[str, Any]:
        if dimension not in RANKING_DIMENSIONS:
            raise ValueError("dimension must be tracks, artists, albums, or genres")
        if metric not in {"plays", "duration"}:
            raise ValueError("metric must be plays or duration")
        where, params = _period_where(period, start_date, end_date)
        key, label, subtitle = RANKING_DIMENSIONS[dimension]
        value = "COUNT(*)" if metric == "plays" else (
            f"SUM(CASE WHEN date(e.played_at, '{SQLITE_JAPAN_TIMEZONE}') >= "
            f"'{LEGACY_PLAYBACK_CUTOFF}' THEN e.play_duration ELSE 0 END)"
        )
        qualified_where = where.replace("played_at", "e.played_at")
        subtitle_select = f"MAX({subtitle})" if subtitle else "NULL"
        having = "HAVING value > 0" if metric == "duration" else ""
        with self.database.connect() as connection:
            rows = connection.execute(
                f"""SELECT {key} itemKey, MAX({label}) label, {subtitle_select} subtitle,
                    {value} value
                    FROM playback_events e
                    LEFT JOIN library_tracks lt ON lt.track_id=e.track_id AND lt.is_present=1
                    {qualified_where}
                    GROUP BY {key}
                    {having}
                    ORDER BY value DESC, label COLLATE NOCASE
                    LIMIT 50""", params
            ).fetchall()
        return {"period": period, "dimension": dimension, "metric": metric,
                "items": [dict(row) for row in rows],
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    @staticmethod
    def _top(connection: Any, where: str, params: tuple[Any, ...], expression: str, alias: str,
             having: str = "") -> list[dict[str, Any]]:
        rows = connection.execute(
            f"""SELECT track_id trackId, MAX(track_title) title, MAX(artist) artist,
                {expression} value FROM playback_events {where} GROUP BY track_id {having}
                ORDER BY value DESC, title COLLATE NOCASE LIMIT 50""", params)
        return [dict(row) | {"metric": alias} for row in rows]

    def tracks(
        self, period: str, search: str = "", start_date: str | None = None,
        end_date: str | None = None, title: str = "", artist: str = "",
        album: str = "", genre: str = "", sort: str = "playCount",
        order: str = "desc", page: int = 1, page_size: int = 200,
    ) -> dict[str, Any]:
        event_where, params = _period_where(period, start_date, end_date)
        if sort not in TRACK_SORT_COLUMNS:
            raise ValueError("unsupported track sort")
        if order not in {"asc", "desc"}:
            raise ValueError("order must be asc or desc")
        search_conditions = []
        if search:
            search_conditions.append(
                "(c.title LIKE ? ESCAPE '\\' OR c.artist LIKE ? ESCAPE '\\' "
                "OR c.album LIKE ? ESCAPE '\\' OR c.genre LIKE ? ESCAPE '\\')"
            )
            escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            params.extend([f"%{escaped}%"] * 4)
        for column, value in (("title", title), ("artist", artist), ("album", album), ("genre", genre)):
            if value:
                search_conditions.append(f"c.{column} LIKE ? ESCAPE '\\'")
                escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
                params.append(f"%{escaped}%")
        search_where = "WHERE " + " AND ".join(search_conditions) if search_conditions else ""
        sort_column, sort_order = TRACK_SORT_COLUMNS[sort], order.upper()
        with self.database.connect() as connection:
            rows = connection.execute(
                f"""WITH filtered_events AS (
                        SELECT * FROM playback_events {event_where}
                    ), event_stats AS (
                        SELECT track_id, COUNT(*) play_count,
                            SUM(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'
                                THEN play_duration END) total_play_time,
                            AVG(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'
                                THEN completed END) * 100 completion_rate,
                            AVG(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'
                                THEN skipped END) * 100 skip_rate,
                            MAX(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'
                                THEN played_at END) last_played_at,
                            COUNT(CASE WHEN date(played_at, '{SQLITE_JAPAN_TIMEZONE}') >= '{LEGACY_PLAYBACK_CUTOFF}'
                                THEN 1 END) detail_event_count,
                            SUM(CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1 ELSE 0 END) early_skip_count,
                            AVG(CASE WHEN {DETAIL_EVENT_PREDICATE}
                                THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                                * 100 early_skip_rate
                        FROM filtered_events GROUP BY track_id
                    ), event_catalog AS (
                        SELECT track_id, MAX(track_title) title, MAX(artist) artist, MAX(album) album,
                            MAX(track_duration) duration
                        FROM playback_events GROUP BY track_id
                    ), catalog AS (
                        SELECT track_id, title, artist, album, genre, year, duration, format,
                            favorite, audio_fingerprint, 1 in_library
                        FROM library_tracks WHERE is_present = 1
                        UNION ALL
                        SELECT ec.track_id, ec.title, ec.artist, ec.album, NULL, NULL,
                            ec.duration, NULL, NULL, NULL, 0
                        FROM event_catalog ec
                        WHERE NOT EXISTS (
                            SELECT 1 FROM library_tracks lt
                            WHERE lt.track_id = ec.track_id AND lt.is_present = 1
                        )
                    )
                    SELECT c.track_id trackId, c.title, c.artist, c.album, c.genre, c.year,
                        c.duration, c.format, COALESCE(pp.favorite, c.favorite) favorite,
                        CASE WHEN c.audio_fingerprint IS NULL THEN 0 ELSE 1 END hasFingerprint,
                        c.in_library inLibrary,
                        pp.playback_preference playbackPreference,
                        COALESCE(es.play_count, 0) playCount,
                        es.total_play_time totalPlayTime,
                        es.completion_rate completionRate, es.skip_rate skipRate,
                        COALESCE(es.early_skip_count, 0) earlySkipCount,
                        es.early_skip_rate earlySkipRate,
                        es.last_played_at lastPlayedAt,
                        COALESCE(es.detail_event_count, 0) detailEventCount,
                        COUNT(*) OVER() totalCount
                    FROM catalog c
                    LEFT JOIN event_stats es ON es.track_id = c.track_id
                    LEFT JOIN playback_preferences pp ON pp.track_id = c.track_id
                    {search_where}
                    ORDER BY {sort_column} {sort_order}, c.title COLLATE NOCASE, c.track_id
                    LIMIT ? OFFSET ?""", (*params, page_size, (page - 1) * page_size)).fetchall()
            total = rows[0]["totalCount"] if rows else 0
            items = []
            for row in rows:
                item = dict(row)
                item.pop("totalCount")
                items.append(item)
            return {"items": items, "total": total}

    def imports(self) -> list[dict[str, Any]]:
        with self.database.connect() as connection:
            rows = connection.execute(
                """SELECT id, imported_at importedAt, source_filename sourceFilename,
                    data_kind dataKind, new_count newCount, updated_count updatedCount,
                    duplicate_count duplicateCount, error_count errorCount,
                    error_details errorDetails FROM import_runs ORDER BY id DESC LIMIT 100""")
            return [dict(row) for row in rows]

    def update_preference(
        self, track_id: str, playback_preference: int, favorite: bool
    ) -> dict[str, Any]:
        with self.database.connect() as connection:
            existing = connection.execute(
                "SELECT track_id FROM playback_preferences WHERE track_id=?", (track_id,)
            ).fetchone()
            if existing is None:
                raise LookupError("Import済みの再生傾向がありません。")
            edited_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
            raw = json.dumps(
                {"trackId": track_id, "playbackPreference": playback_preference,
                 "favorite": favorite},
                ensure_ascii=False, sort_keys=True, separators=(",", ":"),
            )
            connection.execute(
                """UPDATE playback_preferences
                   SET playback_preference=?, favorite=?, exported_at=?, imported_at=?, raw_json=?
                   WHERE track_id=?""",
                (playback_preference, int(favorite), edited_at, edited_at, raw, track_id),
            )
        return {"trackId": track_id, "playbackPreference": playback_preference,
                "favorite": favorite}

    def export_preferences(self) -> dict[str, Any]:
        with self.database.connect() as connection:
            rows = connection.execute(
                """SELECT pp.track_id, pp.playback_preference, pp.favorite
                   FROM playback_preferences pp
                   JOIN library_tracks lt ON lt.track_id=pp.track_id
                   WHERE lt.is_present=1 ORDER BY pp.track_id"""
            ).fetchall()
        tracks = []
        for row in rows:
            try:
                UUID(row["track_id"])
            except (ValueError, AttributeError):
                continue
            tracks.append({"trackId": row["track_id"],
                           "playbackPreference": row["playback_preference"],
                           "favorite": bool(row["favorite"]) if row["favorite"] is not None else False})
        return {"schemaVersion": 2,
                "exportedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "tracks": tracks}

    def sources(
        self, data_kind: str, page: int = 1, page_size: int = 200,
        sort: str = "title", order: str = "asc",
    ) -> dict[str, Any]:
        allowed = {"track_features", "volume_normalization", "playlists", "equalizer", "genre_presets"}
        if data_kind not in allowed:
            raise ValueError("unsupported source kind")
        if sort not in SOURCE_SORT_COLUMNS:
            raise ValueError("unsupported source sort")
        if order not in {"asc", "desc"}:
            raise ValueError("order must be asc or desc")
        sort_column = SOURCE_SORT_COLUMNS[sort]
        with self.database.connect() as connection:
            rows = connection.execute(
                f"""SELECT sr.item_key, sr.track_id, sr.title, sr.subtitle, sr.imported_at,
                    sr.raw_json, CASE WHEN lt.track_id IS NULL THEN 0 ELSE 1 END linked
                    FROM source_records sr
                    LEFT JOIN library_tracks lt ON lt.track_id=sr.track_id AND lt.is_present=1
                    WHERE sr.data_kind=? ORDER BY {sort_column} {order.upper()}, sr.item_key
                    LIMIT ? OFFSET ?""", (data_kind, page_size, (page - 1) * page_size)
            ).fetchall()
            total = connection.execute(
                "SELECT COUNT(*) FROM source_records WHERE data_kind=?", (data_kind,)
            ).fetchone()[0]
            linked_total = connection.execute(
                """SELECT COUNT(*) FROM source_records sr JOIN library_tracks lt
                   ON lt.track_id=sr.track_id AND lt.is_present=1 WHERE sr.data_kind=?""",
                (data_kind,),
            ).fetchone()[0]
            library_ids = {row[0] for row in connection.execute(
                "SELECT track_id FROM library_tracks WHERE is_present=1"
            )}
        items = []
        for row in rows:
            raw = json.loads(row["raw_json"])
            item = {"key": row["item_key"], "trackId": row["track_id"], "title": row["title"],
                    "subtitle": row["subtitle"], "importedAt": row["imported_at"],
                    "linked": bool(row["linked"]), "data": raw}
            if data_kind == "playlists":
                tracks = raw.get("tracks", [])
                item["trackCount"] = len(tracks)
                item["linkedTrackCount"] = sum(1 for track in tracks if track.get("trackID") in library_ids)
            items.append(item)
        return {"dataKind": data_kind, "count": total, "pageCount": len(items),
                "linkedCount": linked_total, "items": items}
