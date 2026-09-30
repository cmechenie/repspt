"""
Reps analyzer: read pose CSV from posetool, detect reps, score form.

Usage: uv run analyze.py <joints.csv> <output_prefix> [--video <path>]
  --video <path>: enables ffmpeg thumbnail extraction of the worst rep per set
"""
import sys
import math
import subprocess
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.signal import find_peaks
import matplotlib.pyplot as plt

# ---------- arg parsing ----------
ap = argparse.ArgumentParser()
ap.add_argument("csv", type=Path, help="joints CSV from posetool")
ap.add_argument("out_prefix", type=str, help="output file prefix (path stem)")
ap.add_argument("--video", type=Path, default=None,
                help="optional source video for thumbnail extraction")
args = ap.parse_args()

csv_path = args.csv
out_prefix = args.out_prefix
video_path = args.video

# ---------- joint name mapping (Vision raw values) ----------
JOINT = {
    "nose":      "head_joint",
    "neck":      "neck_1_joint",
    "lShoulder": "left_shoulder_1_joint",
    "rShoulder": "right_shoulder_1_joint",
    "lElbow":    "left_forearm_joint",
    "rElbow":    "right_forearm_joint",
    "lWrist":    "left_hand_joint",
    "rWrist":    "right_hand_joint",
    "lHip":      "left_upLeg_joint",
    "rHip":      "right_upLeg_joint",
    "lKnee":     "left_leg_joint",
    "rKnee":     "right_leg_joint",
    "lAnkle":    "left_foot_joint",
    "rAnkle":    "right_foot_joint",
    "root":      "root",
}

# ---------- grade thresholds ----------
DEPTH_OK_PX = 0       # hip at or below knee = "good"
DEPTH_AT_PARALLEL_PX = -50   # within 50px above knee = acceptable
DEPTH_SHALLOW_PX = -50       # > 50px above knee = "shallow"
LEAN_BAD_DEG = 50            # torso angle from vertical at bottom
TEMPO_RUSH_S = 0.5
TEMPO_VALID_MIN = 0.4
TEMPO_VALID_MAX = 2.5

# ============================================================
# load + pivot
# ============================================================
df = pd.read_csv(csv_path)
print(f"loaded {len(df):,} joint observations from {csv_path.name}")

wide = df.pivot_table(index=["frame", "time_s"],
                     columns="joint",
                     values=["x", "y", "confidence"],
                     aggfunc="first")
wide.columns = [f"{j}_{m}" for m, j in wide.columns]
wide = wide.reset_index().sort_values("frame").reset_index(drop=True)
print(f"frames: {len(wide):,}, span: {wide.time_s.min():.1f}s -> {wide.time_s.max():.1f}s")

# ---------- pick camera-near side ----------
def avg_conf(joint_key):
    c = f"{JOINT[joint_key]}_confidence"
    return wide[c].mean() if c in wide.columns else 0.0

right_score = avg_conf("rHip") + avg_conf("rKnee") + avg_conf("rAnkle") + avg_conf("rShoulder")
left_score  = avg_conf("lHip") + avg_conf("lKnee") + avg_conf("lAnkle") + avg_conf("lShoulder")
side = "r" if right_score >= left_score else "l"
print(f"camera-near side: {'right' if side == 'r' else 'left'} (score r={right_score:.2f} l={left_score:.2f})")

def col(joint_key, axis):
    return f"{JOINT[joint_key]}_{axis}"

# ============================================================
# clean signals: per-joint short-gap interpolation, then smooth
# ============================================================
# Strategy: interpolate within ~1s (30 frames) to recover joints that
# briefly dropped below confidence threshold (e.g. ankle at squat bottom).
# Larger gaps (rest periods) stay NaN by design.
def clean_series(joint_key, axis, gap_limit=30, smooth_win=7):
    s = wide[col(joint_key, axis)]
    s = s.interpolate(method="linear", limit=gap_limit, limit_direction="both")
    s = s.rolling(smooth_win, center=True, min_periods=1).median()
    s = s.rolling(smooth_win, center=True, min_periods=1).mean()
    return s

