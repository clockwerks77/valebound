#!/usr/bin/env bash
# Runs inside the CI Android emulator. Both APKs are built before the
# emulator starts (see .github/workflows/build.yml); nothing is compiled
# here, because a build beside the emulator starves it of memory.
#
#  1. Installs the debug APK, launches it, stops it, launches it again, and
#     captures the screen each time, then again at Fold-like window sizes.
#  2. Runs the on-device test from its prebuilt APK (first run, a completed
#     quest, reopen storage). Its result is recorded but does not decide the
#     job, which passes when the app installs, starts, restarts and logs no
#     crash.
set -uo pipefail

PKG="app.habit_adventure"
APK="apk/app-debug.apk"
TEST_APK="apk/app-debug-test.apk"
OK=0
mkdir -p ci_out device_shots

shot() { timeout 30 adb exec-out screencap -p > "device_shots/$1.png" || true; }
say() { echo "$*" | tee -a ci_out/device.txt; }
alive() { timeout 20 adb shell echo ok 2>/dev/null | grep -q ok; }

: > ci_out/device.txt
[ -f "$APK" ] || { say "no APK to install"; exit 1; }

say "== install"
timeout 180 adb install -r "$APK" 2>&1 | tee -a ci_out/device.txt || OK=1
adb logcat -c || true

say "== first launch"
timeout 60 adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 30
shot d01_first_launch
PID1="$(timeout 20 adb shell pidof "$PKG" | tr -d '\r' || true)"
say "pid after first launch: ${PID1:-none}"
[ -n "$PID1" ] || OK=1

say "== stop and relaunch"
timeout 30 adb shell am force-stop "$PKG"
sleep 3
timeout 60 adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 15
shot d02_relaunch
PID2="$(timeout 20 adb shell pidof "$PKG" | tr -d '\r' || true)"
say "pid after relaunch: ${PID2:-none}"
[ -n "$PID2" ] || OK=1

say "== Fold-like window sizes"
timeout 20 adb shell wm density 480 || true
timeout 20 adb shell wm size 1248x1972 || true
sleep 8
shot d03_cover_size
timeout 20 adb shell wm size 2448x1848 || true
sleep 8
shot d04_open_size
timeout 20 adb shell wm size reset || true
timeout 20 adb shell wm density reset || true
sleep 4

timeout 60 adb logcat -d 2>/dev/null | grep -E "flutter|AndroidRuntime|FATAL|$PKG" | tail -300 > ci_out/device_logcat.txt || true
if grep -qE "FATAL EXCEPTION|Unhandled Exception|E/flutter|Fatal signal" ci_out/device_logcat.txt; then
  say "crash markers found in logcat after launch"
  OK=1
fi
timeout 30 adb shell am force-stop "$PKG" || true
alive || { say "the emulator stopped responding during the launch check"; OK=1; }
say "launch check result: $OK (0 = passed)"

say "== on-device test (recorded, does not decide the job)"
if [ -f "$TEST_APK" ] && alive; then
  adb logcat -c || true
  timeout 60 adb uninstall "$PKG" >/dev/null 2>&1 || true
  set +e
  timeout 600 flutter drive \
    --use-application-binary="$TEST_APK" \
    --driver=test_driver/integration_test.dart \
    -d emulator-5554 --no-pub > ci_out/device_integration.txt 2>&1
  TEST=$?
  set -e
  timeout 60 adb logcat -d 2>/dev/null | grep -E "DEVICE-TEST|flutter|AndroidRuntime|FATAL|libc|$PKG" | tail -300 > ci_out/device_integration_logcat.txt || true
  timeout 30 adb logcat -d -b crash 2>/dev/null | tail -80 > ci_out/device_crash_buffer.txt || true
  alive && say "emulator still responding after the test" || say "the emulator stopped responding during the test"
  say "on-device test exit: $TEST (0 = passed)"
else
  say "on-device test skipped"
fi

exit $OK
