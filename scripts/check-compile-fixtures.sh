#!/usr/bin/env bash
#
# check-compile-fixtures.sh
#
# Verifies the Pipeline<State> phantom types reject invalid stage orderings at
# COMPILE time. SPM can't assert compile *failures* inside a test target, so we
# typecheck standalone fixtures under CompileFixtures/ against the freshly built
# Alloy module and assert each one's exit code matches its
# `EXPECT-COMPILE-{FAILURE,SUCCESS}` marker.
#
set -uo pipefail
cd "$(dirname "$0")/.."

echo "Building Alloy (debug) so fixtures can typecheck against the module..."
if ! swift build >/dev/null 2>&1; then
    echo "FAIL: swift build failed"
    exit 1
fi

# Derive the SDK from the active Xcode toolchain — the one `swift build` uses.
# `xcrun --show-sdk-path` can anomalously resolve to the CommandLineTools SDK,
# whose version won't match the module `swift build` just emitted, causing a
# spurious "cannot load module built with SDK X" failure on every fixture.
SDK="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
TARGET="$(uname -m)-apple-macos14"
# Newer toolchains emit .swiftmodule under Modules/; older ones alongside .build/debug.
INCLUDES=(-I .build/debug/Modules -I .build/debug)

fail=0
shopt -s nullglob
for fixture in CompileFixtures/*.swift; do
    expect="$(grep -om1 'EXPECT-COMPILE-[A-Z]*' "$fixture")"
    swiftc -typecheck -sdk "$SDK" -target "$TARGET" "${INCLUDES[@]}" "$fixture" >/dev/null 2>&1
    rc=$?
    case "$expect" in
        EXPECT-COMPILE-FAILURE)
            if [ "$rc" -eq 0 ]; then
                echo "FAIL: $fixture compiled but should have been REJECTED"
                fail=1
            else
                echo "ok (rejected): $(basename "$fixture")"
            fi
            ;;
        EXPECT-COMPILE-SUCCESS)
            if [ "$rc" -ne 0 ]; then
                echo "FAIL: $fixture should compile but was REJECTED"
                fail=1
            else
                echo "ok (accepted): $(basename "$fixture")"
            fi
            ;;
        *)
            echo "FAIL: $fixture is missing an EXPECT-COMPILE-* marker"
            fail=1
            ;;
    esac
done

if [ "$fail" -eq 0 ]; then
    echo "All compile fixtures behaved as expected."
fi
exit "$fail"