hip_y     = clean_series(f"{side}Hip",      "y")
hip_x     = clean_series(f"{side}Hip",      "x")
knee_y    = clean_series(f"{side}Knee",     "y")
knee_x    = clean_series(f"{side}Knee",     "x")
ankle_y   = clean_series(f"{side}Ankle",    "y")
ankle_x   = clean_series(f"{side}Ankle",    "x")
neck_y    = clean_series("neck",            "y")
neck_x    = clean_series("neck",            "x")

t = wide["time_s"].to_numpy()

# coverage report (post-interpolation)
def coverage(s, name):
    pct = 100 * s.notna().mean()
    print(f"  {name:18s} coverage: {pct:5.1f}%")

print("post-clean joint coverage:")
coverage(hip_y,   f"{side}_hip_y")
coverage(knee_y,  f"{side}_knee_y")
coverage(ankle_y, f"{side}_ankle_y")
coverage(neck_y,  "neck_y")

# ============================================================
# rep detection
# ============================================================
hip_y_filled = hip_y.copy().to_numpy()
y_range = float(np.nanmax(hip_y_filled) - np.nanmin(hip_y_filled))

# replace NaN with -inf for find_peaks (so they're never local maxima)
sig_for_peaks = np.where(np.isnan(hip_y_filled), -np.inf, hip_y_filled)

peaks, _ = find_peaks(sig_for_peaks,
                      distance=45,                # >=1.5s between bottoms
                      prominence=0.12 * y_range)
print(f"raw peaks: {len(peaks)}  (y_range={y_range:.0f}px, prominence_min={0.12*y_range:.0f}px)")

# valley search constrained to ±3s window around each peak
WINDOW_FRAMES = 90

def find_valley(start, end, sig):
    seg = sig[start:end]
    if len(seg) == 0 or np.all(np.isnan(seg)):
        return None
    return start + int(np.nanargmin(seg))

reps_raw = []
for p in peaks:
    v_start = find_valley(max(0, p - WINDOW_FRAMES), p, hip_y_filled)
    v_end   = find_valley(p, min(len(hip_y_filled), p + WINDOW_FRAMES), hip_y_filled)
    if v_start is None or v_end is None:
        continue
    ecc_s = float(t[p] - t[v_start])
    con_s = float(t[v_end] - t[p])
    if not (TEMPO_VALID_MIN <= ecc_s <= TEMPO_VALID_MAX):
        continue
    if not (TEMPO_VALID_MIN <= con_s <= TEMPO_VALID_MAX):
        continue
    drop = hip_y_filled[p] - hip_y_filled[v_start]
    if drop < 0.12 * y_range:
        continue
    # reject bend-over false-positives (e.g. picking up/placing dumbbell):
    # the lifter bends sharply forward but knees barely flex.
    # Compute provisional lean and knee_travel to gate out these.
    hy_b = hip_y.iloc[p];   ny_b = neck_y.iloc[p]
    hx_b = hip_x.iloc[p];   nx_b = neck_x.iloc[p]
    kx_b = knee_x.iloc[p];  kx_t = knee_x.iloc[v_start]
    hy_t = hip_y.iloc[v_start]; ky_t = knee_y.iloc[v_start]
    if (pd.notna(hy_b) and pd.notna(ny_b) and pd.notna(hx_b) and pd.notna(nx_b)
            and pd.notna(kx_b) and pd.notna(kx_t)
            and pd.notna(hy_t) and pd.notna(ky_t) and (ky_t - hy_t) > 0):
        prov_lean = math.degrees(math.atan2(abs(hx_b - nx_b), max(hy_b - ny_b, 1e-3)))
        prov_travel = abs(kx_b - kx_t) / (ky_t - hy_t)
        if prov_lean > 45 and prov_travel < 0.30:
            continue  # hip hinge, not a squat
    reps_raw.append({
        "frame_start":  int(wide.frame.iloc[v_start]),
        "frame_bottom": int(wide.frame.iloc[p]),
        "frame_end":    int(wide.frame.iloc[v_end]),
        "t_start":      float(t[v_start]),
        "t_bottom":     float(t[p]),
        "t_end":        float(t[v_end]),
        "idx_bottom":   int(p),
        "idx_start":    int(v_start),
    })

