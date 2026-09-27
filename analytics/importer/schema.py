from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any
from unicodedata import combining, normalize
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class PlaybackEventV1(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    event_id: str = Field(alias="eventId", min_length=1, max_length=128)
    track_id: str = Field(alias="trackId", min_length=1, max_length=256)
    track_title: str = Field(alias="trackTitle", min_length=1, max_length=1000)
    artist: str = Field(min_length=1, max_length=1000)
    album: str | None = Field(default=None, max_length=1000)
    played_at: datetime = Field(alias="playedAt")
    play_duration: float = Field(alias="playDuration", ge=0)
    track_duration: float = Field(alias="trackDuration", ge=0)
    completed: bool
    skipped: bool
    play_source: str = Field(alias="playSource", min_length=1, max_length=100)
    selection_type: str = Field(alias="selectionType", min_length=1, max_length=100)
    session_id: str | None = Field(default=None, alias="sessionId", max_length=128)
    platform: str = Field(min_length=1, max_length=100)
    schema_version: int = Field(alias="schemaVersion")

    @field_validator("played_at")
    @classmethod
    def timezone_is_required(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("playedAt must include a timezone")
        return value

    @model_validator(mode="after")
    def validate_contract(self) -> "PlaybackEventV1":
        if self.schema_version != 1:
            raise ValueError("event schemaVersion must be 1")
        if self.completed and self.skipped:
            raise ValueError("completed and skipped cannot both be true")
        return self


class PlaybackExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schemaVersion: int
    exportedAt: datetime
    events: list[Any]

    @model_validator(mode="after")
    def validate_version(self) -> "PlaybackExportV1":
        if self.schemaVersion != 1:
            raise ValueError("root schemaVersion must be 1")
        if self.exportedAt.tzinfo is None or self.exportedAt.utcoffset() is None:
            raise ValueError("exportedAt must include a timezone")
        return self


class LibraryTrackV1(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    track_id: str = Field(alias="trackID", min_length=1, max_length=256)
    title: str = Field(min_length=1, max_length=1000)
    artist: str = Field(min_length=1, max_length=1000)
    album: str | None = Field(default=None, max_length=1000)
    genre: str | None = Field(default=None, max_length=500)
    year: int | None = Field(default=None, ge=0, le=9999)
    duration: float = Field(ge=0)
    format: str | None = Field(default=None, max_length=100)
    favorite: bool | None = None
    play_count: int | None = Field(default=None, alias="playCount", ge=0)
    last_played_at: datetime | None = Field(default=None, alias="lastPlayedAt")
    audio_fingerprint: str | None = Field(
        default=None, alias="audioFingerprint", min_length=64, max_length=64,
        pattern=r"^[0-9a-f]{64}$"
    )
    relative_path: str | None = Field(default=None, alias="relativePath", min_length=1, max_length=4000)
    file_size: int | None = Field(default=None, alias="fileSize", ge=1)
    first_seen_at: datetime | None = Field(default=None, alias="firstSeenAt")

    @field_validator("last_played_at", "first_seen_at")
    @classmethod
    def optional_datetime_has_timezone(cls, value: datetime | None) -> datetime | None:
        if value is not None and (value.tzinfo is None or value.utcoffset() is None):
            raise ValueError("date must include a timezone")
        return value


class LibraryExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")

    version: int
    tracks: list[Any]

    @model_validator(mode="after")
    def validate_version(self) -> "LibraryExportV1":
        if self.version != 1:
            raise ValueError("library version must be 1")
        return self


class PlaybackPreferenceV1(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    track_id: str = Field(alias="trackId", min_length=1, max_length=256)
    playback_preference: int = Field(alias="playbackPreference", ge=-10, le=10)
    favorite: bool | None = None


class PlaybackPreferencesExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schemaVersion: int
    exportedAt: datetime
    tracks: list[Any]

    @model_validator(mode="after")
    def validate_contract(self) -> "PlaybackPreferencesExportV1":
        if self.schemaVersion not in (1, 2):
            raise ValueError("preferences schemaVersion must be 1 or 2")
        if self.exportedAt.tzinfo is None or self.exportedAt.utcoffset() is None:
            raise ValueError("exportedAt must include a timezone")
        return self


class PlaybackPreferenceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    playbackPreference: int = Field(ge=-10, le=10)
    favorite: bool


class SourceIdentityV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    relativePath: str = Field(min_length=1, max_length=4000)
    fileSize: int = Field(ge=0)
    duration: float = Field(ge=0)
    modificationDate: datetime | None = None
    contentHash: str | None = Field(default=None, max_length=256)
    title: str | None = Field(default=None, max_length=1000)
    artist: str | None = Field(default=None, max_length=1000)
    album: str | None = Field(default=None, max_length=1000)


class TrackFeatureItemV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    trackID: str = Field(min_length=1, max_length=256)
    title: str | None = Field(default=None, max_length=1000)
    artist: str | None = Field(default=None, max_length=1000)
    sourceIdentity: SourceIdentityV1
    analysisVersion: int = Field(ge=1)
    analyzedAt: datetime
    importedAt: datetime
    features: dict[str, Any]


class TrackFeaturesExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int
    exportedAt: datetime
    tracks: list[TrackFeatureItemV1]

    @model_validator(mode="after")
    def validate_version(self):
        if self.version != 1: raise ValueError("track features version must be 1")
        return self


class VolumeItemV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    trackID: str = Field(min_length=1, max_length=256)
    title: str | None = Field(default=None, max_length=1000)
    artist: str | None = Field(default=None, max_length=1000)
    relativePath: str = Field(min_length=1, max_length=4000)
    integratedLUFS: float
    truePeakDBTP: float
    normalizationGainDB: float


class VolumeExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int
    exportedAt: datetime
    isEnabled: bool
    tracks: list[VolumeItemV1]

    @model_validator(mode="after")
    def validate_version(self):
        if self.version != 1: raise ValueError("volume normalization version must be 1")
        return self


class PlaylistTrackV1(LibraryTrackV1):
    pass


class PlaylistItemV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int
    name: str = Field(min_length=1, max_length=1000)
    playlistID: str = Field(min_length=1, max_length=256)
    createdAt: datetime
    updatedAt: datetime
    kind: str = Field(min_length=1, max_length=100)
    tags: list[str]
    tracks: list[PlaylistTrackV1]


class PlaylistsExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int
    playlists: list[PlaylistItemV1]

    @model_validator(mode="after")
    def validate_version(self):
        if self.version != 1 or any(x.version != 1 for x in self.playlists):
            raise ValueError("playlists version must be 1")
        return self


class EqualizerExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid")
    kind: str
    version: int
    equalizer: dict[str, Any]
    customPresets: list[dict[str, Any]]

    @model_validator(mode="after")
    def validate_contract(self):
        if self.kind != "mymusic.equalizer" or self.version != 1:
            raise ValueError("unsupported equalizer document")
        return self


class GenrePresetsExportV1(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    kind: str
    version: int
    presets: list["GenreDisplayPresetV1"]

    @model_validator(mode="after")
    def validate_contract(self):
        if self.kind != "mymusic.genre-display-presets" or self.version != 1:
            raise ValueError("unsupported genre presets document")
        ids: set[UUID] = set()
        names: set[str] = set()
        for preset in self.presets:
            if preset.id in ids:
                raise ValueError("preset IDs must be unique")
            normalized_name = normalized_genre_value(preset.name)
            if normalized_name in names:
                raise ValueError("preset names must be unique")
            ids.add(preset.id)
            names.add(normalized_name)
        return self


def normalized_genre_value(value: str) -> str:
    """Match Swift's case/width/diacritic-insensitive comparison contract."""
    width_folded = normalize("NFKC", value)
    return "".join(
        character for character in normalize("NFKD", width_folded.casefold())
        if not combining(character)
    )


class GenreDisplayPresetV1(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    id: UUID = Field(strict=False)
    name: str
    enabledGenreNames: list[str]
    includesUnassignedGenreSetting: bool | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name must not be empty")
        return trimmed

    @field_validator("enabledGenreNames")
    @classmethod
    def validate_genres(cls, values: list[str]) -> list[str]:
        trimmed = [value.strip() for value in values]
        if any(not value for value in trimmed):
            raise ValueError("genre names must not be empty")
        normalized = [normalized_genre_value(value) for value in trimmed]
        if len(set(normalized)) != len(normalized):
            raise ValueError("genre names must be unique")
        return trimmed


class GenreDisplayPresetWrite(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    name: str
    enabledGenreNames: list[str]
    includesUnassignedGenreSetting: bool | None = True

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        return GenreDisplayPresetV1.validate_name(value)

    @field_validator("enabledGenreNames")
    @classmethod
    def validate_genres(cls, values: list[str]) -> list[str]:
        return GenreDisplayPresetV1.validate_genres(values)


class GenreDisplayPresetOrder(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    ids: list[Annotated[UUID, Field(strict=False)]]

    @field_validator("ids")
    @classmethod
    def validate_ids(cls, values: list[UUID]) -> list[UUID]:
        if len(set(values)) != len(values):
            raise ValueError("ids must be unique")
        return values


GenrePresetsExportV1.model_rebuild()
