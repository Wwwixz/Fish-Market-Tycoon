"""Summarize an android_soak.py report without treating missing metrics as passes."""

import argparse
import json
from pathlib import Path
import statistics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    engine = report.get("engine_samples", [])
    device = report.get("samples", [])
    assert engine, "No engine frames have been measured"

    def bounds(values):
        values = [value for value in values if value is not None]
        return {"min": min(values), "max": max(values)} if values else None

    def fps(rows):
        return sum(row["frames"] for row in rows) / sum(row["window_seconds"] for row in rows) if rows else None

    warmed = [row for row in engine if row["active_seconds"] - row["window_seconds"] >= 600]
    late = [row for row in engine if row["active_seconds"] - row["window_seconds"] >= 3000]
    early = [row for row in warmed if row["active_seconds"] <= 1201]
    memory = [row for row in device if row["elapsed_seconds"] > 600 and row.get("pss_kib") is not None]
    slope = statistics.linear_regression([row["elapsed_seconds"] / 60 for row in memory],
                                        [row["pss_kib"] / 1024 for row in memory]).slope if len(memory) > 2 else None
    sensor_names = sorted({name for row in device for name in row.get("thermal_sensors_c", {})})
    debug_monitors = any(row.get("debug_build", True) for row in engine)
    summary = {
        "status": report["status"], "device": report["device"], "build_type": report["build_type"],
        "active_minutes": engine[-1]["active_seconds"] / 60, "engine_windows": len(engine),
        "fps_all": fps(engine), "fps_after_10min": fps(warmed), "fps_minutes_10_to_20": fps(early),
        "fps_after_50min": fps(late), "minute_fps_range": bounds([row["fps"] for row in engine]),
        "minute_p95_ms_range": bounds([row["frame_p95_ms"] for row in engine]),
        "minute_p99_ms_range": bounds([row["frame_p99_ms"] for row in engine]),
        "slow_frame_fraction": sum(row["slow_frame_fraction"] * row["frames"] for row in engine) / sum(row["frames"] for row in engine),
        "pss_mib_range": bounds([row["pss_kib"] / 1024 if row.get("pss_kib") is not None else None for row in device]),
        "rss_mib_range": bounds([row["rss_kib"] / 1024 if row.get("rss_kib") is not None else None for row in device]),
        "pss_mib_per_minute_after_10min": slope,
        "engine_static_mib_range": bounds([row["engine_static_bytes"] / 1048576 for row in engine]) if debug_monitors else None,
        "orphan_range": bounds([row["orphans"] for row in engine]) if debug_monitors else None,
        "release_engine_verified": all(row.get("debug_build") is False for row in engine),
        "render_scale": bounds([row.get("render_scale", 1.0) for row in engine]),
        "draw_calls_range": bounds([row["draw_calls"] for row in engine]),
        "thermal_status_range": bounds([row.get("thermal_status") for row in device]),
        "thermal_sensors_c": {name: bounds([row.get("thermal_sensors_c", {}).get(name) for row in device]) for name in sensor_names},
        "battery_c_range": bounds([row.get("battery_c") for row in device]),
        "ui_actions": engine[-1]["cycles"], "background_cycles": report.get("background_cycles", 0),
        "cold_reload": report.get("cold_reload", False),
        "unplanned_interruptions": len(report.get("interruptions", [])),
        "limitations": report.get("limitations", []) + ["p95/p99 are ranges of per-minute percentiles, not global frame percentiles",
                                                       "memory trend alone does not establish a leak"]
    }
    args.report.with_name("summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return
    figure, axes = plt.subplots(4, 1, figsize=(10, 11))
    axes[1].sharex(axes[0])
    axes[3].sharex(axes[2])
    axes[0].tick_params(labelbottom=False)
    axes[2].tick_params(labelbottom=False)
    minutes = [row["active_seconds"] / 60 for row in engine]
    axes[0].plot(minutes, [row["fps"] for row in engine], label="Engine FPS")
    axes[0].axhline(30, color="gray", linestyle="--", label="30 FPS target")
    axes[0].set_ylabel("FPS")
    axes[1].plot(minutes, [row["frame_p95_ms"] for row in engine], label="Minute p95")
    axes[1].plot(minutes, [row["frame_p99_ms"] for row in engine], label="Minute p99", alpha=.7)
    axes[1].set_ylabel("Frame interval (ms)")
    axes[1].set_xlabel("Active gameplay minutes (background excluded)")
    device_minutes = [row["elapsed_seconds"] / 60 for row in device]
    for metric in ("pss_kib", "rss_kib"):
        axes[2].plot(device_minutes, [row.get(metric, 0) / 1024 if row.get(metric) is not None else float("nan") for row in device], label=metric[:3].upper())
    axes[2].set_ylabel("Process memory (MiB)")
    for sensor in ("CPU", "GPU", "SKIN", "BATTERY"):
        if sensor in sensor_names:
            axes[3].plot(device_minutes, [row.get("thermal_sensors_c", {}).get(sensor, float("nan")) for row in device], label=sensor, alpha=.8)
    axes[3].set_ylabel("Sensor temperature (C)")
    axes[3].set_xlabel("Wall-clock minutes (includes interruptions and background)")
    for axis in axes:
        axis.grid(alpha=.2)
        axis.legend(loc="upper right", fontsize=8)
    figure.suptitle(f"{report['device']} | {report['build_type']} | {report['status']}")
    figure.tight_layout()
    figure.savefig(args.report.with_name("metrics.png"), dpi=160)


if __name__ == "__main__":
    main()