print(f"validated reps (tempo+depth filter): {len(reps_raw)}")

# ============================================================
# set detection (peak-to-peak time gap)
# ============================================================
GAP_THRESHOLD = 8.0
sets = []
current = []
last_bottom = None
for r in reps_raw:
    if last_bottom is not None and (r["t_bottom"] - last_bottom) > GAP_THRESHOLD:
        if current:
            sets.append(current)
            current = []
    current.append(r)
    last_bottom = r["t_bottom"]
if current:
    sets.append(current)

# drop spurious "sets" with <3 reps (detection artifacts at transitions)
real_sets = [s for s in sets if len(s) >= 2]
dropped_set_count = len(sets) - len(real_sets)
sets = real_sets
print(f"sets: {len(sets)}  reps per set: {[len(s) for s in sets]}"
      + (f"  (dropped {dropped_set_count} spurious set(s))" if dropped_set_count else ""))

# ============================================================
# per-rep metrics
# ============================================================
def metrics_at(idx_bottom, idx_start):
    hy = hip_y.iloc[idx_bottom];  ky = knee_y.iloc[idx_bottom]
    ny = neck_y.iloc[idx_bottom]
    hx = hip_x.iloc[idx_bottom];  kx_b = knee_x.iloc[idx_bottom]
    nx = neck_x.iloc[idx_bottom]

    # Use knee_x at top-of-rep as ankle reference (legs are vertical when standing,
    # so knee_x ≈ ankle_x). Knee-forward travel = knee_x_bottom - knee_x_top.
    kx_t = knee_x.iloc[idx_start]
    # Thigh length at top of rep (knee_y_top - hip_y_top) for normalization
    hy_t = hip_y.iloc[idx_start]
    ky_t = knee_y.iloc[idx_start]
    thigh_top = (ky_t - hy_t) if (pd.notna(ky_t) and pd.notna(hy_t) and (ky_t - hy_t) > 0) else np.nan

    below_knee_px = (hy - ky) if (pd.notna(hy) and pd.notna(ky)) else np.nan

    if pd.notna(hy) and pd.notna(ny) and pd.notna(hx) and pd.notna(nx):
        dy = hy - ny
        dx = hx - nx
        torso_lean_deg = math.degrees(math.atan2(abs(dx), max(dy, 1e-3)))
    else:
        torso_lean_deg = np.nan

    # knee forward travel (px); positive value = knees moved forward during descent
    if pd.notna(kx_b) and pd.notna(kx_t):
        knee_travel_px = abs(kx_b - kx_t)
        # normalize by thigh length so it's camera-distance-invariant
        knee_travel_ratio = (knee_travel_px / thigh_top) if pd.notna(thigh_top) else np.nan
    else:
        knee_travel_px = np.nan
        knee_travel_ratio = np.nan

    return dict(below_knee_px=below_knee_px,
                torso_lean_deg=torso_lean_deg,
                knee_travel_px=knee_travel_px,
                knee_travel_ratio=knee_travel_ratio)

# build rep table
rep_rows = []
for set_idx, rep_set in enumerate(sets, start=1):
    for r in rep_set:
        m = metrics_at(r["idx_bottom"], r["idx_start"])
        ecc_s = r["t_bottom"] - r["t_start"]
        con_s = r["t_end"] - r["t_bottom"]
        rep_rows.append({
            "set":             set_idx,
            "rep_in_set":      None,
            "t_bottom":        round(r["t_bottom"], 2),
            "ecc_s":           round(ecc_s, 2),
            "con_s":           round(con_s, 2),
            "below_knee_px":   round(m["below_knee_px"], 1) if pd.notna(m["below_knee_px"]) else np.nan,
            "torso_lean_deg":  round(m["torso_lean_deg"], 1) if pd.notna(m["torso_lean_deg"]) else np.nan,
            "knee_travel":     round(m["knee_travel_ratio"], 2) if pd.notna(m["knee_travel_ratio"]) else np.nan,
            "frame_bottom":    r["frame_bottom"],
        })

