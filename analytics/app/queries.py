from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from app.database import Database


PERIOD_DAYS = {"today": 0, "7d": 7, "30d": 30, "all": None}


def _since(period: str) -> str | None:
    if period not in PERIOD_DAYS:
        raise ValueError("period must be today, 7d, 30d, or all")
    days = PERIOD_DAYS[period]
    if days is None:
        return None
    now = datetime.now().astimezone()
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if days:
        start -= timedelta(days=days - 1)
    return start.isoformat()


def _where(since: str | None) -> tuple[str, tuple[Any, ...]]:
    return ("WHERE played_at >= ?", (since,)) if since else ("", ())


class AnalyticsQueries:
    def __init__(self, database: Database):
        self.database = database

    def dashboard(self, period: str) -> dict[str, Any]:
        since = _since(period)
        where, params = _where(since)
        with self.database.connect() as connection:
            metrics = dict(connection.execute(
                f"""SELECT COUNT(*) play_count, COALESCE(SUM(play_duration), 0) total_play_time,
                    COALESCE(AVG(skipped) * 100, 0) skip_rate,
                    COALESCE(AVG(completed) * 100, 0) completion_rate
                    FROM playback_events {where}""", params).fetchone())
            library_metrics = dict(connection.execute(
                """SELECT COUNT(*) library_count,
                    COALESCE(SUM(CASE WHEN favorite = 1 THEN 1 ELSE 0 END), 0) favorite_count
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
            daily = [dict(row) for row in connection.execute(
                f"""SELECT date(played_at, 'localtime') label, COUNT(*) value
                    FROM playback_events {where} GROUP BY label ORDER BY label""", params)]
            hourly = [dict(row) for row in connection.execute(
                f"""SELECT CAST(strftime('%H', played_at, 'localtime') AS INTEGER) label, COUNT(*) value
                    FROM playback_events {where} GROUP BY label ORDER BY label""", params)]
            top_tracks = self._top(connection, where, params, "COUNT(*)", "plays")
            skipped_tracks = self._top(connection, where, params, "SUM(skipped)", "skips", "HAVING SUM(skipped) > 0")
            artists = [dict(row) for row in connection.execute(
                f"""SELECT artist label, COUNT(*) value FROM playback_events {where}
                    GROUP BY artist ORDER BY value DESC, artist COLLATE NOCASE LIMIT 10""", params)]
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
                "topTracks": top_tracks, "skippedTracks": skipped_tracks, "artists": artists,
                "preferenceDistribution": preference_distribution}

    @staticmethod
    def _top(connection: Any, where: str, params: tuple[Any, ...], expression: str, alias: str,
             having: str = "") -> list[dict[str, Any]]:
        rows = connection.execute(
            f"""SELECT track_id trackId, MAX(track_title) title, MAX(artist) artist,
                {expression} value FROM playback_events {where} GROUP BY track_id {having}
                ORDER BY value DESC, title COLLATE NOCASE LIMIT 10""", params)
        return [dict(row) | {"metric": alias} for row in rows]

    def tracks(self, period: str, search: str = "") -> list[dict[str, Any]]:
        since = _since(period)
        event_conditions, params = [], []
        if since:
            event_conditions.append("played_at >= ?")
            params.append(since)
        search_conditions = []
        if search:
            search_conditions.append(
                "(c.title LIKE ? ESCAPE '\\' OR c.artist LIKE ? ESCAPE '\\' "
                "OR c.album LIKE ? ESCAPE '\\' OR c.genre LIKE ? ESCAPE '\\')"
            )
            escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            params.extend([f"%{escaped}%"] * 4)
        event_where = "WHERE " + " AND ".join(event_conditions) if event_conditions else ""
        search_where = "WHERE " + " AND ".join(search_conditions) if search_conditions else ""
        with self.database.connect() as connection:
            rows = connection.execute(
                f"""WITH filtered_events AS (
                        SELECT * FROM playback_events {event_where}
                    ), event_stats AS (
                        SELECT track_id, COUNT(*) play_count, SUM(play_duration) total_play_time,
                            AVG(completed) * 100 completion_rate, AVG(skipped) * 100 skip_rate,
                            MAX(played_at) last_played_at
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
                        c.duration, c.format, c.favorite,
                        CASE WHEN c.audio_fingerprint IS NULL THEN 0 ELSE 1 END hasFingerprint,
                        c.in_library inLibrary,
                        pp.playback_preference playbackPreference,
                        COALESCE(es.play_count, 0) playCount,
                        COALESCE(es.total_play_time, 0) totalPlayTime,
                        es.completion_rate completionRate, es.skip_rate skipRate,
                        es.last_played_at lastPlayedAt
                    FROM catalog c
                    LEFT JOIN event_stats es ON es.track_id = c.track_id
                    LEFT JOIN playback_preferences pp ON pp.track_id = c.track_id
                    {search_where}
                    ORDER BY playCount DESC, lastPlayedAt DESC, c.title COLLATE NOCASE
                    LIMIT 1000""", params)
            return [dict(row) for row in rows]

    def imports(self) -> list[dict[str, Any]]:
        with self.database.connect() as connection:
            rows = connection.execute(
                """SELECT id, imported_at importedAt, source_filename sourceFilename,
                    data_kind dataKind, new_count newCount, updated_count updatedCount,
                    duplicate_count duplicateCount, error_count errorCount,
                    error_details errorDetails FROM import_runs ORDER BY id DESC LIMIT 100""")
            return [dict(row) for row in rows]
