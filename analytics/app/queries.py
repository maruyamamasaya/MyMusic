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
RECENT_CHANGE_ALL_DAYS = 30
RECENT_TRACK_MIN_PLAYS = 3
RECENT_TRACK_MIN_DETAILS = 3
HOOKED_PLAY_GROWTH_RATIO = 2.0
HOOKED_PLAY_GROWTH_MINIMUM = 2
HOOKED_MAX_SKIP_RATE = 70.0
BORED_RATE_WORSENING_POINTS = 20.0
NEW_TASTE_MIN_DETAILS = 3
NEW_TASTE_RATE_IMPROVEMENT_POINTS = 15.0
NEW_TASTE_SCORE_MINIMUM = 0.6
REDISCOVERY_MIN_DETAIL_PLAYS = 3
REDISCOVERY_MIN_COMPLETION_RATE = 70.0
ENTITY_GROWTH_RATIO = 1.5
ENTITY_GROWTH_MINIMUM = 2
ENTITY_GOOD_COMPLETION_RATE = 70.0
TIME_FEATURE_MIN_DETAILS = 3
LISTENING_PROFILE_MIN_DETAILS = 5
PROFILE_STRONG_THRESHOLD = 50.0
PROFILE_POSITIVE_THRESHOLD = 20.0
RECOMMENDATION_FEATURE_MATCH_MINIMUM = 0.55
DISCOVERY_MAX_PLAYS = 2
TRACK_SORT_COLUMNS = {
    "title": "c.title COLLATE NOCASE", "artist": "c.artist COLLATE NOCASE",
    "album": "c.album COLLATE NOCASE", "preference": "pp.playback_preference",
    "favorite": "COALESCE(pp.favorite, c.favorite)",
    "fingerprint": "hasFingerprint",
    "playCount": "playCount", "totalPlayTime": "totalPlayTime",
    "completionRate": "completionRate", "skipRate": "skipRate",
    "earlySkipCount": "earlySkipCount", "earlySkipRate": "earlySkipRate",
    "lastPlayedAt": "lastPlayedAt",
}
SOURCE_COMMON_SORT_COLUMNS = {
    "title": "sr.title COLLATE NOCASE", "subtitle": "sr.subtitle COLLATE NOCASE",
    "linked": "linked", "importedAt": "sr.imported_at",
}
TRACK_FEATURE_KEY_ORDER = (
    "tempo", "energy",
    "vocal", "instrumental", "piano", "electronic", "ambient", "drumAndBass",
    "aggressive", "calm", "bright", "dark",
    "integratedLUFS", "truePeakDBTP", "normalizationGainDB",
)
SOURCE_KIND_SORT_COLUMNS = {
    "track_features": {
        "tempo": "CAST(json_extract(sr.raw_json, '$.features.tempo') AS REAL)",
        "energy": "CAST(json_extract(sr.raw_json, '$.features.energy') AS REAL)",
        "vocal": "CAST(json_extract(sr.raw_json, '$.features.vocal') AS REAL)",
        "analysisVersion": "CAST(json_extract(sr.raw_json, '$.analysisVersion') AS INTEGER)",
    },
    "volume_normalization": {
        "integratedLUFS": "CAST(json_extract(sr.raw_json, '$.integratedLUFS') AS REAL)",
        "truePeakDBTP": "CAST(json_extract(sr.raw_json, '$.truePeakDBTP') AS REAL)",
        "normalizationGainDB": "CAST(json_extract(sr.raw_json, '$.normalizationGainDB') AS REAL)",
        "relativePath": "json_extract(sr.raw_json, '$.relativePath') COLLATE NOCASE",
    },
    "playlists": {
        "kind": "json_extract(sr.raw_json, '$.kind') COLLATE NOCASE",
        "tags": "json_extract(sr.raw_json, '$.tags') COLLATE NOCASE",
        "trackCount": "json_array_length(json_extract(sr.raw_json, '$.tracks'))",
        "linkedTrackCount": "(SELECT COUNT(*) FROM json_each(sr.raw_json, '$.tracks') jt "
                            "JOIN library_tracks linked_lt "
                            "ON linked_lt.track_id=json_extract(jt.value, '$.trackID') "
                            "AND linked_lt.is_present=1)",
        "updatedAt": "json_extract(sr.raw_json, '$.updatedAt')",
    },
    "equalizer": {
        "recordType": "json_extract(sr.raw_json, '$.recordType') COLLATE NOCASE",
        "enabled": "CAST(json_extract(sr.raw_json, '$.isEnabled') AS INTEGER)",
        "preamp": "CAST(json_extract(sr.raw_json, '$.preamp') AS REAL)",
        "gains": "COALESCE(json_extract(sr.raw_json, '$.gains'), json_extract(sr.raw_json, '$.bands'))",
    },
    "genre_presets": {
        "genreCount": "json_array_length(json_extract(sr.raw_json, '$.enabledGenreNames'))",
        "genres": "json_extract(sr.raw_json, '$.enabledGenreNames') COLLATE NOCASE",
        "unassigned": "CAST(json_extract(sr.raw_json, '$.includesUnassignedGenreSetting') AS INTEGER)",
    },
}
GENRE_PARTS_CTE = """genre_parts(track_id, rest, genre) AS (
    SELECT track_id, normalize_genre_delimiters(genre) || ';', ''
    FROM library_tracks WHERE is_present = 1
    UNION ALL
    SELECT track_id, substr(rest, instr(rest, ';') + 1),
        trim(substr(rest, 1, instr(rest, ';') - 1))
    FROM genre_parts WHERE rest <> ''
), track_genres AS (
    SELECT DISTINCT track_id, genre FROM genre_parts WHERE genre <> ''
)"""
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