rep_df = pd.DataFrame(rep_rows)

# drop reps with NaN primary metrics (incomplete pose)
before = len(rep_df)
rep_df = rep_df.dropna(subset=["below_knee_px", "torso_lean_deg"]).reset_index(drop=True)
dropped = before - len(rep_df)
if dropped:
    print(f"dropped {dropped} reps with incomplete metrics")

# renumber rep_in_set within each set
rep_df["rep_in_set"] = rep_df.groupby("set").cumcount() + 1

# ============================================================
# grade each rep (3-level depth + lean + tempo flags)
# ============================================================
def depth_label(px):
    if pd.isna(px):
        return "unknown"
    if px > DEPTH_OK_PX:
        return "good"          # below parallel
    if px >= DEPTH_AT_PARALLEL_PX:
        return "at_parallel"   # close enough
    return "shallow"           # well above parallel

def grade(row):
    issues = []
    dlabel = depth_label(row["below_knee_px"])
    if dlabel == "shallow":
        issues.append("shallow")
    if row["torso_lean_deg"] > LEAN_BAD_DEG:
        issues.append("forward-lean")
    if row["ecc_s"] < TEMPO_RUSH_S:
        issues.append("rushed-descent")
    return ",".join(issues) if issues else "ok"

rep_df["depth_label"] = rep_df["below_knee_px"].apply(depth_label)
rep_df["grade"] = rep_df.apply(grade, axis=1)

# ============================================================
# per-set summary + worst-rep identification
# ============================================================
def cv(s):
    return s.std() / s.mean() if s.mean() else 0.0

set_rows = []
worst_reps = []  # (set, rep_in_set, frame_bottom, reason)
for set_idx, group in rep_df.groupby("set"):
    n = len(group)
    bad = (group["grade"] != "ok").sum()
    pct_good = 100 * (group["depth_label"] == "good").sum() / n
    pct_atpar = 100 * (group["depth_label"] == "at_parallel").sum() / n
    pct_shallow = 100 * (group["depth_label"] == "shallow").sum() / n
    set_rows.append({
        "set": set_idx,
        "reps": n,
        "%good_depth": round(pct_good, 0),
        "%parallel":   round(pct_atpar, 0),
        "%shallow":    round(pct_shallow, 0),
        "avg_depth_px": round(group["below_knee_px"].mean(), 1),
        "avg_lean_deg": round(group["torso_lean_deg"].mean(), 1),
        "tempo_cv":    round(cv(group["ecc_s"] + group["con_s"]), 2),
        "bad_reps":    int(bad),
    })

    # worst rep: lowest depth (most shallow), or worst lean, whichever is more egregious
    worst = group.copy()
    worst["depth_score"] = (worst["below_knee_px"] - DEPTH_AT_PARALLEL_PX).clip(upper=0).abs()
    worst["lean_score"]  = (worst["torso_lean_deg"] - LEAN_BAD_DEG).clip(lower=0)
    worst["bad_score"]   = worst["depth_score"] + worst["lean_score"] * 5  # weight lean
    if worst["bad_score"].max() > 0:
        w = worst.loc[worst["bad_score"].idxmax()]
        reason_parts = []
        if w["depth_label"] == "shallow":
            reason_parts.append(f"shallow (hip {w['below_knee_px']:.0f}px above knee)")
        if w["torso_lean_deg"] > LEAN_BAD_DEG:
            reason_parts.append(f"lean {w['torso_lean_deg']:.0f}°")
        worst_reps.append({
            "set": set_idx,
            "rep_in_set": int(w["rep_in_set"]),
            "frame_bottom": int(w["frame_bottom"]),
            "t_bottom": float(w["t_bottom"]),
            "reason": "; ".join(reason_parts) or "borderline",
        })

set_df = pd.DataFrame(set_rows)

