"""Run an instrumented, isolated Android QA soak; production data is untouched.

Frame intervals come from the engine main loop, not compositor presentation times.
The debug build and USB charging must be recorded when interpreting measurements.
"""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.lastoutpost.fishmarkettycoon.qa"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--minutes", type=float, default=60)
    parser.add_argument("--reuse-qa", action="store_true")
    parser.add_argument("--resume", type=Path, help="Resume collection for a paused run whose QA process is still alive")
    parser.add_argument("--release", action="store_true", help="Use release engine binaries; QA signing key only")
    parser.add_argument("--uninterrupted", action="store_true", help="Continuous foreground load without planned background cycles")
    args = parser.parse_args()
    assert 0 < args.minutes <= 240
    out = args.resume.resolve() if args.resume else ROOT / "test-artifacts" / ("soak-" + time.strftime("%Y%m%d-%H%M%S"))
    project = out / "project"
    if not args.resume:
        project.mkdir(parents=True)
    prefix = [args.adb, "-s", args.serial]
    release_samples = {}

    def adb(*parts, check=True):
        result = subprocess.run(prefix + list(parts), capture_output=True, timeout=40, check=check)
        return result.stdout.decode("utf-8", errors="replace").strip()

    def shell(command, check=True):
        return adb("shell", command, check=check)

    def artifact(name, content):
        (out / name).write_text(content, encoding="utf-8")

    def private_file(name, check=True):
        assert re.fullmatch(r"[a-zA-Z0-9_.-]+", name)
        if args.release:
            current = shell(f"pidof {PACKAGE}", check=False).split()
            if not current:
                return ""
            value = adb("logcat", "-d", "--pid=" + current[0], "-v", "brief")
            if name == "qa_soak_frames.jsonl":
                for line in re.findall(r"QA soak sample: (\{[^\r\n]*\})", value):
                    row = json.loads(line)
                    assert row["debug_build"] is False, "Expected release engine binaries"
                    release_samples[row["active_seconds"]] = row
                return "\n".join(json.dumps(release_samples[key]) for key in sorted(release_samples))
            if name == "qa_soak_done.json":
                found = re.findall(r"QA soak done: (\{[^\r\n]*\})", value)
                return found[-1] if found else ""
            chunks = {}
            for token, index, count, data in re.findall(r"QA snapshot chunk: ([\d-]+):(\d+):(\d+):([A-Za-z0-9+/=]+)", value):
                chunks.setdefault(token, {"count": int(count), "parts": {}})["parts"][int(index)] = data
            for token in reversed(re.findall(r"QA snapshot end: ([\d-]+)", value)):
                entry = chunks.get(token)
                if entry and len(entry["parts"]) == entry["count"]:
                    return base64.b64decode("".join(entry["parts"][i] for i in range(entry["count"]))).decode("utf-8")
            return ""
        if name == "qa_soak_done.json":
            name = report.get("marker", name)
        return shell(f"run-as {PACKAGE} cat files/{name}", check=check)

    def saved():
        outer = json.loads(private_file("fish_market_save.json"))
        assert hashlib.sha256(outer["payload"].encode()).hexdigest() == outer["checksum"]
        data = json.loads(outer["payload"])
        assert outer["version"] == data["version"] == 4
        return data

    def launch(wait_ready=True):
        shell(f"monkey -p {PACKAGE} -c android.intent.category.LAUNCHER 1")
        for _ in range(40):
            pid = shell(f"pidof {PACKAGE}", check=False)
            if pid and PACKAGE in shell("dumpsys window | grep mCurrentFocus"):
                current_pid = pid.split()[0]
                startup = adb("logcat", "-d", "--pid=" + current_pid, "-v", "brief")
                assert not re.search(r"SCRIPT ERROR|Parse Error|FATAL EXCEPTION", startup), "Startup error"
                if not wait_ready or "Fish Market Tycoon: ready" in startup:
                    return current_pid
            time.sleep(1)
        raise RuntimeError("QA app failed to enter foreground")

    def logs(pid):
        value = adb("logcat", "-d", "--pid=" + pid, "-v", "threadtime")
        artifact(f"app-{pid}.log", value)
        assert not re.search(r"SCRIPT ERROR|Parse Error|FATAL EXCEPTION|QA soak: cannot", value), "Runtime error: inspect app.log"

    def screenshot(name):
        result = subprocess.run(prefix + ["exec-out", "screencap", "-p"], capture_output=True, check=True, timeout=30)
        (out / name).write_bytes(result.stdout)

    def sample(index):
        pid_now = shell(f"pidof {PACKAGE}", check=False)
        assert pid_now.split() == [pid], "QA process stopped or restarted during soak"
        assert PACKAGE in shell("dumpsys window | grep mCurrentFocus"), "QA lost foreground; stop rather than measure another app"
        mem = shell(f"dumpsys meminfo {PACKAGE}")
        thermal = shell("dumpsys thermalservice", check=False)
        battery = shell("dumpsys battery")
        artifact(f"memory-{index:03}.txt", mem)
        artifact(f"thermal-{index:03}.txt", thermal)
        artifact(f"battery-{index:03}.txt", battery)
        pss = re.search(r"TOTAL PSS:\s*(\d+)", mem)
        if not pss:
            pss = re.search(r"^\s*TOTAL\s+(\d+)", mem, re.M)
        rss = re.search(r"TOTAL RSS:\s*(\d+)", mem)
        temp = re.search(r"temperature:\s*(\d+)", battery)
        status = re.search(r"Thermal Status:\s*(\d+)", thermal)
        current_thermal = thermal.split("Current temperatures from HAL:", 1)[-1].split("Current cooling devices", 1)[0]
        sensors = {name: float(value) for value, name in re.findall(
            r"Temperature\{mValue=([\d.]+), mType=\d+, mName=([^,}]+)", current_thermal)}
        row = {"elapsed_seconds": time.monotonic() - start, "pss_kib": int(pss[1]) if pss else None,
               "rss_kib": int(rss[1]) if rss else None, "battery_c": int(temp[1]) / 10 if temp else None,
               "thermal_status": int(status[1]) if status else None, "thermal_sensors_c": sensors}
        samples.append(row)
        raw = private_file("qa_soak_frames.jsonl", check=False)
        artifact("frames.jsonl", raw + "\n")
        engine = [json.loads(line) for line in raw.splitlines() if line.startswith("{")]
        report.update(status="running", samples=samples, engine_samples=engine)
        artifact("report.json", json.dumps(report, ensure_ascii=False, indent=2))
        latest = engine[-1] if engine else {}
        print(json.dumps({"wall_minute": round(row["elapsed_seconds"] / 60, 1),
                          "active_minute": round(latest.get("active_seconds", 0) / 60, 1),
                          "fps": latest.get("fps"), "p95_ms": latest.get("frame_p95_ms"),
                          "pss_mib": round(row["pss_kib"] / 1024, 1) if row["pss_kib"] else None,
                          "battery_c": row["battery_c"], "cycles": latest.get("cycles")}), flush=True)
        logs(pid)
        return engine

    if args.resume:
        assert not args.uninterrupted, "A continuous run cannot be resumed after an interruption"
        report = json.loads((out / "report.json").read_text(encoding="utf-8"))
        assert report["package"] == PACKAGE and report["minutes_requested"] == args.minutes
        assert report["device"] == shell("getprop ro.product.model"), "Different device"
        assert shell(f"pidof {PACKAGE}").split() == [report["pid"]], "QA restarted; begin a fresh run instead"
        samples = report["samples"]
        release_samples.update({row["active_seconds"]: row for row in report.get("engine_samples", [])})
        assert samples, "No previous samples to resume"
        artifact(f"report-before-resume-{int(time.time())}.json", json.dumps(report, ensure_ascii=False, indent=2))
        report.setdefault("interruptions", []).append({"reason": report.pop("error", "collector interrupted"),
                                                       "resume_epoch": time.time()})
        # Older collectors did not store the wall-clock origin. Reconstruct it
        # to within sampling I/O latency from the first memory artifact.
        report.setdefault("started_at_epoch", (out / "memory-000.txt").stat().st_mtime - samples[0]["elapsed_seconds"])
        pid = launch(wait_ready=False)
        start = time.monotonic() - (time.time() - report["started_at_epoch"])
    else:
        assert args.reuse_qa or not shell(f"pm list packages {PACKAGE}"), "Existing disposable QA app requires --reuse-qa"
        for folder in ["scripts", "scenes"]:
            shutil.copytree(ROOT / folder, project / folder)
        for name in ["project.godot", "icon.svg", "export_presets.cfg"]:
            shutil.copy2(ROOT / name, project / name)
        shutil.copy2(ROOT / "tests" / "soak_monitor.gd", project / "scripts" / "qa_soak_monitor.gd")
        settings = (project / "project.godot").read_text(encoding="utf-8")
        settings += '\n[autoload]\n\nQASoak="*res://scripts/qa_soak_monitor.gd"\n\n[qa]\n\nsoak_seconds=%s\nsoak_marker="%s-done.json"\n' % (args.minutes * 60, out.name)
        (project / "project.godot").write_text(settings, encoding="utf-8")
        config = (project / "export_presets.cfg").read_text(encoding="utf-8")
        config = re.sub(r'^package/unique_name=.*$', f'package/unique_name="{PACKAGE}"', config, flags=re.M)
        config = re.sub(r'^package/name=.*$', 'package/name="Fish Market Tycoon QA Soak"', config, flags=re.M)
        if args.release:
            key = Path(os.environ["APPDATA"]) / "Godot" / "keystores" / "debug.keystore"
            assert key.is_file(), "Existing QA debug signing key is required for release profiling"
            config = config.replace("[preset.0.options]", '[preset.0.options]\nkeystore/release="%s"\nkeystore/release_user="androiddebugkey"\nkeystore/release_password="android"' % key.as_posix())
        (project / "export_presets.cfg").write_text(config, encoding="utf-8")
        apk = ROOT / "builds" / ("FishMarketTycoon-soak-release.apk" if args.release else "FishMarketTycoon-soak.apk")
        apk.parent.mkdir(exist_ok=True)
        print("Building isolated instrumented QA APK", flush=True)
        with (out / "export.log").open("w", encoding="utf-8") as log:
            subprocess.run([args.godot, "--headless", "--path", str(project), "--log-file", str(out / "godot-export.log"),
                            "--export-release" if args.release else "--export-debug", "Android", str(apk)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        adb("install", "-r", str(apk))
        shell(f"am force-stop {PACKAGE}")
        # Only our disposable QA telemetry is removed; application saves remain intact.
        if not args.release:
            shell(f"run-as {PACKAGE} rm -f files/qa_soak_frames.jsonl files/qa_soak_done.json")
        report = {"status": "starting", "minutes_requested": args.minutes, "package": PACKAGE,
                  "device": shell("getprop ro.product.model"), "android": shell("getprop ro.build.version.release"),
                  "screen": shell("wm size"), "density": shell("wm density"),
                  "build_type": "instrumented release" if args.release else "instrumented debug",
                  "uninterrupted": args.uninterrupted,
                  "marker": out.name + "-done.json",
                  "frame_source": "engine main-loop wall-clock intervals; not compositor presentation",
                  "limitations": ["single device", "USB charging", "scripted route and UI transitions; not a manual play session"],
                  "production_app_modified": False, "artifacts": str(out)}
        report["source_sha256"] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                   for folder in ("scripts", "scenes") for path in (ROOT / folder).rglob("*")
                                   if path.is_file()}
        report["screen_brightness"] = shell("settings get system screen_brightness")
        report["screen_brightness_mode"] = shell("settings get system screen_brightness_mode")
        report["battery_saver"] = shell("settings get global low_power")
        artifact("device-display.txt", shell("dumpsys display"))
        artifact("device-memory.txt", shell("cat /proc/meminfo"))
        artifact("device-power.txt", shell("dumpsys power"))
        artifact("source-status.txt", subprocess.run(["git", "status", "--short"], cwd=ROOT, capture_output=True, text=True, check=True).stdout)
        pid = launch()
        report["pid"] = pid
        report["started_at_epoch"] = time.time()
        start = time.monotonic()
        samples = []
    print("Soak started: " + str(out), flush=True)
    try:
        index = len(samples)
        background_cycles = report.get("background_cycles", 0)
        next_sample = time.monotonic() + (5 if args.resume else 65)
        active_before = report.get("engine_samples", [{}])[-1].get("active_seconds", 0)
        deadline = time.monotonic() + max(0, args.minutes * 60 - active_before) + 180
        while time.monotonic() < deadline:
            if time.monotonic() >= next_sample:
                engine = sample(index)
                if index % 10 == 0:
                    screenshot(f"screen-{index:03}.png")
                index += 1
                next_sample += 60
                if private_file("qa_soak_done.json", check=False).startswith("{"):
                    break
                # Five lifecycle cycles during the late part of a full soak.
                active = engine[-1]["active_seconds"] if engine else 0
                if not args.uninterrupted and args.minutes >= 60 and background_cycles < 5 and active >= 2400 + background_cycles * 120:
                    shell("input keyevent KEYCODE_HOME")
                    time.sleep(30)
                    assert launch(wait_ready=False) == pid, "Process restarted unexpectedly after backgrounding"
                    background_cycles += 1
                    report["background_cycles"] = background_cycles
                    print(f"Background/resume cycle {background_cycles}/5 complete", flush=True)
            time.sleep(1)
        else:
            raise RuntimeError("Timed out before active-game duration completed (screen off or background?)")
        done = json.loads(private_file("qa_soak_done.json"))
        assert done["active_seconds"] >= args.minutes * 60
        screenshot("completed.png")
        shell("input keyevent KEYCODE_HOME")
        time.sleep(1)
        before = saved()
        artifact("save-before-reload.json", json.dumps(before, ensure_ascii=False, indent=2))
        shell(f"am force-stop {PACKAGE}")
        pid = launch()
        time.sleep(2)
        logs(pid)
        shell("input keyevent KEYCODE_HOME")
        time.sleep(1)
        after = saved()
        artifact("save-after-reload.json", json.dumps(after, ensure_ascii=False, indent=2))
        assert before["hired"] == after["hired"] == [5, 2, 2, 1]
        assert before["quests"]["completed"] == after["quests"]["completed"] == [True] * 3
        assert after["revision"] > before["revision"]
        assert after["coins"] >= before["coins"] # Background systems may finish a sale.
        report.update(status="completed", completion=done, cold_reload=True, samples=samples, engine_samples=engine)
        artifact("report.json", json.dumps(report, ensure_ascii=False, indent=2))
        print("Completed: " + str(out / "report.json"), flush=True)
    except BaseException as exc:
        report.update(status="failed", error=repr(exc), samples=samples)
        artifact("report.json", json.dumps(report, ensure_ascii=False, indent=2))
        raise


if __name__ == "__main__":
    main()
