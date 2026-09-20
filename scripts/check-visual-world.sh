#!/bin/bash
# Native macOS XCTest harness for display-only analysis/simulation; creates no Simulator devices.
set -euo pipefail
cd "$(dirname "$0")/.."
task_dir="$(mktemp -d /tmp/mymusic-visual-tests.XXXXXX)"
developer_dir="$(xcode-select -p)"
platform_dir="$developer_dir/Platforms/MacOSX.platform/Developer"
for name in VisualWorldDynamicsTests VisualWorldInstallationTests; do
    sed '/@testable import MyMusic/d' "MyMusicTests/$name.swift" > "$task_dir/$name.swift"
done
cat > "$task_dir/main.swift" <<'SWIFT'
import XCTest
let suite = XCTestSuite(name: "Visual World Beta 3")
suite.addTest(VisualWorldDynamicsTests.defaultTestSuite)
suite.addTest(VisualWorldInstallationTests.defaultTestSuite)
suite.run()
guard let result = suite.testRun else { fatalError("No test run") }
print("TEST RESULT: \(result.executionCount) tests, \(result.totalFailureCount) failures")
exit(result.totalFailureCount == 0 && result.executionCount == 14 ? 0 : 1)
SWIFT
xcrun swiftc -module-cache-path "$task_dir/module-cache" \
    -I "$platform_dir/usr/lib" -L "$platform_dir/usr/lib" \
    -F "$platform_dir/Library/Frameworks" \
    -Xlinker -rpath -Xlinker "$platform_dir/Library/Frameworks" \
    -Xlinker -rpath -Xlinker "$platform_dir/Library/PrivateFrameworks" \
    -Xlinker -rpath -Xlinker "$platform_dir/usr/lib" \
    MyMusic/Services/VisualWorldAudioAnalyzer.swift \
    MyMusic/Views/Player/VisualWorldDynamics.swift \
    MyMusic/Views/Player/VisualWorldSimulation.swift \
    MyMusic/Views/Player/PlasmaSparkPattern.swift \
    MyMusic/Views/Player/VisualizerRipplePattern.swift \
    "$task_dir/VisualWorldDynamicsTests.swift" "$task_dir/VisualWorldInstallationTests.swift" \
    "$task_dir/main.swift" -o "$task_dir/tests"
"$task_dir/tests"
printf 'Harness artifacts: %s\n' "$task_dir"