# ============================================================
# console output
# ============================================================
print("\n=== PER-REP DETAIL ===")
print(rep_df[["set","rep_in_set","t_bottom","ecc_s","con_s",
              "below_knee_px","torso_lean_deg","knee_travel",
              "depth_label","grade"]].to_string(index=False))

print("\n=== PER-SET SUMMARY ===")
print(set_df.to_string(index=False))

# ============================================================
# thumbnail extraction (worst rep per set)
# ============================================================
thumbnails = []
if video_path and worst_reps:
    print("\nextracting worst-rep thumbnails...")
    for w in worst_reps:
        thumb_path = f"{out_prefix}_set{w['set']}_worst.jpg"
        cmd = ["ffmpeg", "-y", "-loglevel", "error",
               "-ss", f"{w['t_bottom']:.2f}",
               "-i", str(video_path),
               "-frames:v", "1",
               "-q:v", "2",
               thumb_path]
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            thumbnails.append({"set": w["set"], "path": thumb_path,
                              "rep": w["rep_in_set"], "reason": w["reason"]})
            print(f"  set {w['set']} rep {w['rep_in_set']}: {thumb_path}")
        except subprocess.CalledProcessError as e:
            print(f"  ffmpeg failed for set {w['set']}: {e}")

# ============================================================
# plot (4 panels with 3-tier color coding)
# ============================================================
def color_for(row):
    if row["grade"] == "ok":
        return "tab:green"
    if "shallow" in row["grade"] and row["below_knee_px"] < -100:
        return "tab:red"
    return "tab:orange"

if not rep_df.empty:
    rep_df["plot_color"] = rep_df.apply(color_for, axis=1)

fig, axes = plt.subplots(4, 1, figsize=(14, 11), sharex=True)

# panel 1: hip y signal with rep markers + set bands
axes[0].plot(t, hip_y_filled, "b-", linewidth=0.8, label="hip y (smoothed)")
if peaks.size:
    axes[0].plot(t[peaks], hip_y_filled[peaks], "k.", markersize=4, alpha=0.4, label="raw peaks")
if not rep_df.empty:
    axes[0].scatter(rep_df["t_bottom"],
                   [hip_y_filled[wide.index[wide.frame == fb][0]] for fb in rep_df["frame_bottom"]],
                   c=rep_df["plot_color"], s=40, marker="v", edgecolors="black", linewidths=0.5,
                   label="validated rep")
band_colors = ["#cce5ff","#ffe0b3","#ccffcc","#ffcccc","#e0ccff"]
for i, s in enumerate(sets):
    axes[0].axvspan(s[0]["t_start"], s[-1]["t_end"], alpha=0.4,
                   color=band_colors[i % len(band_colors)])
    axes[0].text((s[0]["t_start"] + s[-1]["t_end"]) / 2,
                np.nanmin(hip_y_filled) - 20,
                f"Set {i+1}\n({len(s)} reps)",
                ha="center", fontsize=9)
axes[0].invert_yaxis()
axes[0].set_ylabel("hip y position (px)\n(higher in plot = lower in frame)")
axes[0].legend(loc="upper right", fontsize=8)
axes[0].set_title(f"Reps analyzer — {csv_path.name}")

# panel 2: depth bars
if not rep_df.empty:
    axes[1].bar(rep_df["t_bottom"], rep_df["below_knee_px"],
               width=1.0, color=rep_df["plot_color"])
    axes[1].axhline(DEPTH_OK_PX, color="green", linewidth=0.6, linestyle="--", label=f"parallel ({DEPTH_OK_PX})")
    axes[1].axhline(DEPTH_SHALLOW_PX, color="red", linewidth=0.6, linestyle="--", label=f"shallow cutoff ({DEPTH_SHALLOW_PX})")
    axes[1].set_ylabel("hip vs knee (px)\n(positive = below parallel)")
    axes[1].legend(loc="lower left", fontsize=8)

