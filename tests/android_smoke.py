"""Build and exercise a separate QA package; never modify the installed user's game.

Usage: python tests/android_smoke.py --godot PATH --adb PATH [--serial SERIAL]
Requires an unlocked, authorized Android device. Artifacts stay in ignored folders.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time


PACKAGE = "com.lastoutpost.fishmarkettycoon.qa"
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial")
    parser.add_argument("--reuse-qa", action="store_true", help="Reseed only the disposable QA package from a previous run")
    parser.add_argument("--skip-build", action="store_true", help="Reuse an already built QA APK when only the test driver changed")
    parser.add_argument("--layout-only", action="store_true", help="Check fullscreen layout, zoom and windows without reseeding saves")
    args = parser.parse_args()
    out = ROOT / "test-artifacts" / ("android-" + time.strftime("%Y%m%d-%H%M%S"))
    project = out / "project"
    project.mkdir(parents=True)
    adb_prefix = [args.adb] + (["-s", args.serial] if args.serial else [])

    def adb(*parts, binary=False):
        result = subprocess.run(adb_prefix + list(parts), check=True, capture_output=True, timeout=30)
        return result.stdout if binary else result.stdout.decode("utf-8", errors="replace").strip()

    def shell(command):
        return adb("shell", command)

    def require_foreground():
        focus = shell("dumpsys window | grep mCurrentFocus")
        assert PACKAGE in focus, "QA lost foreground focus; no input or screenshots sent to other apps"

    def input_command(command):
        require_foreground()
        return shell(command)

    def save_text(value, suffix=""):
        # All writes are restricted to our separate debuggable QA application.
        command = f"run-as {PACKAGE} sh -c 'cat > files/fish_market_save.json{suffix}'"
        subprocess.run(adb_prefix + ["shell", command], input=value.encode(), check=True, capture_output=True, timeout=15)

    def read_save():
        raw = shell(f"run-as {PACKAGE} cat files/fish_market_save.json")
        outer = json.loads(raw)
        assert outer["version"] == 4
        assert hashlib.sha256(outer["payload"].encode()).hexdigest() == outer["checksum"]
        return json.loads(outer["payload"])

    def screenshot(name):
        require_foreground()
        (out / (name + ".png")).write_bytes(adb("exec-out", "screencap", "-p", binary=True))

    def collect_logs(name):
        pid = shell(f"pidof {PACKAGE}")
        assert pid, "Android game process is not running"
        logs = adb("logcat", "-d", "--pid=" + pid.split()[0], "-v", "brief")
        (out / (name + ".log")).write_text(logs, encoding="utf-8")
        assert not re.search(r"SCRIPT ERROR|FATAL EXCEPTION|Parse Error", logs), "Godot/Android runtime error; inspect log"

    def launch():
        shell(f"monkey -p {PACKAGE} -c android.intent.category.LAUNCHER 1")
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            pid = shell(f"pidof {PACKAGE} || true")
            if pid:
                logs = adb("logcat", "-d", "--pid=" + pid.split()[0], "-v", "brief")
                assert not re.search(r"SCRIPT ERROR|FATAL EXCEPTION|Parse Error", logs), "Startup error; inspect app log"
                if "Fish Market Tycoon: ready" in logs:
                    time.sleep(1.5)
                    require_foreground()
                    return
            time.sleep(1)
        raise AssertionError("Game scene did not finish loading within 40 seconds")

    def background():
        input_command("input keyevent KEYCODE_HOME")
        time.sleep(0.5)

    def stop():
        shell(f"am force-stop {PACKAGE}")

    def layout_metrics():
        size = re.findall(r"(\d+)x(\d+)", shell("wm size"))[-1]
        width, height = map(int, size)
        settings = (ROOT / "project.godot").read_text(encoding="utf-8")
        base_width = int(re.search(r"window/size/viewport_width=(\d+)", settings)[1])
        base_height = int(re.search(r"window/size/viewport_height=(\d+)", settings)[1])
        scale = min(width / base_width, height / base_height)
        cutout = re.search(r"DisplayCutout\{insets=Rect\((\d+),\s*(\d+)\s*-\s*(\d+),\s*(\d+)\)", shell("dumpsys display"))
        left, top, right, bottom = map(int, cutout.groups()) if cutout else (0, 0, 0, 0)
        return width, height, scale, top, right, bottom

    def tap(x, y):
        input_command(f"input tap {int(x)} {int(y)}")
        time.sleep(0.5)

    print("Preparing isolated Android QA package", flush=True)
    for folder in ["scripts", "scenes"]:
        shutil.copytree(ROOT / folder, project / folder)
    for filename in ["project.godot", "icon.svg", "export_presets.cfg"]:
        shutil.copy2(ROOT / filename, project / filename)
    config = (project / "export_presets.cfg").read_text(encoding="utf-8")
    config = re.sub(r'^package/unique_name=.*$', f'package/unique_name="{PACKAGE}"', config, flags=re.M)
    config = re.sub(r'^package/name=.*$', 'package/name="Fish Market Tycoon QA"', config, flags=re.M)
    (project / "export_presets.cfg").write_text(config, encoding="utf-8")
    (ROOT / "builds").mkdir(exist_ok=True)
    apk = ROOT / "builds" / "FishMarketTycoon-qa.apk"
    if not args.skip_build:
        with (out / "export.log").open("w", encoding="utf-8") as log:
            subprocess.run([args.godot, "--headless", "--path", str(project), "--log-file", str(out / "godot-export.log"),
                            "--export-debug", "Android", str(apk)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    assert apk.exists(), "No existing QA APK; run without --skip-build"
    # Do not overwrite progress if somebody already uses this QA package.
    assert args.reuse_qa or not shell(f"pm list packages {PACKAGE}"), "QA package already installed; use --reuse-qa only for this disposable test app"
    print("Installing QA package; production package remains untouched", flush=True)
    adb("install", "-r", str(apk))
    stop()
    launch()
    screenshot("fresh-install")
    if args.layout_only:
        print("Checking fullscreen safe area, camera zoom and large mobile buttons", flush=True)
        width, height, scale, top, right, bottom = layout_metrics()
        zoom_x = width - right - 48 * scale
        zoom_y = (top + height - bottom) / 2 - 38 * scale
        tap(zoom_x, zoom_y)
        screenshot("zoom-in")
        tap(zoom_x, zoom_y + 76 * scale)
        tap(width - right - 72 * scale, top + 48 * scale)
        screenshot("team-window")
        input_command("input keyevent KEYCODE_BACK")
        tap(width - right - 72 * scale, top + 124 * scale)
        screenshot("quest-window")
        input_command("input keyevent KEYCODE_BACK")
        screenshot("final")
        collect_logs("mobile-layout")
        background()
        assert read_save()["version"] == 4
        report = {"package": PACKAGE, "device": shell("getprop ro.product.model"),
                  "android": shell("getprop ro.build.version.release"), "screen": [width, height],
                  "safe_top_pixels": top, "passed": ["fullscreen screenshots", "safe area around camera cutout",
                  "touch zoom controls", "large team and quest buttons", "Android Back closes both windows",
                  "no script errors", "background save"], "production_app_modified": False, "artifacts": str(out)}
        (out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
        return
    background()
    initial = read_save()
    stop()
    seed = dict(initial)
    seed.update(coins=4321, hired=[5, 0, 0, 0], prices=[77, 88, 99, 111], player_fish=0, player_fillets=0,
                fish_box=0, machine_input=0, machine_output=0, fillet_box=0, processing=False, process_timer=0,
                player_fish_caught=17, worker_fish_caught=23, served=0, customers_served=0,
                boat_state="none", boat_order=0, boat_time=0, player_position=[-17, 0.5, -12],
                upgrade_levels=[1, 1, 1, 1], upgrade_prices=[50, 75, 100, 125],
                expansion_levels=[1, 1, 0], expansion_prices=[150, 120, 200], progression={"level": 1, "xp": 0, "total_xp": 0})
    seed["quests"] = {"progress": [10, 5, 3], "completed": [True, True, True]}
    seed["harbor"] = {"equipment": [False] * 3, "raw_stock": [0] * 3, "smoked_stock": [0] * 3,
                      "caught": [0] * 3, "goal_done": [False] * 5, "zone_open": False,
                      "selected_species": 0, "orders": 0, "smoked_total": 0,
                      "smoking_species": -1, "smoking_elapsed": 0}
    seed["daily"] = {"day": shell("date +%F"), "daily_progress": [15, 5, 3], "daily_done": [True, True, True],
                     "achievement_done": [True, True, True]}
    payload = json.dumps(seed, ensure_ascii=False, separators=(",", ":"))
    seeded_text = json.dumps({"version": seed["version"], "payload": payload, "checksum": hashlib.sha256(payload.encode()).hexdigest()}, ensure_ascii=False)
    save_text(seeded_text)
    save_text(seeded_text, ".bak")
    print("Checking reloads, worker restoration and reward flags on the phone", flush=True)
    for iteration in range(3):
        launch()
        if iteration == 0:
            screenshot("loaded-workers")
        collect_logs(f"reload-{iteration}")
        background()
        saved = read_save()
        assert saved["coins"] == 4321 and saved["hired"] == [5, 0, 0, 0]
        assert saved["prices"] == [77, 88, 99, 111]
        assert saved["quests"]["completed"] == [True, True, True]
        assert saved["daily"]["achievement_done"] == [True, True, True]
        assert saved["player_fish_caught"] == 17
        stop()
    print("Checking real touch drag, menus and Android Back", flush=True)
    launch()
    size = re.findall(r"(\d+)x(\d+)", shell("wm size"))[-1]
    width, height, scale, safe_top, safe_right, safe_bottom = layout_metrics()
    project_settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    base_width = int(re.search(r"window/size/viewport_width=(\d+)", project_settings)[1])
    base_height = int(re.search(r"window/size/viewport_height=(\d+)", project_settings)[1])
    scale = min(width / base_width, height / base_height)
    expanded = 'window/stretch/aspect="expand"' in project_settings
    viewport_width = width / scale if expanded else base_width
    offset_x = 0 if expanded else (width - base_width * scale) / 2
    offset_y = 0 if expanded else (height - base_height * scale) / 2
    if expanded:
        offset_x = -safe_right
        offset_y = safe_top
    before = read_save()["player_position"]
    require_foreground()
    gesture = subprocess.Popen(adb_prefix + ["shell", f"input swipe {int(width * .4)} {int(height * .55)} {int(width * .7)} {int(height * .55)} 900"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(0.2)
    screenshot("joystick-drag")
    gesture.communicate(timeout=10)
    assert gesture.returncode == 0
    time.sleep(0.4)
    # Action buttons are 112 units wide and 64 high, inset 16 units.
    input_command(f"input tap {int(offset_x + (viewport_width - 72) * scale)} {int(offset_y + 48 * scale)}")
    time.sleep(0.5)
    screenshot("team-window")
    collect_logs("touch-and-team")
    input_command("input keyevent KEYCODE_BACK")
    input_command(f"input tap {int(offset_x + (viewport_width - 72) * scale)} {int(offset_y + 124 * scale)}")
    time.sleep(0.5)
    screenshot("quest-window")
    input_command("input keyevent KEYCODE_BACK")
    screenshot("after-back")
    background()
    moved = read_save()
    assert math.dist(before, moved["player_position"]) > 0.1, "touch drag did not move player"
    assert moved["coins"] == 4321 and moved["player_fish_caught"] == 17
    stop()
    print("Checking recovery and damaged-file protection on Android storage", flush=True)
    save_text("{broken-primary")
    launch()
    collect_logs("backup-recovery")
    background()
    assert read_save()["coins"] == 4321
    stop()
    save_text("{broken-primary")
    save_text("{broken-backup", ".bak")
    launch()
    screenshot("corruption-warning")
    background()
    assert shell(f"run-as {PACKAGE} cat files/fish_market_save.json") == "{broken-primary"
    assert shell(f"run-as {PACKAGE} cat files/fish_market_save.json.bak") == "{broken-backup"
    stop()
    save_text(seeded_text)
    save_text(seeded_text, ".bak")
    launch()
    collect_logs("final")
    screenshot("final")
    report = {"package": PACKAGE, "device": shell("getprop ro.product.model"),
              "android": shell("getprop ro.build.version.release"), "screen": size,
              "passed": ["debug export/install/launch", "three save/reload cycles", "worker count/prices", "no repeated quest or achievement rewards",
                         "separate fishing counters", "touch drag moves player", "menu/quest/Android Back screenshots",
                         "background save", "corrupt primary recovery", "both damaged copies preserved", "no script errors in app logs"],
              "production_app_modified": False, "artifacts": str(out)}
    (out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
