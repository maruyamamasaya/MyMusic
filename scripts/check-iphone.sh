#!/bin/bash

set -Eeuo pipefail

DEVICE_NAME="${DEVICE_NAME:-Vspera}"

info() {
    printf '[INFO] %s\n' "$1"
}

ok() {
    printf '[OK] %s\n' "$1"
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v xcrun >/dev/null 2>&1 || fail "xcrun が見つかりません。Xcode Command Line Tools をインストールしてください。"

if ! developer_dir="$(xcode-select -p 2>/dev/null)"; then
    fail "有効なXcode Command Line Toolsが選択されていません。xcode-select の設定を確認してください。"
fi

[[ -d "$developer_dir" ]] || fail "xcode-select が存在しないDeveloper Directoryを指しています: $developer_dir"
xcrun --find xcodebuild >/dev/null 2>&1 || fail "xcodebuild が見つかりません。Xcodeのインストールと xcode-select の設定を確認してください。"
xcrun --find devicectl >/dev/null 2>&1 || fail "devicectl が見つかりません。対応するXcodeを選択してください。"
[[ -x /usr/bin/plutil ]] || fail "デバイス情報の解析に必要な /usr/bin/plutil が見つかりません。"

ok "xcrun: $(command -v xcrun)"
ok "Developer Directory: $developer_dir"
ok "Xcode: $(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mymusic-device-check.XXXXXX")"
devices_json="$temp_dir/devices.json"

cleanup() {
    rm -f "$devices_json"
    rmdir "$temp_dir" 2>/dev/null || true
}
trap cleanup EXIT

info "CoreDeviceが認識しているデバイス一覧:"
set +e
devices_output="$(xcrun devicectl list devices --timeout 15 --json-output "$devices_json" 2>&1)"
devices_status=$?
set -e
printf '%s\n' "$devices_output"

if [[ $devices_status -ne 0 || ! -s "$devices_json" ]]; then
    fail "iOSデバイス一覧を取得できませんでした。iPhoneの接続、ロック解除、Macの信頼設定、Xcode/macOSの権限を確認してください。"
fi

device_index=0
matched_index=""
known_ios_names=()

while device_name="$(/usr/bin/plutil -extract "result.devices.${device_index}.deviceProperties.name" raw "$devices_json" 2>/dev/null)"; do
    platform="$(/usr/bin/plutil -extract "result.devices.${device_index}.hardwareProperties.platform" raw "$devices_json" 2>/dev/null || true)"
    reality="$(/usr/bin/plutil -extract "result.devices.${device_index}.hardwareProperties.reality" raw "$devices_json" 2>/dev/null || true)"

    if [[ "$platform" == "iOS" && "$reality" == "physical" ]]; then
        known_ios_names+=("$device_name")
        if [[ "$device_name" == "$DEVICE_NAME" && -z "$matched_index" ]]; then
            matched_index="$device_index"
        fi
    fi

    device_index=$((device_index + 1))
done

if [[ -z "$matched_index" ]]; then
    if [[ ${#known_ios_names[@]} -eq 0 ]]; then
        fail "物理iOSデバイスが見つかりません。対象iPhoneを接続し、ロック解除と信頼設定を確認してください。"
    fi

    printf '[ERROR] 対象iPhone「%s」が見つかりません（名前は完全一致で確認します）。\n' "$DEVICE_NAME" >&2
    printf '[INFO] 認識済みの物理iOSデバイス:' >&2
    printf ' %s' "${known_ios_names[@]}" >&2
    printf '\n' >&2
    printf '[INFO] 別名を使う場合: DEVICE_NAME="デバイス名" ./scripts/check-iphone.sh\n' >&2
    exit 1
fi

device_udid="$(/usr/bin/plutil -extract "result.devices.${matched_index}.hardwareProperties.udid" raw "$devices_json" 2>/dev/null || true)"
core_device_id="$(/usr/bin/plutil -extract "result.devices.${matched_index}.identifier" raw "$devices_json" 2>/dev/null || true)"
tunnel_state="$(/usr/bin/plutil -extract "result.devices.${matched_index}.connectionProperties.tunnelState" raw "$devices_json" 2>/dev/null || true)"
pairing_state="$(/usr/bin/plutil -extract "result.devices.${matched_index}.connectionProperties.pairingState" raw "$devices_json" 2>/dev/null || true)"
developer_mode="$(/usr/bin/plutil -extract "result.devices.${matched_index}.deviceProperties.developerModeStatus" raw "$devices_json" 2>/dev/null || true)"

[[ -n "$device_udid" ]] || fail "「${DEVICE_NAME}」のUDIDを取得できませんでした。再接続後にXcodeのDevices and Simulatorsで状態を確認してください。"
[[ -n "$core_device_id" ]] || fail "「${DEVICE_NAME}」のCoreDevice IDを取得できませんでした。"

ok "Target device: $DEVICE_NAME"
ok "Device UDID: $device_udid"
ok "CoreDevice ID: $core_device_id"
info "Pairing state: ${pairing_state:-unknown}"
info "Developer Mode: ${developer_mode:-unknown}"
info "Tunnel state: ${tunnel_state:-unknown}"

if [[ "$tunnel_state" == "unavailable" ]]; then
    fail "「${DEVICE_NAME}」は認識済みですが現在利用できません。接続、ロック解除、信頼設定、Developer Modeを確認してください。"
fi

if [[ -n "$pairing_state" && "$pairing_state" != "paired" ]]; then
    fail "「${DEVICE_NAME}」はMacとペアリングされていません。XcodeのDevices and Simulatorsで信頼・ペアリングを完了してください。"
fi

if [[ -n "$developer_mode" && "$developer_mode" != "enabled" ]]; then
    fail "「${DEVICE_NAME}」のDeveloper Modeが有効ではありません。iPhone側でDeveloper Modeを有効にしてください。"
fi

ok "「${DEVICE_NAME}」は実機デプロイに利用可能です。"
