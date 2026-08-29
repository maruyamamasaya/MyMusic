from __future__ import annotations

import argparse
import importlib
import shutil
import signal
import sys
from pathlib import Path
from typing import Any, Sequence

from . import ANALYSIS_VERSION
from .audio import AnalysisConfig, analyze_audio
from .cache import AnalysisCache
from .discovery import discover_audio_files, relative_path
from .metadata import file_signature, read_metadata
from .normalization import LOUDNESS_ANALYSIS_REVISION, analyze_loudness
from .schema import atomic_write_document, make_document


ANALYZER_ROOT = Path(__file__).resolve().parents[1]


def main(argv: Sequence[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    if args.limit is not None and args.limit < 1:
        parser.error("--limitは1以上にしてください")
    if args.analysis_version < 1:
        parser.error("--analysis-versionは1以上にしてください")
    if args.segment_seconds <= 0 or args.segments < 1:
        parser.error("--segment-secondsと--segmentsは正の値にしてください")

    root = args.music_root.expanduser().resolve()
    if not root.is_dir():
        parser.error(f"音楽Rootが見つかりません: {root}")
    _check_runtime(parser)

    output_path = args.output.expanduser().resolve()
    cache_path = args.cache.expanduser().resolve()
    config = AnalysisConfig(segment_seconds=args.segment_seconds, segment_count=args.segments)
    config_key = config.cache_key()
    root_key = str(root)
    files = discover_audio_files(root)

    print(f"Music root : {root}")
    print(f"Track count: {len(files):,}")
    print(f"Cache      : {cache_path}")
    print(f"Output     : {output_path}")
    print(f"Mode       : {'resume' if args.resume else 'force re-analysis'}")
    if args.limit is not None:
        print(f"Limit      : {args.limit:,} analyses")
    print()

    cache = AnalysisCache(cache_path)
    analyzed = 0
    dsp_analyzed = 0
    loudness_analyzed = 0
    loudness_backfilled = 0
    loudness_failed = 0
    failed = 0
    skipped = 0
    deferred = 0
    interrupted = False
    entries: list[dict[str, Any]] = []
    stop_requested = False

    def request_stop(_signal_number: int, _frame: Any) -> None:
        nonlocal stop_requested, interrupted
        stop_requested = True
        interrupted = True
        print("\n中断要求を受け付けました。現在の1曲が終わり次第停止します。", flush=True)

    previous_sigint_handler = signal.signal(signal.SIGINT, request_stop)

    try:
        for index, path in enumerate(files, start=1):
            if stop_requested:
                interrupted = True
                deferred += len(files) - index + 1
                break
            relative = relative_path(path, root)
            try:
                size, modification_time_ns = file_signature(path)
            except OSError as error:
                failed += 1
                print(f"[{index:,} / {len(files):,}] {relative}\nFile error: {error}\n")
                continue

            cached = cache.valid_result(
                root_key, relative, size, modification_time_ns,
                args.analysis_version, config_key,
            )
            cached_loudness = cache.valid_loudness_result(
                root_key, relative, size, modification_time_ns, LOUDNESS_ANALYSIS_REVISION,
            )
            if cached_loudness is None and cached is not None:
                cached_loudness = _loudness_from_entry(cached)
                if cached_loudness is not None:
                    cache.save_loudness_success(
                        root_key, relative, size, modification_time_ns,
                        LOUDNESS_ANALYSIS_REVISION, cached_loudness,
                    )

            if args.resume and cached is not None and cached_loudness is not None:
                merged = _merge_loudness(cached, cached_loudness)
                if merged != cached:
                    cache.save_success(
                        root_key, relative, size, modification_time_ns,
                        args.analysis_version, config_key, merged,
                    )
                skipped += 1
                if skipped == 1 or skipped % 100 == 0 or index == len(files):
                    print(f"[{index:,} / {len(files):,}] Skip cached: {relative}")
                continue
            if args.limit is not None and analyzed + failed >= args.limit:
                deferred += 1
                continue

            print(f"[{index:,} / {len(files):,}]")
            print(relative)
            print("Analyzing...")
            try:
                if args.resume and cached is not None:
                    entry = cached
                else:
                    metadata = read_metadata(path, root)
                    features = analyze_audio(path, metadata.duration, config)
                    entry = metadata.identity_fields()
                    entry["features"] = features
                    dsp_analyzed += 1

                loudness = cached_loudness if args.resume else None
                if loudness is None:
                    try:
                        loudness = analyze_loudness(path)
                        cache.save_loudness_success(
                            root_key, relative, size, modification_time_ns,
                            LOUDNESS_ANALYSIS_REVISION, loudness,
                        )
                        loudness_analyzed += 1
                        if cached is not None:
                            loudness_backfilled += 1
                    except Exception as error:
                        loudness_failed += 1
                        cache.save_loudness_error(
                            root_key, relative, size, modification_time_ns,
                            LOUDNESS_ANALYSIS_REVISION, f"{type(error).__name__}: {error}",
                        )
                        print(f"Loudness failed: {type(error).__name__}: {error}")
                if loudness is not None:
                    entry = _merge_loudness(entry, loudness)
                cache.save_success(
                    root_key, relative, size, modification_time_ns,
                    args.analysis_version, config_key, entry,
                )
                analyzed += 1
                _print_scores(
                    str(entry.get("artist", "Unknown Artist")),
                    str(entry.get("title", path.stem)),
                    entry["features"],
                )
            except KeyboardInterrupt:
                interrupted = True
                print("\n中断要求を受け付けました。完了済み結果を保存します。")
                break
            except Exception as error:  # A single corrupt/unsupported file must not abort the batch.
                failed += 1
                cache.save_error(
                    root_key, relative, size, modification_time_ns,
                    args.analysis_version, config_key, f"{type(error).__name__}: {error}",
                )
                print(f"Failed: {type(error).__name__}: {error}\n")

        entries = _current_results(
            cache, files, root, root_key, args.analysis_version, config_key,
        )
        document = make_document(args.analysis_version, entries)
        atomic_write_document(document, output_path)
    finally:
        signal.signal(signal.SIGINT, previous_sigint_handler)
        cache.close()

    print("\nSummary")
    print(f"Track count : {len(files):,}")
    print(f"Success     : {len(entries):,}")
    print(f"Failed      : {failed:,}")
    print(f"Skipped     : {skipped:,}")
    print(f"Analyzed    : {analyzed:,}")
    print(f"DSP analyzed: {dsp_analyzed:,}")
    print(f"Loudness    : {loudness_analyzed:,} ({loudness_backfilled:,} cache backfills)")
    print(f"Loudness err: {loudness_failed:,}")
    print(f"Deferred    : {deferred:,}")
    print(f"Output      : {output_path}")
    return 130 if interrupted else 0


def _current_results(
    cache: AnalysisCache,
    files: list[Path],
    root: Path,
    root_key: str,
    analysis_version: int,
    config_key: str,
) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for path in files:
        try:
            relative = relative_path(path, root)
            size, modification_time_ns = file_signature(path)
            result = cache.valid_result(
                root_key, relative, size, modification_time_ns,
                analysis_version, config_key,
            )
            if result is not None:
                entries.append(result)
        except OSError:
            continue
    return entries


def _print_scores(artist: str, title: str, features: dict[str, Any]) -> None:
    print("Done")
    print(f"{artist} - {title}")
    if "tempo" in features:
        print(f"Tempo: {features['tempo']:.1f} BPM")
    print(f"Piano: {features['piano']:.2f}")
    print(f"Ambient: {features['ambient']:.2f}")
    print(f"Energy: {features['energy']:.2f}\n")


def _loudness_from_entry(entry: dict[str, Any]) -> dict[str, float] | None:
    features = entry.get("features")
    if not isinstance(features, dict):
        return None
    names = ("integratedLUFS", "truePeakDBTP", "normalizationGainDB")
    if not all(name in features for name in names):
        return None
    return {name: float(features[name]) for name in names}


def _merge_loudness(entry: dict[str, Any], loudness: dict[str, float]) -> dict[str, Any]:
    merged = dict(entry)
    merged["features"] = {**entry.get("features", {}), **loudness}
    return merged


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Mac上で音楽を解析し、MyMusic Track Feature schema v1 JSONを生成します。"
    )
    parser.add_argument("music_root", type=Path, help="MyMusicに登録した音楽Rootフォルダ")
    parser.add_argument("--limit", type=int, help="この実行で新たに解析する最大曲数")
    parser.add_argument(
        "--output", type=Path, default=ANALYZER_ROOT / "output" / "music_features.json",
        help="出力JSON（default: analyzer/output/music_features.json）",
    )
    parser.add_argument(
        "--cache", type=Path, default=ANALYZER_ROOT / "cache" / "analysis.sqlite3",
        help="SQLite cache path",
    )
    parser.add_argument("--analysis-version", type=int, default=ANALYSIS_VERSION, help="1以上の解析version")
    parser.add_argument("--segment-seconds", type=float, default=30.0, help="各解析区間の秒数")
    parser.add_argument("--segments", type=int, default=3, help="曲中から採取する解析区間数")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--resume", dest="resume", action="store_true", help="有効なcacheをSkip（default）")
    mode.add_argument("--force", dest="resume", action="store_false", help="cacheがあっても再解析")
    parser.set_defaults(resume=True)
    return parser


def _check_runtime(parser: argparse.ArgumentParser) -> None:
    try:
        import lzma  # noqa: F401 - librosa/scikit-learn requires a complete CPython stdlib.
        for module_name in ("librosa", "mutagen", "soundfile"):
            importlib.import_module(module_name)
    except (ImportError, ModuleNotFoundError) as error:
        parser.error(
            "Python環境または依存関係が不完全です。Homebrew Pythonでvenvを作成し、"
            f"requirements.txtを導入してください。Python: {sys.executable} / Error: {error}"
        )
    if shutil.which("ffmpeg") is None:
        parser.error("FFmpegが見つかりません。Homebrew等でffmpegをインストールしてください。")
