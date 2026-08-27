#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVICE_NAME="${DEVICE_NAME:-Vspera}"
SCHEME="${SCHEME:-MyMusic}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/MyMusic-iPhone-DerivedData}"
LAUNCH_APP="${LAUNCH_APP:-1}"

info() {
    printf '[INFO] %s\n' "$1"
}

ok() {
    printf '[OK] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1" >&2
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

resolve_from_root() {
    if [[ "$1" = /* ]]; then
        printf '%s\n' "$1"
    else
        printf '%s/%s\n' "$PROJECT_ROOT" "$1"
    fi
}

cd "$PROJECT_ROOT"

info "Git状態を確認します（変更は行いません）。"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_status="$(git status --short)"
    if [[ -n "$git_status" ]]; then
        printf '%s\n' "$git_status"
        warn "未コミットの変更があります。この状態を保持したままデプロイを続行します。"
    else
        ok "Git working tree is clean."
    fi
else
    warn "Gitリポジトリとして認識できません。デプロイ処理は続行します。"
fi

info "対象iPhoneを確認します: $DEVICE_NAME"
set +e
check_output="$(DEVICE_NAME="$DEVICE_NAME" "$SCRIPT_DIR/check-iphone.sh" 2>&1)"
check_status=$?
set -e
printf '%s\n' "$check_output"
[[ $check_status -eq 0 ]] || fail "対象iPhoneの確認に失敗したため、ビルド前に停止しました。"

device_udid="$(printf '%s\n' "$check_output" | sed -n 's/^\[OK\] Device UDID: //p' | tail -n 1)"
[[ -n "$device_udid" ]] || fail "check-iphone.sh の結果からDevice UDIDを取得できませんでした。"

container_path=""
container_kind=""

if [[ -n "${WORKSPACE:-}" ]]; then
    container_path="$(resolve_from_root "$WORKSPACE")"
    [[ -d "$container_path" ]] || fail "指定されたWorkspaceが見つかりません: $container_path"
    container_kind="workspace"
else
    workspaces=("$PROJECT_ROOT"/*.xcworkspace)
    if [[ -e "${workspaces[0]}" ]]; then
        [[ ${#workspaces[@]} -eq 1 ]] || fail "ルートに複数の.xcworkspaceがあります。WORKSPACE環境変数で指定してください。"
        container_path="${workspaces[0]}"
        container_kind="workspace"
    fi
fi

if [[ -z "$container_path" ]]; then
    if [[ -n "${PROJECT:-}" ]]; then
        container_path="$(resolve_from_root "$PROJECT")"
        [[ -d "$container_path" ]] || fail "指定されたProjectが見つかりません: $container_path"
    else
        projects=("$PROJECT_ROOT"/*.xcodeproj)
        [[ -e "${projects[0]}" ]] || fail "ルートに.xcworkspaceまたは.xcodeprojが見つかりません。"
        [[ ${#projects[@]} -eq 1 ]] || fail "ルートに複数の.xcodeprojがあります。PROJECT環境変数で指定してください。"
        container_path="${projects[0]}"
    fi
    container_kind="project"
fi

container_args=("-$container_kind" "$container_path")
ok "Xcode ${container_kind}: $container_path"

mkdir -p "$DERIVED_DATA_PATH"
scheme_json="$DERIVED_DATA_PATH/schemes.json"

if ! xcodebuild "${container_args[@]}" -list -json > "$scheme_json"; then
    fail "Xcode構成の読み取りに失敗しました。"
fi

scheme_found=0
for scheme_root in workspace project; do
    scheme_index=0
    while listed_scheme="$(/usr/bin/plutil -extract "${scheme_root}.schemes.${scheme_index}" raw "$scheme_json" 2>/dev/null)"; do
        if [[ "$listed_scheme" == "$SCHEME" ]]; then
            scheme_found=1
            break
        fi
        scheme_index=$((scheme_index + 1))
    done
done

[[ $scheme_found -eq 1 ]] || fail "Scheme「${SCHEME}」が見つかりません。SCHEME環境変数またはXcodeの共有Scheme設定を確認してください。"
ok "Scheme: $SCHEME"

common_build_args=(
    "${container_args[@]}"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -sdk iphoneos
    -destination "platform=iOS,id=$device_udid"
    -destination-timeout 30
    -derivedDataPath "$DERIVED_DATA_PATH"
)

info "実機向けBuild Settingsを確認します。"
if ! build_settings="$(xcodebuild "${common_build_args[@]}" -showBuildSettings)"; then
    fail "実機向けBuild Settingsを取得できませんでした。端末状態またはXcode構成を確認してください。"
fi

product_name="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*PRODUCT_NAME = //p' | tail -n 1)"
bundle_id="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = //p' | tail -n 1)"
deployment_target="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = //p' | tail -n 1)"
development_team="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = //p' | tail -n 1)"
target_build_dir="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*TARGET_BUILD_DIR = //p' | tail -n 1)"
wrapper_name="$(printf '%s\n' "$build_settings" | sed -n 's/^[[:space:]]*WRAPPER_NAME = //p' | tail -n 1)"

info "Configuration: $CONFIGURATION"
info "Product: ${product_name:-unknown}"
info "Bundle Identifier: ${bundle_id:-unknown}"
info "Development Team: ${development_team:-unknown}"
info "iOS Deployment Target: ${deployment_target:-unknown}"
info "DerivedData: $DERIVED_DATA_PATH"

build_log="$DERIVED_DATA_PATH/build.log"
info "Debug実機ビルドを開始します。"
if ! xcodebuild "${common_build_args[@]}" build 2>&1 | tee "$build_log"; then
    fail "実機ビルドに失敗しました。詳細: $build_log"
fi
ok "Build succeeded."

app_path=""
if [[ -n "$target_build_dir" && -n "$wrapper_name" && -d "$target_build_dir/$wrapper_name" ]]; then
    app_path="$target_build_dir/$wrapper_name"
else
    products_dir="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos"
    if [[ -d "$products_dir" ]]; then
        app_candidates=("$products_dir"/*.app)
        if [[ -e "${app_candidates[0]}" && ${#app_candidates[@]} -eq 1 ]]; then
            app_path="${app_candidates[0]}"
        fi
    fi
fi

[[ -n "$app_path" && -d "$app_path" ]] || fail "生成された.appを一意に検出できませんでした。DerivedDataを確認してください: $DERIVED_DATA_PATH"
ok "App bundle: $app_path"

built_bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$app_path/Info.plist" 2>/dev/null || true)"
if [[ -n "$built_bundle_id" ]]; then
    bundle_id="$built_bundle_id"
fi
[[ -n "$bundle_id" ]] || fail "生成された.appからBundle Identifierを取得できませんでした。"

info "「${DEVICE_NAME}」へインストールします。"
if ! xcrun devicectl device install app --device "$device_udid" --timeout 120 "$app_path"; then
    fail "インストールに失敗しました。端末の接続、ロック解除、Developer Mode、署名を確認してください。"
fi
ok "Install succeeded: $bundle_id"

if [[ "$LAUNCH_APP" == "0" ]]; then
    info "LAUNCH_APP=0 のため起動を省略しました。"
    exit 0
fi

info "「${DEVICE_NAME}」でMyMusicを起動します。"
if xcrun devicectl device process launch --device "$device_udid" --timeout 30 "$bundle_id"; then
    ok "Launch succeeded: $bundle_id"
else
    warn "インストールは成功しましたが起動できませんでした。端末をロック解除して手動起動を確認してください。"
fi
