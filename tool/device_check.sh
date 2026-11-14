#!/usr/bin/env bash
# Runs inside the CI Android emulator.
#
#  1. Builds the debug APK and installs it.
#  2. Launches it, stops it, launches it again, and captures the screen each
#     time, then again at Fold-like window sizes.
#  3. Runs the on-device test (first run, a completed quest, reopen storage).
#
# The job passes when the app installs, starts, restarts and logs no crash.
# The on-device test's own result is recorded separately in device.txt.
set -uo pipefail

PKG="app.habit_adventure"
APK="build/app/outputs/flutter-apk/app-debug.apk"
OK=0
mkdir -p ci_out device_shots

shot() { adb exec-out screencap -p > "device_shots/$1.png" || true; }
say() { echo "$*" | tee -a ci_out/device.txt; }

: > ci_out/device.txt
say "== build"
flutter build apk --debug 2>&1 | tail -4 | tee -a ci_out/device.txt
[ -f "$APK" ] || { say "no APK was built"; exit 1; }

say "== install"
adb install -r "$APK" 2>&1 | tee -a ci_out/device.txt || OK=1
adb logcat -c || true

say "== first launch"
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 30
shot d01_first_launch
PID1="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
say "pid after first launch: ${PID1:-none}"
[ -n "$PID1" ] || OK=1

say "== stop and relaunch"
adb shell am force-stop "$PKG"
sleep 3
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 15
shot d02_relaunch
PID2="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
say "pid after relaunch: ${PID2:-none}"
[ -n "$PID2" ] || OK=1

say "== Fold-like window sizes"
adb shell wm density 480 || true
adb shell wm size 1248x1972 || true
sleep 8
shot d03_cover_size
adb shell wm size 2448x1848 || true
sleep 8
shot d04_open_size
adb shell wm size reset || true
adb shell wm density reset || true
sleep 4

adb logcat -d 2>/dev/null | grep -E "flutter|AndroidRuntime|FATAL|$PKG" | tail -300 > ci_out/device_logcat.txt || true
if grep -qE "FATAL EXCEPTION|Unhandled Exception|E/flutter|Fatal signal" ci_out/device_logcat.txt; then
  say "crash markers found in logcat after launch"
  OK=1
fi
adb shell am force-stop "$PKG" || true
say "launch check result: $OK (0 = passed)"

say "== on-device test"
adb logcat -c || true
set +e
flutter test integration_test -d emulator-5554 --reporter expanded > ci_out/device_integration_full.txt 2>&1
TEST=$?
set -e
grep -vE "Unzipping|^\[=*" ci_out/device_integration_full.txt | tail -120 > ci_out/device_integration.txt || true
rm -f ci_out/device_integration_full.txt
adb logcat -d 2>/dev/null | grep -E "flutter|AndroidRuntime|FATAL|DEBUG|libc|ActivityManager.*$PKG|$PKG" | tail -400 > ci_out/device_integration_logcat.txt || true
adb logcat -d -b crash 2>/dev/null | tail -120 > ci_out/device_crash_buffer.txt || true
say "on-device test exit: $TEST (0 = passed)"

exit $OK
