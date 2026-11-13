#!/usr/bin/env bash
# Runs inside the CI Android emulator. Installs the debug APK, launches it,
# stops it, launches it again, and captures the screen each time; then runs
# the on-device test. Any crash in the log marks the check as not passed.
set -uo pipefail

APK="apk/app-debug.apk"
PKG="app.habit_adventure"
OK=0
mkdir -p ci_out device_shots

shot() { adb exec-out screencap -p > "device_shots/$1.png" || true; }

echo "== install" | tee ci_out/device.txt
adb install -r "$APK" 2>&1 | tee -a ci_out/device.txt || OK=1
adb logcat -c || true

echo "== first launch" | tee -a ci_out/device.txt
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 30
shot d01_first_launch
PID1="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
echo "pid after first launch: ${PID1:-none}" | tee -a ci_out/device.txt
[ -n "$PID1" ] || OK=1

echo "== stop and relaunch" | tee -a ci_out/device.txt
adb shell am force-stop "$PKG"
sleep 3
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a ci_out/device.txt
sleep 15
shot d02_relaunch
PID2="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
echo "pid after relaunch: ${PID2:-none}" | tee -a ci_out/device.txt
[ -n "$PID2" ] || OK=1

echo "== Fold-like window sizes" | tee -a ci_out/device.txt
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

adb logcat -d > ci_out/device_logcat_full.txt 2>/dev/null || true
grep -E "flutter|AndroidRuntime|$PKG" ci_out/device_logcat_full.txt | tail -400 > ci_out/device_logcat.txt || true
rm -f ci_out/device_logcat_full.txt
if grep -qE "FATAL EXCEPTION|Unhandled Exception|E/flutter" ci_out/device_logcat.txt; then
  echo "crash markers found in logcat" | tee -a ci_out/device.txt
  OK=1
fi
adb shell am force-stop "$PKG" || true

echo "== on-device test" | tee -a ci_out/device.txt
set -o pipefail
flutter test integration_test -d emulator-5554 --reporter expanded 2>&1 | tee ci_out/device_integration.txt || OK=1

echo "device check exit: $OK" | tee -a ci_out/device.txt
exit $OK
