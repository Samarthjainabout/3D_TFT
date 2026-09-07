"""Run the FeTFT DRAM-like dynamic-cell equations without MATLAB/Simulink.

This is a lightweight numerical companion to build_fetft_dynamic_cell_model.m.
It evaluates the same default WRITE-HOLD-READ equations and writes CSV/PNG
outputs that can be compared with the later Simulink run.

NLS/detrapping retention mechanism adapted from:
F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure
FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model,"
IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022,
doi: 10.1109/JEDS.2022.3142046.
"""

from __future__ import annotations

import csv
import math
from pathlib import Path


OUT_DIR = Path(__file__).resolve().parent
CSV_FILE = OUT_DIR / "fetft_dynamic_cell_equation_results.csv"
PNG_FILE = OUT_DIR / "fetft_dynamic_cell_equation_response.png"
SVG_FILE = OUT_DIR / "fetft_dynamic_cell_equation_response.svg"


PARAMS = {
    "t_write": 2e-6,
    "t_read_start": 22e-6,
    "t_stop": 40e-6,
    "dt": 5e-8,
    "dP0": 1.0,
    "tau_write": 0.35e-6,
    "tau_nls": 11e-6,
    "beta_retention": 0.62,
    "trap_accel": 0.18,
    "tau_trap": 25e-6,
    "p_eq": 0.0,
    "a_write": 0.25,
    "a_hold": 0.35,
    "a_read": 0.88,
    "b_write": 0.12,
    "b_hold": 0.08,
    "b_read": 0.12,
    "v_min": 0.12,
    "kappa": 0.35,
    "gm_proxy": 1.0,
    "gP_proxy": 0.20,
}


def sample(t: float) -> dict[str, float]:
    p = PARAMS
    dP_write_end = p["dP0"] * (1.0 - math.exp(-p["t_write"] / p["tau_write"]))

    if t < p["t_write"]:
        phase = 1.0
        dP = p["dP0"] * (1.0 - math.exp(-t / p["tau_write"]))
        a = p["a_write"]
        b = p["b_write"]
    elif t < p["t_read_start"]:
        phase = 2.0
        t_hold = t - p["t_write"]
        dP = dP_write_end * retention_factor(t_hold)
        a = p["a_hold"]
        b = p["b_hold"]
    else:
        phase = 3.0
        t_hold = t - p["t_write"]
        dP = dP_write_end * retention_factor(t_hold)
        a = p["a_read"]
        b = p["b_read"]

    if a >= 1.0:
        a = 0.999999

    p17 = p["p_eq"] + 0.5 * dP
    p18 = p["p_eq"] - 0.5 * dP
    polarization_gain = b / (1.0 - a)
    dVQ = polarization_gain * dP
    sense_margin = abs(dVQ) - p["v_min"]
    vt_shift = p["kappa"] * dP
    id_proxy = p["gm_proxy"] * dVQ + p["gP_proxy"] * dP

    return {
        "time_s": t,
        "phase": phase,
        "dP": dP,
        "p17": p17,
        "p18": p18,
        "dVQ_V": dVQ,
        "loop_gain": a,
        "polarization_gain": polarization_gain,
        "sense_margin_V": sense_margin,
        "vt_shift_V": vt_shift,
        "id_proxy": id_proxy,
        "refresh_needed": 1.0 if sense_margin < 0.0 else 0.0,
    }


def retention_estimate() -> float:
    p = PARAMS
    dP_write_end = p["dP0"] * (1.0 - math.exp(-p["t_write"] / p["tau_write"]))
    g_read = p["b_read"] / (1.0 - p["a_read"])
    if g_read * abs(dP_write_end) <= p["v_min"]:
        return 0.0
    lo = 0.0
    hi = max(p["tau_nls"], p["t_stop"] - p["t_write"])
    while g_read * abs(dP_write_end) * retention_factor(hi) > p["v_min"]:
        hi *= 2.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if g_read * abs(dP_write_end) * retention_factor(mid) > p["v_min"]:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def retention_factor(t_hold: float) -> float:
    """Effective NLS depolarization/back-switching retention factor."""
    p = PARAMS
    if t_hold <= 0.0:
        return 1.0
    trap_multiplier = 1.0 + p["trap_accel"] * (1.0 - math.exp(-t_hold / p["tau_trap"]))
    return math.exp(-trap_multiplier * (t_hold / p["tau_nls"]) ** p["beta_retention"])