# panel 3: torso lean
if not rep_df.empty:
    axes[2].bar(rep_df["t_bottom"], rep_df["torso_lean_deg"],
               width=1.0, color=rep_df["plot_color"])
    axes[2].axhline(LEAN_BAD_DEG, color="red", linewidth=0.6, linestyle="--", label=f"lean cutoff ({LEAN_BAD_DEG}°)")
    axes[2].set_ylabel("torso lean at bottom (°)")
    axes[2].legend(loc="upper left", fontsize=8)

# panel 4: tempo (ecc + con)
if not rep_df.empty:
    axes[3].bar(rep_df["t_bottom"], rep_df["ecc_s"], width=0.8,
               color="tab:cyan", label="eccentric (s)")
    axes[3].bar(rep_df["t_bottom"], rep_df["con_s"], width=0.8,
               bottom=rep_df["ecc_s"], color="tab:purple", label="concentric (s)")
    axes[3].set_ylabel("rep duration (s)")
    axes[3].set_xlabel("time (s)")
    axes[3].legend(loc="upper left", fontsize=8)

plt.tight_layout()
plot_path = f"{out_prefix}_analysis.png"
plt.savefig(plot_path, dpi=110)
print(f"\nplot saved: {plot_path}")

# save detailed CSV
detail_path = f"{out_prefix}_reps.csv"
rep_df.drop(columns=["plot_color"], errors="ignore").to_csv(detail_path, index=False)
print(f"per-rep CSV: {detail_path}")

# ============================================================
# markdown report
# ============================================================
report_path = f"{out_prefix}_report.md"
lines = []
lines.append(f"# Reps session report — `{csv_path.name}`\n")
lines.append(f"- Source video span: **{wide.time_s.min():.1f}s → {wide.time_s.max():.1f}s** ({(wide.time_s.max()-wide.time_s.min())/60:.1f} min)")
lines.append(f"- Camera-near side detected: **{'right' if side == 'r' else 'left'}**")
lines.append(f"- Total reps detected: **{len(rep_df)}**, in **{len(sets)} set(s)**\n")
lines.append("## Per-set summary\n")
lines.append(set_df.to_markdown(index=False) if hasattr(set_df, "to_markdown") else set_df.to_string(index=False))
lines.append("")
lines.append("## Worst rep per set\n")
if worst_reps:
    for w in worst_reps:
        lines.append(f"- **Set {w['set']}, rep {w['rep_in_set']}** at t={w['t_bottom']:.1f}s — {w['reason']}")
else:
    lines.append("_no flagged reps_")
lines.append("")
if thumbnails:
    lines.append("## Worst-rep thumbnails\n")
    for th in thumbnails:
        rel = Path(th["path"]).name
        lines.append(f"### Set {th['set']}\n![worst rep set {th['set']}]({rel})\n\n_{th['reason']}_\n")
lines.append("\n## Coaching cues\n")
# generate prioritized cues based on worst issues across the session
issue_counts = {}
for g in rep_df["grade"]:
    if g == "ok":
        continue
    for tag in g.split(","):
        issue_counts[tag] = issue_counts.get(tag, 0) + 1
if issue_counts:
    sorted_issues = sorted(issue_counts.items(), key=lambda x: -x[1])
    cue_map = {
        "shallow":         "**Drive deeper.** Sit straight down between the heels until the hip crease passes below the kneecap. Common cause: tight ankles or hesitation; cue 'knees out, butt back, sit between the legs.'",
        "forward-lean":    "**Stay tall.** Torso is collapsing forward at the bottom. Cue 'chest up, dumbbell into the ribs.' If the lean appears only late in the set, it's quad fatigue — drop the load or shorten the set.",
        "rushed-descent":  "**Slow the descent.** Take 1.5–2.0 seconds on the way down to control the bottom. Cue 'lower with intent.'",
    }
    for tag, count in sorted_issues:
        lines.append(f"- ({count}× this session) {cue_map.get(tag, tag)}")
else:
    lines.append("- No systematic issues detected.")
lines.append("")
with open(report_path, "w") as f:
    f.write("\n".join(lines))
print(f"report:    {report_path}")