def _recent_change_windows(
    period: str, start_date: str | None, end_date: str | None,
) -> tuple[date, date, date, date]:
    _period_where(period, start_date, end_date)
    if period == "custom":
        recent_start = date.fromisoformat(start_date or "")
        recent_end = date.fromisoformat(end_date or "")
    else:
        recent_end = datetime.now(JAPAN_TIMEZONE).date()
        days = 1 if period == "today" else PERIOD_DAYS[period]
        days = RECENT_CHANGE_ALL_DAYS if days is None else days
        recent_start = recent_end - timedelta(days=days - 1)
    window_days = (recent_end - recent_start).days + 1
    baseline_end = recent_start - timedelta(days=1)
    baseline_start = baseline_end - timedelta(days=window_days - 1)
    return recent_start, recent_end, baseline_start, baseline_end


def _nullable_delta(current: float | None, baseline: float | None) -> float | None:
    return None if current is None or baseline is None else current - baseline


def _behavior_affinity(row: dict[str, Any]) -> float:
    return (float(row["completionRate"]) - float(row["skipRate"])
            - 0.5 * float(row["earlySkipRate"]))


def _profile_level(score: float | None) -> str:
    if score is None:
        return "データ不足"
    if score >= PROFILE_STRONG_THRESHOLD:
        return "強いプラス傾向"
    if score >= PROFILE_POSITIVE_THRESHOLD:
        return "プラス傾向"
    if score > -PROFILE_POSITIVE_THRESHOLD:
        return "ほぼ中立"
    if score > -PROFILE_STRONG_THRESHOLD:
        return "マイナス傾向"
    return "強いマイナス傾向"


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
            analysis_version = self._latest_analysis_version(connection)
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
    def _latest_analysis_version(connection: Any) -> int | None:
        return connection.execute(
            """SELECT MAX(CAST(json_extract(raw_json, '$.analysisVersion') AS INTEGER))
               FROM source_records WHERE data_kind='track_features'
               AND json_type(raw_json, '$.analysisVersion')='integer'"""
        ).fetchone()[0]

    def recent_changes(
        self, period: str, start_date: str | None = None, end_date: str | None = None,
        quality: str = "analyzable",
    ) -> dict[str, Any]:
        if quality not in {"analyzable", "all"}:
            raise ValueError("quality must be analyzable or all")
        recent_start, recent_end, baseline_start, baseline_end = _recent_change_windows(
            period, start_date, end_date
        )
        event_date = f"date(played_at, '{SQLITE_JAPAN_TIMEZONE}')"
        recent_window = f"{event_date} BETWEEN '{recent_start}' AND '{recent_end}'"
        baseline_window = f"{event_date} BETWEEN '{baseline_start}' AND '{baseline_end}'"
        quality_count = DETAIL_EVENT_PREDICATE if quality == "analyzable" else "1=1"
        recent_count = f"({recent_window}) AND ({quality_count})"
        baseline_count = f"({baseline_window}) AND ({quality_count})"
        recent_detail = f"({recent_window}) AND ({DETAIL_EVENT_PREDICATE})"
        baseline_detail = f"({baseline_window}) AND ({DETAIL_EVENT_PREDICATE})"
        historical_detail = (
            f"{event_date} < '{recent_start}' AND ({DETAIL_EVENT_PREDICATE})"
        )
        with self.database.connect() as connection:
            rows = [dict(row) for row in connection.execute(
                f"""SELECT track_id trackId, MAX(track_title) title, MAX(artist) artist,
                    SUM(CASE WHEN {recent_count} THEN 1 ELSE 0 END) recentPlayCount,
                    SUM(CASE WHEN {baseline_count} THEN 1 ELSE 0 END) baselinePlayCount,
                    COUNT(CASE WHEN {recent_detail} THEN 1 END) recentDetailCount,
                    COUNT(CASE WHEN {baseline_detail} THEN 1 END) baselineDetailCount,
                    AVG(CASE WHEN {recent_detail} THEN skipped END) * 100 recentSkipRate,
                    AVG(CASE WHEN {baseline_detail} THEN skipped END) * 100 baselineSkipRate,
                    AVG(CASE WHEN {recent_detail}
                        THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                        * 100 recentEarlySkipRate,
                    AVG(CASE WHEN {baseline_detail}
                        THEN CASE WHEN {EARLY_SKIP_PREDICATE} THEN 1.0 ELSE 0.0 END END)
                        * 100 baselineEarlySkipRate,
                    COUNT(CASE WHEN {historical_detail} THEN 1 END) historicalDetailCount,
                    AVG(CASE WHEN {historical_detail} THEN completed END) * 100 historicalCompletionRate,
                    MAX(CASE WHEN {historical_detail} THEN played_at END) historicalLastPlayedAt
                    FROM playback_events GROUP BY track_id"""
            )]
            analysis_version = self._latest_analysis_version(connection)
            new_tastes = self._new_tastes(
                connection, analysis_version, recent_detail, baseline_detail
            )

        hooked = []
        bored = []
        rediscovery = []
        for row in rows:
            recent_plays = row["recentPlayCount"]
            baseline_plays = row["baselinePlayCount"]
            if (recent_plays >= RECENT_TRACK_MIN_PLAYS
                    and row["recentDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                    and recent_plays >= baseline_plays + HOOKED_PLAY_GROWTH_MINIMUM
                    and (baseline_plays == 0
                         or recent_plays >= baseline_plays * HOOKED_PLAY_GROWTH_RATIO)
                    and row["recentSkipRate"] <= HOOKED_MAX_SKIP_RATE):
                hooked.append(row)
            skip_delta = _nullable_delta(row["recentSkipRate"], row["baselineSkipRate"])
            early_delta = _nullable_delta(
                row["recentEarlySkipRate"], row["baselineEarlySkipRate"]
            )
            if (recent_plays >= RECENT_TRACK_MIN_PLAYS
                    and row["recentDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                    and row["baselineDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                    and ((skip_delta is not None and skip_delta >= BORED_RATE_WORSENING_POINTS)
                         or (early_delta is not None
                             and early_delta >= BORED_RATE_WORSENING_POINTS))):
                row["skipRateDelta"] = skip_delta
                row["earlySkipRateDelta"] = early_delta
                bored.append(row)
            if (recent_plays == 0
                    and row["historicalDetailCount"] >= REDISCOVERY_MIN_DETAIL_PLAYS
                    and row["historicalCompletionRate"] >= REDISCOVERY_MIN_COMPLETION_RATE):
                rediscovery.append(row)
        hooked.sort(key=lambda row: (-row["recentPlayCount"], row["title"].casefold()))
        bored.sort(key=lambda row: (-max(row.get("skipRateDelta") or 0,
                                         row.get("earlySkipRateDelta") or 0),
                                    row["title"].casefold()))
        rediscovery.sort(key=lambda row: (-row["historicalCompletionRate"],
                                          -row["historicalDetailCount"],
                                          row["title"].casefold()))
        return {"period": period, "quality": quality,
                "recentWindow": {"startDate": str(recent_start), "endDate": str(recent_end)},
                "baselineWindow": {"startDate": str(baseline_start), "endDate": str(baseline_end)},
                "analysisVersion": analysis_version, "hookedTracks": hooked[:20],
                "boredTracks": bored[:20], "newTastes": new_tastes[:20],
                "rediscoveryTracks": rediscovery[:20], "thresholds": {
                    "recentTrackMinPlays": RECENT_TRACK_MIN_PLAYS,
                    "recentTrackMinDetails": RECENT_TRACK_MIN_DETAILS,
                    "hookedPlayGrowthRatio": HOOKED_PLAY_GROWTH_RATIO,
                    "hookedPlayGrowthMinimum": HOOKED_PLAY_GROWTH_MINIMUM,
                    "hookedMaxSkipRate": HOOKED_MAX_SKIP_RATE,
                    "boredRateWorseningPoints": BORED_RATE_WORSENING_POINTS,
                    "newTasteMinDetails": NEW_TASTE_MIN_DETAILS,
                    "newTasteRateImprovementPoints": NEW_TASTE_RATE_IMPROVEMENT_POINTS,
                    "newTasteScoreMinimum": NEW_TASTE_SCORE_MINIMUM,
                    "rediscoveryMinDetailPlays": REDISCOVERY_MIN_DETAIL_PLAYS,
                    "rediscoveryMinCompletionRate": REDISCOVERY_MIN_COMPLETION_RATE,
                }, "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    @staticmethod
    def _new_tastes(
        connection: Any, analysis_version: int | None,
        recent_detail: str, baseline_detail: str,
    ) -> list[dict[str, Any]]:
        if analysis_version is None:
            return []
        placeholders = ",".join("?" for _ in INSIGHT_FEATURES)
        rows = connection.execute(
            f"""WITH feature_values AS (
                SELECT sr.track_id, feature.key feature, CAST(feature.value AS REAL) score
                FROM source_records sr, json_each(sr.raw_json, '$.features') feature
                WHERE sr.data_kind='track_features' AND sr.track_id IS NOT NULL
                    AND json_type(sr.raw_json, '$.analysisVersion')='integer'
                    AND CAST(json_extract(sr.raw_json, '$.analysisVersion') AS INTEGER)=?
                    AND feature.key IN ({placeholders})
                    AND feature.type IN ('integer', 'real')
                    AND CAST(feature.value AS REAL) BETWEEN ? AND 1.0
            )
            SELECT fv.feature, COUNT(CASE WHEN {recent_detail} THEN 1 END) recentDetailCount,
                COUNT(CASE WHEN {baseline_detail} THEN 1 END) baselineDetailCount,
                AVG(CASE WHEN {recent_detail} THEN e.completed END) * 100 recentCompletionRate,
                AVG(CASE WHEN {baseline_detail} THEN e.completed END) * 100 baselineCompletionRate,
                AVG(CASE WHEN {recent_detail} THEN e.skipped END) * 100 recentSkipRate,
                AVG(CASE WHEN {baseline_detail} THEN e.skipped END) * 100 baselineSkipRate
            FROM feature_values fv JOIN playback_events e ON e.track_id=fv.track_id
            GROUP BY fv.feature""",
            (analysis_version, *INSIGHT_FEATURES.keys(), NEW_TASTE_SCORE_MINIMUM),
        ).fetchall()
        result = []
        for raw in rows:
            row = dict(raw)
            completion_delta = _nullable_delta(
                row["recentCompletionRate"], row["baselineCompletionRate"]
            )
            skip_improvement = _nullable_delta(
                row["baselineSkipRate"], row["recentSkipRate"]
            )
            if (row["recentDetailCount"] >= NEW_TASTE_MIN_DETAILS
                    and row["baselineDetailCount"] >= NEW_TASTE_MIN_DETAILS
                    and ((completion_delta is not None
                          and completion_delta >= NEW_TASTE_RATE_IMPROVEMENT_POINTS)
                         or (skip_improvement is not None
                             and skip_improvement >= NEW_TASTE_RATE_IMPROVEMENT_POINTS))):
                row["featureLabel"] = INSIGHT_FEATURES[row["feature"]]
                row["completionRateDelta"] = completion_delta
                row["skipRateImprovement"] = skip_improvement
                result.append(row)
        result.sort(key=lambda row: (-max(row["completionRateDelta"] or 0,
                                          row["skipRateImprovement"] or 0),
                                     row["featureLabel"]))
        return result

    def advanced_insights(
        self, period: str, start_date: str | None = None, end_date: str | None = None,
        quality: str = "analyzable",
    ) -> dict[str, Any]:
        event_where, event_params = _insights_event_where(
            period, start_date, end_date, quality
        )
        event_condition = (
            event_where.removeprefix("WHERE ").replace("played_at", "e.played_at") or "1=1"
        )
        recent_start, recent_end, baseline_start, baseline_end = _recent_change_windows(
            period, start_date, end_date
        )
        with self.database.connect() as connection:
            analysis_version = self._latest_analysis_version(connection)
            time_features, profile = self._feature_behavior_profiles(
                connection, analysis_version, event_condition, event_params
            )
            entity_changes = {
                dimension: self._entity_changes(
                    connection, dimension, recent_start, recent_end,
                    baseline_start, baseline_end, quality
                ) for dimension in ("artists", "albums", "genres")
            }
        return {"period": period, "quality": quality,
                "recentWindow": {"startDate": str(recent_start), "endDate": str(recent_end)},
                "baselineWindow": {"startDate": str(baseline_start), "endDate": str(baseline_end)},
                "analysisVersion": analysis_version, "timeFeatureAffinity": time_features,
                "entityChanges": entity_changes, "listeningProfile": profile,
                "thresholds": {"entityGrowthRatio": ENTITY_GROWTH_RATIO,
                    "entityGrowthMinimum": ENTITY_GROWTH_MINIMUM,
                    "entityGoodCompletionRate": ENTITY_GOOD_COMPLETION_RATE,
                    "timeFeatureMinDetails": TIME_FEATURE_MIN_DETAILS,
                    "listeningProfileMinDetails": LISTENING_PROFILE_MIN_DETAILS,
                    "profileStrongThreshold": PROFILE_STRONG_THRESHOLD,
                    "profilePositiveThreshold": PROFILE_POSITIVE_THRESHOLD},
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    def recommendations(
        self, period: str, start_date: str | None = None, end_date: str | None = None,
        quality: str = "analyzable",
    ) -> dict[str, Any]:
        changes = self.recent_changes(period, start_date, end_date, quality)
        advanced = self.advanced_insights(period, start_date, end_date, quality)
        positive_features = [row["feature"] for row in advanced["listeningProfile"]
                             if row["score"] is not None
                             and row["score"] >= PROFILE_POSITIVE_THRESHOLD]
        recent_start = changes["recentWindow"]["startDate"]
        recent_end = changes["recentWindow"]["endDate"]
        detail = DETAIL_EVENT_PREDICATE
        recent_window = (
            f"date(played_at, '{SQLITE_JAPAN_TIMEZONE}') BETWEEN "
            f"'{recent_start}' AND '{recent_end}'"
        )
        quality_count = detail if quality == "analyzable" else "1=1"
        feature_columns = ",\n".join(
            f"CASE WHEN json_type(sr.raw_json, '$.features.{feature}') IN ('integer','real') "
            f"AND json_extract(sr.raw_json, '$.features.{feature}') BETWEEN 0.0 AND 1.0 "
            f"THEN CAST(json_extract(sr.raw_json, '$.features.{feature}') AS REAL) END {feature}"
            for feature in INSIGHT_FEATURES
        )
        with self.database.connect() as connection:
            version = self._latest_analysis_version(connection)
            rows = [dict(row) for row in connection.execute(
                f"""WITH stats AS (
                    SELECT track_id, COUNT(*) playCount,
                        SUM(CASE WHEN ({recent_window}) AND ({quality_count}) THEN 1 ELSE 0 END) recentPlayCount,
                        COUNT(CASE WHEN {detail} THEN 1 END) detailEventCount,
                        AVG(CASE WHEN {detail} THEN completed END) * 100 completionRate,
                        AVG(CASE WHEN {detail} THEN skipped END) * 100 skipRate,
                        AVG(CASE WHEN {detail} THEN CASE WHEN {EARLY_SKIP_PREDICATE}
                            THEN 1.0 ELSE 0.0 END END) * 100 earlySkipRate
                    FROM playback_events GROUP BY track_id
                ), feature_tracks AS (
                    SELECT sr.track_id, {feature_columns}
                    FROM source_records sr WHERE sr.data_kind='track_features'
                        AND json_type(sr.raw_json, '$.analysisVersion')='integer'
                        AND CAST(json_extract(sr.raw_json, '$.analysisVersion') AS INTEGER)=?
                )
                SELECT lt.track_id trackId, lt.title, lt.artist, lt.album, lt.genre,
                    COALESCE(pp.favorite, lt.favorite, 0) favorite,
                    COALESCE(pp.playback_preference, 0) playbackPreference,
                    COALESCE(s.playCount, 0) playCount,
                    COALESCE(s.recentPlayCount, 0) recentPlayCount,
                    COALESCE(s.detailEventCount, 0) detailEventCount,
                    s.completionRate, s.skipRate, s.earlySkipRate,
                    {', '.join(f'ft.{feature}' for feature in INSIGHT_FEATURES)}
                FROM library_tracks lt
                JOIN feature_tracks ft ON ft.track_id=lt.track_id
                LEFT JOIN stats s ON s.track_id=lt.track_id
                LEFT JOIN playback_preferences pp ON pp.track_id=lt.track_id
                WHERE lt.is_present=1""", (version,)
            )] if version is not None else []
        recommendations = []
        discoveries = []
        for row in rows:
            values = [row[feature] for feature in positive_features
                      if row.get(feature) is not None]
            if not values:
                continue
            feature_match = sum(values) / len(values)
            if feature_match < RECOMMENDATION_FEATURE_MATCH_MINIMUM:
                continue
            score = feature_match * 40
            reasons = [f"現在の好みの特徴と{feature_match * 100:.0f}%一致"]
            if row["favorite"]:
                score += 15
                reasons.append("お気に入り")
            score += max(-15, min(15, row["playbackPreference"] * 1.5))
            if row["playbackPreference"] > 0:
                reasons.append(f"Good +{row['playbackPreference']}")
            if row["detailEventCount"] >= RECENT_TRACK_MIN_DETAILS:
                score += (row["completionRate"] - 50) * 0.2
                score -= row["skipRate"] * 0.1 + row["earlySkipRate"] * 0.05
                if row["completionRate"] >= REDISCOVERY_MIN_COMPLETION_RATE:
                    reasons.append(f"完走率{row['completionRate']:.0f}%")
            overplay_penalty = min(row["recentPlayCount"] * 4, 24)
            score -= overplay_penalty
            if overplay_penalty:
                reasons.append(f"最近{row['recentPlayCount']}回分を減点")
            item = {key: row[key] for key in ("trackId", "title", "artist", "playCount",
                                               "recentPlayCount", "detailEventCount",
                                               "completionRate", "skipRate", "earlySkipRate")}
            item.update({"score": round(score, 2), "featureMatch": feature_match,
                         "reasons": reasons})
            recommendations.append(item)
            if row["playCount"] <= DISCOVERY_MAX_PLAYS:
                discovery = dict(item)
                discovery["reasons"] = [f"最近の好みの特徴と{feature_match * 100:.0f}%一致",
                                        ("未再生" if row["playCount"] == 0
                                         else f"まだ{row['playCount']}回再生")]
                if row["playCount"] == 0:
                    discovery["completionRate"] = None
                    discovery["skipRate"] = None
                    discovery["earlySkipRate"] = None
                discoveries.append(discovery)
        recommendations.sort(key=lambda item: (-item["score"], item["title"].casefold()))
        discoveries.sort(key=lambda item: (-item["featureMatch"], item["playCount"],
                                            item["title"].casefold()))
        rediscovery = []
        for row in changes["rediscoveryTracks"]:
            item = dict(row)
            item["reason"] = (f"以前{row['historicalDetailCount']}回再生・完走率"
                              f"{row['historicalCompletionRate']:.0f}%、最近の期間は再生なし")
            rediscovery.append(item)
        cards = self._automatic_insight_cards(changes, advanced)
        return {"period": period, "quality": quality, "analysisVersion": version,
                "recommendations": recommendations[:20],
                "rediscoveryRecommendations": rediscovery[:20],
                "lowPlayDiscoveries": discoveries[:20], "insightCards": cards[:5],
                "thresholds": {"featureMatchMinimum": RECOMMENDATION_FEATURE_MATCH_MINIMUM,
                    "discoveryMaxPlays": DISCOVERY_MAX_PLAYS,
                    "overplayPenaltyPerRecentPlay": 4,
                    "overplayPenaltyMaximum": 24}}

    @staticmethod
    def _automatic_insight_cards(
        changes: dict[str, Any], advanced: dict[str, Any],
    ) -> list[dict[str, Any]]:
        cards = []
        for row in changes["newTastes"]:
            delta = max(row["completionRateDelta"] or 0, row["skipRateImprovement"] or 0)
            cards.append({"kind": "newTaste", "title": f"{row['featureLabel']}との相性が上昇",
                          "message": f"最近の行動指標が{delta:.0f}ポイント改善しました。",
                          "priority": delta * row["recentDetailCount"]})
        for dimension, rows in advanced["entityChanges"].items():
            for row in rows:
                if "最近急増" in row["signals"]:
                    cards.append({"kind": dimension, "title": f"{row['label']}の再生が急増",
                                  "message": f"過去{row['baselinePlayCount']}回から最近{row['recentPlayCount']}回へ増えました。",
                                  "priority": row["playCountDelta"] * row["recentPlayCount"]})
        for row in changes["boredTracks"]:
            delta = max(row.get("skipRateDelta") or 0, row.get("earlySkipRateDelta") or 0)
            cards.append({"kind": "bored", "trackId": row["trackId"],
                          "title": f"{row['title']}のSkip傾向が上昇",
                          "message": f"過去より{delta:.0f}ポイント悪化しています。",
                          "priority": delta * row["recentDetailCount"]})
        for row in changes["rediscoveryTracks"]:
            cards.append({"kind": "rediscovery", "trackId": row["trackId"],
                          "title": f"{row['title']}を再発見",
                          "message": f"以前{row['historicalDetailCount']}回、完走率{row['historicalCompletionRate']:.0f}%でした。",
                          "priority": row["historicalDetailCount"]
                                      * row["historicalCompletionRate"] / 100})
        cards.sort(key=lambda item: (-item["priority"], item["title"].casefold()))
        return cards

    @staticmethod
    def _feature_behavior_profiles(
        connection: Any, analysis_version: int | None,
        event_condition: str, event_params: list[Any],
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        if analysis_version is None:
            return [], [{"feature": key, "featureLabel": label, "detailEventCount": 0,
                         "completionRate": None, "skipRate": None,
                         "earlySkipRate": None, "score": None, "level": "データ不足"}
                        for key, label in INSIGHT_FEATURES.items()]
        placeholders = ",".join("?" for _ in INSIGHT_FEATURES)
        detail_e = DETAIL_EVENT_PREDICATE.replace("played_at", "e.played_at")
        early_e = (EARLY_SKIP_PREDICATE.replace("played_at", "e.played_at")
                   .replace("skipped", "e.skipped").replace("play_duration", "e.play_duration"))
        base_cte = f"""WITH feature_values AS (
            SELECT sr.track_id, feature.key feature, CAST(feature.value AS REAL) score
            FROM source_records sr, json_each(sr.raw_json, '$.features') feature
            WHERE sr.data_kind='track_features' AND sr.track_id IS NOT NULL
                AND json_type(sr.raw_json, '$.analysisVersion')='integer'
                AND CAST(json_extract(sr.raw_json, '$.analysisVersion') AS INTEGER)=?
                AND feature.key IN ({placeholders})
                AND feature.type IN ('integer', 'real')
                AND CAST(feature.value AS REAL) BETWEEN ? AND 1.0
        ), filtered_events AS (
            SELECT e.*, CASE
                WHEN CAST(strftime('%H', e.played_at, '{SQLITE_JAPAN_TIMEZONE}') AS INTEGER) BETWEEN 5 AND 11 THEN '朝'
                WHEN CAST(strftime('%H', e.played_at, '{SQLITE_JAPAN_TIMEZONE}') AS INTEGER) BETWEEN 12 AND 16 THEN '昼'
                WHEN CAST(strftime('%H', e.played_at, '{SQLITE_JAPAN_TIMEZONE}') AS INTEGER) BETWEEN 17 AND 21 THEN '夜'
                ELSE '深夜' END timeBand
            FROM playback_events e WHERE {event_condition}
        )"""
        base_params = (analysis_version, *INSIGHT_FEATURES.keys(),
                       NEW_TASTE_SCORE_MINIMUM, *event_params)
        time_rows = connection.execute(
            base_cte + f""" SELECT e.timeBand, fv.feature,
                COUNT(*) playCount, COUNT(CASE WHEN {detail_e} THEN 1 END) detailEventCount,
                AVG(CASE WHEN {detail_e} THEN e.completed END) * 100 completionRate,
                AVG(CASE WHEN {detail_e} THEN e.skipped END) * 100 skipRate,
                AVG(CASE WHEN {detail_e} THEN CASE WHEN {early_e}
                    THEN 1.0 ELSE 0.0 END END) * 100 earlySkipRate
            FROM feature_values fv JOIN filtered_events e ON e.track_id=fv.track_id
            GROUP BY e.timeBand, fv.feature""", base_params
        ).fetchall()
        time_features = []
        for raw in time_rows:
            row = dict(raw)
            row["featureLabel"] = INSIGHT_FEATURES[row["feature"]]
            row["affinityScore"] = _behavior_affinity(row) if (
                row["detailEventCount"] >= TIME_FEATURE_MIN_DETAILS) else None
            row["isReliable"] = row["affinityScore"] is not None
            time_features.append(row)
        time_order = {"朝": 0, "昼": 1, "夜": 2, "深夜": 3}
        time_features.sort(key=lambda row: (time_order[row["timeBand"]],
                                            -(row["affinityScore"] or -999),
                                            row["featureLabel"]))

        profile_rows = connection.execute(
            base_cte + f""" SELECT fv.feature, COUNT(*) playCount,
                COUNT(CASE WHEN {detail_e} THEN 1 END) detailEventCount,
                AVG(CASE WHEN {detail_e} THEN e.completed END) * 100 completionRate,
                AVG(CASE WHEN {detail_e} THEN e.skipped END) * 100 skipRate,
                AVG(CASE WHEN {detail_e} THEN CASE WHEN {early_e}
                    THEN 1.0 ELSE 0.0 END END) * 100 earlySkipRate
            FROM feature_values fv JOIN filtered_events e ON e.track_id=fv.track_id
            GROUP BY fv.feature""", base_params
        ).fetchall()
        by_feature = {row["feature"]: dict(row) for row in profile_rows}
        profile = []
        for feature, label in INSIGHT_FEATURES.items():
            row = by_feature.get(feature, {"feature": feature, "playCount": 0,
                                           "detailEventCount": 0, "completionRate": None,
                                           "skipRate": None, "earlySkipRate": None})
            score = (_behavior_affinity(row) if
                     row["detailEventCount"] >= LISTENING_PROFILE_MIN_DETAILS else None)
            row.update({"featureLabel": label, "score": score,
                        "level": _profile_level(score)})
            profile.append(row)
        return time_features, profile

    @staticmethod
    def _entity_changes(
        connection: Any, dimension: str, recent_start: date, recent_end: date,
        baseline_start: date, baseline_end: date, quality: str,
    ) -> list[dict[str, Any]]:
        expressions = {
            "artists": "e.artist",
            "albums": "COALESCE(NULLIF(e.album, ''), 'アルバム不明')",
            "genres": "COALESCE(tg.genre, '未分類')",
        }
        label = expressions[dimension]
        genre_cte = f"WITH RECURSIVE {GENRE_PARTS_CTE}" if dimension == "genres" else ""
        genre_join = ("LEFT JOIN track_genres tg ON tg.track_id=lt.track_id"
                      if dimension == "genres" else "")
        event_date = f"date(e.played_at, '{SQLITE_JAPAN_TIMEZONE}')"
        detail = DETAIL_EVENT_PREDICATE.replace("played_at", "e.played_at")
        recent = f"{event_date} BETWEEN '{recent_start}' AND '{recent_end}'"
        baseline = f"{event_date} BETWEEN '{baseline_start}' AND '{baseline_end}'"
        quality_count = detail if quality == "analyzable" else "1=1"
        rows = connection.execute(
            f"""{genre_cte} SELECT {label} label,
                SUM(CASE WHEN ({recent}) AND ({quality_count}) THEN 1 ELSE 0 END) recentPlayCount,
                SUM(CASE WHEN ({baseline}) AND ({quality_count}) THEN 1 ELSE 0 END) baselinePlayCount,
                COUNT(CASE WHEN ({recent}) AND ({detail}) THEN 1 END) recentDetailCount,
                COUNT(CASE WHEN ({baseline}) AND ({detail}) THEN 1 END) baselineDetailCount,
                AVG(CASE WHEN ({recent}) AND ({detail}) THEN e.completed END) * 100 recentCompletionRate,
                AVG(CASE WHEN ({baseline}) AND ({detail}) THEN e.completed END) * 100 baselineCompletionRate,
                AVG(CASE WHEN ({recent}) AND ({detail}) THEN e.skipped END) * 100 recentSkipRate,
                AVG(CASE WHEN ({baseline}) AND ({detail}) THEN e.skipped END) * 100 baselineSkipRate
            FROM playback_events e
            LEFT JOIN library_tracks lt ON lt.track_id=e.track_id AND lt.is_present=1
            {genre_join}
            GROUP BY {label}"""
        ).fetchall()
        result = []
        for raw in rows:
            row = dict(raw)
            row["playCountDelta"] = row["recentPlayCount"] - row["baselinePlayCount"]
            row["completionRateDelta"] = _nullable_delta(
                row["recentCompletionRate"], row["baselineCompletionRate"])
            row["skipRateDelta"] = _nullable_delta(
                row["recentSkipRate"], row["baselineSkipRate"])
            growth = (row["recentPlayCount"] >= RECENT_TRACK_MIN_PLAYS
                      and row["playCountDelta"] >= ENTITY_GROWTH_MINIMUM
                      and (row["baselinePlayCount"] == 0 or row["recentPlayCount"]
                           >= row["baselinePlayCount"] * ENTITY_GROWTH_RATIO))
            good = (row["recentDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                    and row["recentCompletionRate"] >= ENTITY_GOOD_COMPLETION_RATE)
            skip_worse = (row["recentDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                          and row["baselineDetailCount"] >= RECENT_TRACK_MIN_DETAILS
                          and row["skipRateDelta"] is not None
                          and row["skipRateDelta"] >= BORED_RATE_WORSENING_POINTS)
            signals = []
            if growth: signals.append("最近急増")
            if good: signals.append("最近よく完走")
            if skip_worse: signals.append("Skip増加")
            if signals:
                row["signals"] = signals
                result.append(row)
        result.sort(key=lambda row: (-len(row["signals"]), -row["playCountDelta"],
                                     row["label"].casefold()))
        return result[:20]

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
        artist: str = "", genre: str = "",
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
        filter_conditions = []
        if artist:
            filter_conditions.append("lt.artist = ? COLLATE NOCASE")
            params.append(artist)
        if genre:
            filter_conditions.append("tg.genre = ? COLLATE NOCASE")
            params.append(genre)
        if filter_conditions:
            conjunction = " AND " if qualified_where else " WHERE "
            qualified_where += conjunction + " AND ".join(filter_conditions)
        subtitle_select = f"MAX({subtitle})" if subtitle else "NULL"
        having = "HAVING value > 0" if metric == "duration" else ""
        uses_genres = dimension == "genres" or bool(genre)
        genre_cte = f"WITH RECURSIVE {GENRE_PARTS_CTE}" if uses_genres else ""
        genre_join = "LEFT JOIN track_genres tg ON tg.track_id=lt.track_id" if uses_genres else ""
        with self.database.connect() as connection:
            if dimension == "genres":
                rows = connection.execute(
                    f"""{genre_cte}
                    SELECT COALESCE(tg.genre, '未分類') itemKey,
                        COALESCE(tg.genre, '未分類') label, NULL subtitle, {value} value
                    FROM playback_events e
                    LEFT JOIN library_tracks lt ON lt.track_id=e.track_id AND lt.is_present=1
                    {genre_join}
                    {qualified_where}
                    GROUP BY COALESCE(tg.genre, '未分類')
                    {having}
                    ORDER BY value DESC, label COLLATE NOCASE
                    LIMIT 50""", params
                ).fetchall()
                return {"period": period, "dimension": dimension, "metric": metric,
                        "items": [dict(row) for row in rows],
                        "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}
            rows = connection.execute(
                f"""{genre_cte} SELECT {key} itemKey, MAX({label}) label, {subtitle_select} subtitle,
                    {value} value
                    FROM playback_events e
                    LEFT JOIN library_tracks lt ON lt.track_id=e.track_id AND lt.is_present=1
                    {genre_join}
                    {qualified_where}
                    GROUP BY {key}
                    {having}
                    ORDER BY value DESC, label COLLATE NOCASE
                    LIMIT 50""", params
            ).fetchall()
        return {"period": period, "dimension": dimension, "metric": metric,
                "items": [dict(row) for row in rows],
                "legacyPlaybackCutoff": LEGACY_PLAYBACK_CUTOFF}

    def ranking_filters(self) -> dict[str, list[str]]:
        with self.database.connect() as connection:
            artists = [row[0] for row in connection.execute(
                """SELECT DISTINCT artist FROM library_tracks
                   WHERE is_present=1 AND trim(artist)<>'' ORDER BY artist COLLATE NOCASE"""
            ).fetchall()]
            genres = [row[0] for row in connection.execute(
                f"""WITH RECURSIVE {GENRE_PARTS_CTE}
                    SELECT DISTINCT genre FROM track_genres ORDER BY genre COLLATE NOCASE"""
            ).fetchall()]
        return {"artists": artists, "genres": genres}

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
        order: str = "desc", page: int = 1, page_size: int = 30,
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

    def clear_imported_data(self) -> dict[str, int]:
        tables = (
            "playback_events", "playback_preferences", "source_records", "library_tracks",
            "import_runs",
        )
        with self.database.connect() as connection:
            counts = {
                table: connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                for table in tables
            }
            for table in tables[:-1]:
                connection.execute(f"DELETE FROM {table}")
            connection.execute("DELETE FROM import_runs")
            connection.execute("DELETE FROM sqlite_sequence WHERE name='import_runs'")
        return {
            "playbackEvents": counts["playback_events"],
            "playbackPreferences": counts["playback_preferences"],
            "sourceRecords": counts["source_records"],
            "libraryTracks": counts["library_tracks"],
            "importRuns": counts["import_runs"],
        }

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
        self, data_kind: str, page: int = 1, page_size: int = 30,
        sort: str = "title", order: str = "asc", search: str = "",
    ) -> dict[str, Any]:
        allowed = {"library_genres", "track_features", "volume_normalization", "playlists", "equalizer", "genre_presets"}
        if data_kind not in allowed:
            raise ValueError("unsupported source kind")
        escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{escaped}%"
        if data_kind == "library_genres":
            sort_columns = {"title": "title COLLATE NOCASE", "trackCount": "trackCount",
                            "artistCount": "artistCount", "importedAt": "importedAt"}
            if sort not in sort_columns:
                raise ValueError("unsupported source sort")
            if order not in {"asc", "desc"}:
                raise ValueError("order must be asc or desc")
            offset = (page - 1) * page_size
            with self.database.connect() as connection:
                base = f"""WITH RECURSIVE {GENRE_PARTS_CTE}, genre_catalog AS (
                    SELECT COALESCE(tg.genre, 'ジャンル未設定') title,
                        COUNT(DISTINCT lt.track_id) trackCount,
                        COUNT(DISTINCT lt.artist) artistCount,
                        MAX(lt.imported_at) importedAt
                    FROM library_tracks lt
                    LEFT JOIN track_genres tg ON tg.track_id=lt.track_id
                    WHERE lt.is_present=1
                    GROUP BY COALESCE(tg.genre, 'ジャンル未設定')
                )"""
                count = connection.execute(base + " SELECT COUNT(*) FROM genre_catalog WHERE title LIKE ? ESCAPE '\\'", (pattern,)).fetchone()[0]
                rows = connection.execute(
                    base + f""" SELECT title, trackCount, artistCount, importedAt
                    FROM genre_catalog WHERE title LIKE ? ESCAPE '\\' ORDER BY {sort_columns[sort]} {order.upper()}, title COLLATE NOCASE
                    LIMIT ? OFFSET ?""", (pattern, page_size, offset)
                ).fetchall()
            return {"count": count, "items": [dict(row) for row in rows],
                    "page": page, "pageSize": page_size, "derivedFrom": "library"}
        feature_keys: list[str] = []
        if data_kind == "track_features":
            with self.database.connect() as connection:
                discovered_keys = {
                    row[0] for row in connection.execute(
                        """SELECT DISTINCT feature.key
                           FROM source_records sr, json_each(sr.raw_json, '$.features') feature
                           WHERE sr.data_kind='track_features'"""
                    )
                    if isinstance(row[0], str)
                }
            feature_keys = [key for key in TRACK_FEATURE_KEY_ORDER if key in discovered_keys]
            feature_keys.extend(sorted(discovered_keys - set(TRACK_FEATURE_KEY_ORDER), key=str.casefold))
        sort_columns = SOURCE_COMMON_SORT_COLUMNS | SOURCE_KIND_SORT_COLUMNS[data_kind]
        dynamic_feature_sort = data_kind == "track_features" and sort in feature_keys
        if dynamic_feature_sort:
            sort_columns = sort_columns | {sort: "dynamic_track_feature"}
        if sort not in sort_columns:
            raise ValueError("unsupported source sort")
        if order not in {"asc", "desc"}:
            raise ValueError("order must be asc or desc")
        sort_column = sort_columns[sort]
        if dynamic_feature_sort:
            sort_column = "CAST(json_extract(sr.raw_json, '$.features.' || json_quote(?)) AS REAL)"
        with self.database.connect() as connection:
            search_where = "sr.data_kind=? AND (sr.title LIKE ? ESCAPE '\\' OR sr.subtitle LIKE ? ESCAPE '\\')"
            filter_parameters = [data_kind, pattern, pattern]
            query_parameters: list[Any] = list(filter_parameters)
            if dynamic_feature_sort:
                query_parameters.append(sort)
            query_parameters.extend((page_size, (page - 1) * page_size))
            rows = connection.execute(
                f"""SELECT sr.item_key, sr.track_id, sr.title, sr.subtitle, sr.imported_at,
                    sr.raw_json, CASE WHEN lt.track_id IS NULL THEN 0 ELSE 1 END linked
                    FROM source_records sr
                    LEFT JOIN library_tracks lt ON lt.track_id=sr.track_id AND lt.is_present=1
                    WHERE {search_where} ORDER BY {sort_column} {order.upper()}, sr.item_key
                    LIMIT ? OFFSET ?""", query_parameters
            ).fetchall()
            total = connection.execute(
                f"SELECT COUNT(*) FROM source_records sr WHERE {search_where}", filter_parameters
            ).fetchone()[0]
            linked_total = connection.execute(
                f"""SELECT COUNT(*) FROM source_records sr JOIN library_tracks lt
                   ON lt.track_id=sr.track_id AND lt.is_present=1 WHERE {search_where}""",
                filter_parameters,
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
        result = {"dataKind": data_kind, "count": total, "pageCount": len(items),
                  "linkedCount": linked_total, "items": items}
        if data_kind == "track_features":
            result["featureKeys"] = feature_keys
        return result