def write_csv(rows: list[dict[str, float]]) -> None:
    with CSV_FILE.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_plot(rows: list[dict[str, float]]) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        write_svg_plot(rows)
        print("matplotlib is not available; wrote SVG plot instead.")
        return

    time_us = [row["time_s"] * 1e6 for row in rows]
    dP = [row["dP"] for row in rows]
    dVQ = [row["dVQ_V"] for row in rows]
    margin = [row["sense_margin_V"] for row in rows]
    phase = [0.05 * row["phase"] for row in rows]

    fig, axes = plt.subplots(3, 1, figsize=(8, 6), sharex=True)
    axes[0].plot(time_us, dP, linewidth=1.6)
    axes[0].set_ylabel("dP norm.")
    axes[0].set_title("FeTFT dynamic-cell equation response")
    axes[0].grid(True)

    axes[1].plot(time_us, dVQ, linewidth=1.6)
    axes[1].set_ylabel("dVQ (V)")
    axes[1].grid(True)

    axes[2].plot(time_us, margin, linewidth=1.6, label="sense margin")
    axes[2].step(time_us, phase, where="post", linestyle=":", label="phase marker")
    axes[2].set_xlabel("time (us)")
    axes[2].set_ylabel("margin (V)")
    axes[2].grid(True)
    axes[2].legend(loc="best")

    fig.tight_layout()
    fig.savefig(PNG_FILE, dpi=160)
    plt.close(fig)


def main() -> None:
    p = PARAMS
    n_steps = int(round(p["t_stop"] / p["dt"]))
    rows = [sample(i * p["dt"]) for i in range(n_steps + 1)]

    write_csv(rows)
    write_plot(rows)

    checkpoints = [0.0, p["t_write"], p["t_read_start"], p["t_stop"]]
    print("FeTFT dynamic-cell equation run")
    for t in checkpoints:
        row = sample(t)
        print(
            f"t={t * 1e6:6.2f} us "
            f"phase={row['phase']:.0f} "
            f"dP={row['dP']:.6f} "
            f"dVQ={row['dVQ_V']:.6f} V "
            f"margin={row['sense_margin_V']:.6f} V"
        )
    print(f"retention_estimate_from_write_end={retention_estimate() * 1e6:.3f} us")
    print(f"wrote {CSV_FILE}")
    if PNG_FILE.exists():
        print(f"wrote {PNG_FILE}")
    if SVG_FILE.exists():
        print(f"wrote {SVG_FILE}")


def write_svg_plot(rows: list[dict[str, float]]) -> None:
    width = 900
    height = 620
    left = 80
    right = 30
    top = 45
    panel_h = 155
    gap = 35
    plot_w = width - left - right

    time_us = [row["time_s"] * 1e6 for row in rows]
    series = [
        ("dP norm.", [row["dP"] for row in rows], "#1f77b4"),
        ("dVQ (V)", [row["dVQ_V"] for row in rows], "#2ca02c"),
        ("margin (V)", [row["sense_margin_V"] for row in rows], "#d62728"),
    ]
    x_min = min(time_us)
    x_max = max(time_us)

    def points(values: list[float], panel_idx: int) -> str:
        y_min = min(values)
        y_max = max(values)
        pad = max((y_max - y_min) * 0.08, 1e-9)
        y_min -= pad
        y_max += pad
        y0 = top + panel_idx * (panel_h + gap)
        coords = []
        for x, y in zip(time_us, values):
            sx = left + (x - x_min) / (x_max - x_min) * plot_w
            sy = y0 + panel_h - (y - y_min) / (y_max - y_min) * panel_h
            coords.append(f"{sx:.2f},{sy:.2f}")
        return " ".join(coords)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="80" y="26" font-family="Arial" font-size="18" font-weight="700">FeTFT dynamic-cell equation response</text>',
    ]

    for i, (label, values, color) in enumerate(series):
        y = top + i * (panel_h + gap)
        parts.append(f'<rect x="{left}" y="{y}" width="{plot_w}" height="{panel_h}" fill="none" stroke="#cccccc"/>')
        for frac in (0.25, 0.5, 0.75):
            gy = y + panel_h * frac
            parts.append(f'<line x1="{left}" y1="{gy:.2f}" x2="{left + plot_w}" y2="{gy:.2f}" stroke="#eeeeee"/>')
        parts.append(f'<polyline fill="none" stroke="{color}" stroke-width="2" points="{points(values, i)}"/>')
        parts.append(f'<text x="18" y="{y + panel_h / 2:.2f}" font-family="Arial" font-size="13">{label}</text>')

    x_axis_y = top + 2 * (panel_h + gap) + panel_h + 30
    parts.append(f'<text x="{left + plot_w / 2 - 35:.2f}" y="{x_axis_y}" font-family="Arial" font-size="13">time (us)</text>')
    parts.append("</svg>")
    SVG_FILE.write_text("\n".join(parts), encoding="utf-8")


if __name__ == "__main__":
    main()
