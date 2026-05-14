#!/usr/bin/env python3
"""
slice_card_sheet.py

Slice the designer's card sprite sheet (`poker cards@4x 1.png`) into 52 individual
card PNG files matching Session 17's expected asset naming scheme.

Expected input:
  /path/to/Final assets - V2/Vector illustrations/Card Decks/poker cards@4x 1.png
  /path/to/Final assets - V2/Vector illustrations/Card Decks/Card back.png

Output: 53 PNGs named per Session 17's `AssetNames` convention:
  card_hearts_ace.png   card_hearts_2.png   ... card_hearts_king.png
  card_clubs_ace.png    card_clubs_2.png    ... card_clubs_king.png
  card_diamonds_ace.png card_diamonds_2.png ... card_diamonds_king.png
  card_spades_ace.png   card_spades_2.png   ... card_spades_king.png
  card_back.png

Sprite sheet layout (verified empirically):
  - 8 columns × 7 rows = 56 grid slots
  - 52 used, 4 unused (1 joker, 3 blank)
  - Column pairs: (1,2)=hearts (3,4)=clubs (5,6)=diamonds (7,8)=spades
  - Even cols = lower ranks; odd cols = higher ranks
  - One KNOWN BUG in source: 2 of Diamonds is missing (duplicated A♦ in its slot)

Bounds derivation (Session 23 + 24):
  Session 23 derived uniform-pitch grid bounds from the sheet by scanning the
  alpha channel for opaque column/row runs and fitting a uniform spacing model.
  Session 24 keeps that uniform grid only as a *search region* — per-card tight
  bounding boxes are then detected inside each grid cell's margin-expanded
  region via PIL's alpha-based getbbox(). Each tight crop is finally padded to
  a single uniform output canvas (the max tight-bbox width/height across all
  cards), with the art centered and transparent margins added.

  Result: every output PNG is dimensionally identical AND each contains the
  full card art with consistent transparent padding regardless of small
  positional variances in the source sheet's grid cells.

  Pass --debug to print derived grid bounds, per-card detected bboxes, and
  per-card deltas vs the uniform nominal.

Run from anywhere:
  python3 slice_card_sheet.py \\
    --input "/path/to/poker cards@4x 1.png" \\
    --back  "/path/to/Card back.png" \\
    --output "/path/to/repo/App/Assets.xcassets/Cards" \\
    [--debug]

The output directory must exist (Session 17 created the empty imagesets).
The script writes each PNG INSIDE its corresponding .imageset subfolder.
"""

import argparse
import os
import sys
from pathlib import Path
from statistics import median
from typing import Optional

try:
    from PIL import Image
except ImportError:
    print("ERROR: PIL/Pillow not installed. Run: pip3 install Pillow", file=sys.stderr)
    sys.exit(1)


# Grid dimensions (8 columns × 7 rows, see LAYOUT below).
GRID_COLS = 8
GRID_ROWS = 7

# Pre-Session-23 hardcoded bounds — kept only for --debug residual comparison.
# The slicer no longer uses these at runtime; bounds are derived from alpha.
LEGACY_COL_BOUNDS = [
    (1, 123), (127, 250), (254, 376), (382, 504),
    (509, 631), (635, 757), (760, 883), (886, 1008),
]
LEGACY_ROW_BOUNDS = [
    (2, 173), (178, 349), (354, 525), (530, 701),
    (706, 877), (881, 1053), (1058, 1229),
]

# --- Layout: which suit/rank is at each (row, col) ---
# Row 1: A H, 8 H, A C, 8 C, A D, 8 D, A S, 8 S
# Row 2: 2 H, 9 H, 2 C, 9 C, [2 D MISSING — sheet shows duplicate A D here], 9 D, 2 S, 9 S
# Row 3: 3 H, 10 H, 3 C, 10 C, 2 D, 10 D, 3 S, 10 S  ← WAIT this contradicts row 2
# Actually re-reading: row 3 col 5 is "2 D" because designer shifted diamonds down by 1
# row in cols 5-6 to make room for the (incorrect) duplicate at row 2 col 5.
#
# The CORRECTED layout assumes designer intended:
#   Row 1 col 5 = A D
#   Row 2 col 5 = 2 D  (currently shows A D — BUG)
#   Row 3 col 5 = 3 D
#   ...
# but the sheet actually has:
#   Row 1 col 5 = A D
#   Row 2 col 5 = A D (duplicate — BUG)
#   Row 3 col 5 = 2 D
#   Row 4 col 5 = 3 D
#   Row 5 col 5 = 4 D
#   Row 6 col 5 = 5 D
#   Row 7 col 5 = 6 D
# So diamonds low-ranks are SHIFTED DOWN by one row in cols 5,6.
#
# Suit higher-ranks (cols 2,4,6,8) match across all four suits row-by-row:
#   Row 1 = rank 8
#   Row 2 = rank 9
#   Row 3 = rank 10
#   Row 4 = rank K
#   Row 5 = rank Q
#   Row 6 = rank J
#   Row 7 = unused (col 2 = joker, col 4/6/8 = blank)
#
# So we have all the high-rank diamonds intact (8 D, 9 D, 10 D, K D, Q D, J D).
# The missing card is 7 of Diamonds, which would have been at the (nonexistent)
# row 8 col 5 because diamonds were shifted down.

LAYOUT = {
    # (row, col): (suit, rank) — 1-indexed
    # Hearts low (col 1): A, 2, 3, 4, 5, 6, 7
    (1, 1): ("hearts", "ace"),
    (2, 1): ("hearts", "2"),
    (3, 1): ("hearts", "3"),
    (4, 1): ("hearts", "4"),
    (5, 1): ("hearts", "5"),
    (6, 1): ("hearts", "6"),
    (7, 1): ("hearts", "7"),
    # Hearts high (col 2): 8, 9, 10, K, Q, J, [joker — skip]
    (1, 2): ("hearts", "8"),
    (2, 2): ("hearts", "9"),
    (3, 2): ("hearts", "10"),
    (4, 2): ("hearts", "king"),
    (5, 2): ("hearts", "queen"),
    (6, 2): ("hearts", "jack"),
    # (7, 2) = joker — SKIPPED

    # Clubs low (col 3): A, 2, 3, 4, 5, 6, 7
    (1, 3): ("clubs", "ace"),
    (2, 3): ("clubs", "2"),
    (3, 3): ("clubs", "3"),
    (4, 3): ("clubs", "4"),
    (5, 3): ("clubs", "5"),
    (6, 3): ("clubs", "6"),
    (7, 3): ("clubs", "7"),
    # Clubs high (col 4): 8, 9, 10, K, Q, J, [blank — skip]
    (1, 4): ("clubs", "8"),
    (2, 4): ("clubs", "9"),
    (3, 4): ("clubs", "10"),
    (4, 4): ("clubs", "king"),
    (5, 4): ("clubs", "queen"),
    (6, 4): ("clubs", "jack"),

    # Diamonds low (cols 5) — SHIFTED DOWN by 1 row due to designer error
    # Row 1 col 5 = A D (correct)
    # Row 2 col 5 = A D (DUPLICATE — designer error)
    # Row 3 col 5 = 2 D, Row 4 = 3 D, Row 5 = 4 D, Row 6 = 5 D, Row 7 = 6 D
    # Result: 7 of Diamonds is MISSING from sheet entirely
    (1, 5): ("diamonds", "ace"),
    # (2, 5) SKIPPED — duplicate ace of diamonds
    (3, 5): ("diamonds", "2"),
    (4, 5): ("diamonds", "3"),
    (5, 5): ("diamonds", "4"),
    (6, 5): ("diamonds", "5"),
    (7, 5): ("diamonds", "6"),
    # Diamonds high (col 6): 8, 9, 10, K, Q, J, [blank — skip]
    (1, 6): ("diamonds", "8"),
    (2, 6): ("diamonds", "9"),
    (3, 6): ("diamonds", "10"),
    (4, 6): ("diamonds", "king"),
    (5, 6): ("diamonds", "queen"),
    (6, 6): ("diamonds", "jack"),

    # Spades low (col 7): A, 2, 3, 4, 5, 6, 7
    (1, 7): ("spades", "ace"),
    (2, 7): ("spades", "2"),
    (3, 7): ("spades", "3"),
    (4, 7): ("spades", "4"),
    (5, 7): ("spades", "5"),
    (6, 7): ("spades", "6"),
    (7, 7): ("spades", "7"),
    # Spades high (col 8): 8, 9, 10, K, Q, J, [blank — skip]
    (1, 8): ("spades", "8"),
    (2, 8): ("spades", "9"),
    (3, 8): ("spades", "10"),
    (4, 8): ("spades", "king"),
    (5, 8): ("spades", "queen"),
    (6, 8): ("spades", "jack"),
}

# Expected output: 52 unique cards. Verify we have all of them.
EXPECTED_CARDS = set()
for suit in ("hearts", "clubs", "diamonds", "spades"):
    for rank in ("ace", "2", "3", "4", "5", "6", "7", "8", "9", "10",
                 "jack", "queen", "king"):
        EXPECTED_CARDS.add((suit, rank))

CARDS_IN_LAYOUT = set(LAYOUT.values())
MISSING_CARDS = EXPECTED_CARDS - CARDS_IN_LAYOUT


def _detect_opaque_flags(sheet: Image.Image) -> tuple[list[bool], list[bool]]:
    """Return (col_has_opaque, row_has_opaque) flag lists.

    A column or row is flagged True if it contains any pixel with alpha > 0.
    """
    rgba = sheet.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    col_flag = [False] * w
    row_flag = [False] * h
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                col_flag[x] = True
                row_flag[y] = True
    return col_flag, row_flag


def _runs(flags: list[bool]) -> list[tuple[int, int]]:
    """Return inclusive (start, end) runs of consecutive True values."""
    out = []
    in_run = False
    start = 0
    for i, v in enumerate(flags):
        if v and not in_run:
            in_run = True
            start = i
        elif not v and in_run:
            in_run = False
            out.append((start, i - 1))
    if in_run:
        out.append((start, len(flags) - 1))
    return out


def _fit_axis_bounds(
    detected_runs: list[tuple[int, int]],
    expected_n: int,
    label: str,
) -> tuple[list[tuple[int, int]], int, float, float, float]:
    """Fit a uniform spacing model over detected opaque runs.

    Some runs may be "fused" (two adjacent cards with no transparent gap between
    them at the alpha-channel level). Fused runs are detected as having width
    significantly larger than the median single-run width; their centers are
    not used for the fit, but their grid positions are still counted so the fit
    indices stay aligned.

    Returns (bounds, card_size, gap_size, first_center, pitch) where:
      - bounds is a list of expected_n (left, right) tuples for PIL.Image.crop
        (right exclusive)
      - card_size is the uniform width/height (px, integer)
      - gap_size = pitch - card_size (px, float — may be fractional)
      - first_center is the fitted center of grid position 0 (px, float)
      - pitch is the fitted spacing between adjacent card centers (px, float)
    """
    widths = [e - s + 1 for s, e in detected_runs]
    if not widths:
        raise RuntimeError(f"no opaque {label} runs detected — sheet alpha empty?")
    med_w = median(widths)
    # Identify fused runs by inflated width.
    clean_pairs: list[tuple[int, float]] = []
    grid_idx = 0
    single_widths: list[int] = []
    for s, e in detected_runs:
        run_w = e - s + 1
        n_cards = max(1, round(run_w / med_w))
        if n_cards == 1:
            clean_pairs.append((grid_idx, (s + e) / 2.0))
            single_widths.append(run_w)
            grid_idx += 1
        else:
            grid_idx += n_cards  # skip past fused cards without using their centers
    if grid_idx != expected_n:
        raise RuntimeError(
            f"{label}: detected {grid_idx} card slots (with fused-split), expected {expected_n}. "
            f"Runs: {detected_runs}"
        )
    if len(clean_pairs) < 2:
        raise RuntimeError(f"{label}: too few clean runs for fit ({len(clean_pairs)})")
    # Linear least-squares: center = first_center + grid_idx * pitch
    n = len(clean_pairs)
    xs = [p[0] for p in clean_pairs]
    ys = [p[1] for p in clean_pairs]
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((xs[i] - mx) * (ys[i] - my) for i in range(n))
    den = sum((xs[i] - mx) ** 2 for i in range(n))
    if den == 0:
        raise RuntimeError(f"{label}: degenerate fit (all clean centers at one index)")
    pitch = num / den
    first_center = my - pitch * mx
    card_size = int(round(median(single_widths)))
    gap_size = pitch - card_size
    bounds: list[tuple[int, int]] = []
    for i in range(expected_n):
        ci = first_center + i * pitch
        lo = int(round(ci - card_size / 2.0))
        hi = lo + card_size
        bounds.append((lo, hi))
    return bounds, card_size, gap_size, first_center, pitch


def derive_uniform_bounds(
    sheet: Image.Image,
) -> tuple[list[tuple[int, int]], list[tuple[int, int]], dict]:
    """Derive uniform COL_BOUNDS and ROW_BOUNDS for the given sheet.

    Returns (col_bounds, row_bounds, debug_info_dict).
    """
    col_flag, row_flag = _detect_opaque_flags(sheet)
    col_runs = _runs(col_flag)
    row_runs = _runs(row_flag)
    col_bounds, card_w, gap_w, c0_c, pitch_c = _fit_axis_bounds(col_runs, GRID_COLS, "col")
    row_bounds, card_h, gap_h, c0_r, pitch_r = _fit_axis_bounds(row_runs, GRID_ROWS, "row")
    debug = {
        "sheet_size": sheet.size,
        "col_runs_detected": col_runs,
        "row_runs_detected": row_runs,
        "card_width": card_w,
        "card_height": card_h,
        "column_gap": gap_w,
        "row_gap": gap_h,
        "col_pitch": pitch_c,
        "row_pitch": pitch_r,
        "col_first_center": c0_c,
        "row_first_center": c0_r,
    }
    return col_bounds, row_bounds, debug


# --- Session 24: per-card tight-bbox detection + uniform-canvas padding ---

# Margin (px) added around each uniform grid cell when searching for the card's
# tight bbox. Kept small because the inter-card gap on the source sheet is
# only ~1-2 px (row 6/7 even fused into a single alpha run in Session 23's
# scan), so any margin > the inter-card gap would let neighboring card art
# bleed into the search region and inflate the detected bbox. With margin=0
# the search region is exactly the Session-23 uniform cell, and PIL's
# getbbox() returns the card's tight opaque extent within that cell — which
# is precisely what we want: the per-card shift within identical-size cells
# is captured by the bbox center, not by its size.
BBOX_SEARCH_MARGIN = 0

# Sanity threshold: a detected bbox whose width or height differs from the
# uniform-pitch card_width/card_height by more than this fraction is treated
# as a likely detection failure and aborts the run.
BBOX_SANITY_FRACTION = 0.5


def detect_card_bbox(
    sheet: Image.Image,
    row_idx: int,
    col_idx: int,
    col_bounds: list[tuple[int, int]],
    row_bounds: list[tuple[int, int]],
    margin: int = BBOX_SEARCH_MARGIN,
) -> Optional[tuple[int, int, int, int]]:
    """Return the tight (left, top, right, bottom) bbox in sheet coordinates
    of the opaque card art at uniform grid cell (row_idx, col_idx) (1-indexed),
    or None if the cell is empty.

    The search is confined to a region expanded by `margin` on all sides of
    the uniform grid cell, so neighboring cards can't contaminate the bbox.
    """
    cs, ce = col_bounds[col_idx - 1]
    rs, re = row_bounds[row_idx - 1]
    sheet_w, sheet_h = sheet.size
    search_x0 = max(0, cs - margin)
    search_y0 = max(0, rs - margin)
    search_x1 = min(sheet_w, ce + margin)
    search_y1 = min(sheet_h, re + margin)
    region = sheet.crop((search_x0, search_y0, search_x1, search_y1))
    if region.mode != "RGBA":
        region = region.convert("RGBA")
    alpha = region.split()[-1]
    bbox = alpha.getbbox()
    if bbox is None:
        return None
    bx0, by0, bx1, by1 = bbox
    return (
        search_x0 + bx0,
        search_y0 + by0,
        search_x0 + bx1,
        search_y0 + by1,
    )


def pad_to_canvas(tight_crop: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Return a (target_w, target_h) RGBA image with `tight_crop` centered on
    a fully transparent background."""
    if tight_crop.mode != "RGBA":
        tight_crop = tight_crop.convert("RGBA")
    canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    cw, ch = tight_crop.size
    paste_x = (target_w - cw) // 2
    paste_y = (target_h - ch) // 2
    canvas.paste(tight_crop, (paste_x, paste_y), tight_crop)
    return canvas


def _print_debug(col_bounds, row_bounds, info):
    """Print derived bounds and residual error vs LEGACY_*_BOUNDS."""
    print()
    print("=== DERIVED BOUNDS (--debug) ===")
    print(f"sheet_size       = {info['sheet_size']}")
    print(f"col_runs detected= {info['col_runs_detected']}")
    print(f"row_runs detected= {info['row_runs_detected']}")
    print(f"card_width       = {info['card_width']} px")
    print(f"card_height      = {info['card_height']} px")
    print(f"column_gap       = {info['column_gap']:+.3f} px (pitch={info['col_pitch']:.3f})")
    print(f"row_gap          = {info['row_gap']:+.3f} px (pitch={info['row_pitch']:.3f})")
    print(f"col_first_center = {info['col_first_center']:.3f}")
    print(f"row_first_center = {info['row_first_center']:.3f}")

    def half_open_center(b):
        # PIL crop is half-open: (left, right_exclusive). Pixel center of the
        # cropped span at exclusive bound is (left + right - 1) / 2.
        return (b[0] + b[1] - 1) / 2.0

    print()
    print("Residual error vs LEGACY_COL_BOUNDS (new center minus old center):")
    for i in range(GRID_COLS):
        nc = half_open_center(col_bounds[i])
        oc = half_open_center(LEGACY_COL_BOUNDS[i])
        print(f"  col{i+1}: new=({col_bounds[i][0]:>4},{col_bounds[i][1]:>4}) "
              f"center={nc:7.2f}  legacy=({LEGACY_COL_BOUNDS[i][0]:>4},{LEGACY_COL_BOUNDS[i][1]:>4}) "
              f"center={oc:7.2f}  diff={nc-oc:+.2f}")
    print("Residual error vs LEGACY_ROW_BOUNDS:")
    for i in range(GRID_ROWS):
        nc = half_open_center(row_bounds[i])
        oc = half_open_center(LEGACY_ROW_BOUNDS[i])
        print(f"  row{i+1}: new=({row_bounds[i][0]:>4},{row_bounds[i][1]:>4}) "
              f"center={nc:7.2f}  legacy=({LEGACY_ROW_BOUNDS[i][0]:>4},{LEGACY_ROW_BOUNDS[i][1]:>4}) "
              f"center={oc:7.2f}  diff={nc-oc:+.2f}")
    print("================================")
    print()


def slice_sheet(sheet_path: Path, back_path: Path, output_root: Path, debug: bool = False) -> int:
    """Slice the sprite sheet into individual card files. Returns exit code."""
    if not sheet_path.exists():
        print(f"ERROR: sprite sheet not found: {sheet_path}", file=sys.stderr)
        return 1
    if not back_path.exists():
        print(f"ERROR: card back not found: {back_path}", file=sys.stderr)
        return 1
    if not output_root.exists():
        print(f"ERROR: output dir not found: {output_root}", file=sys.stderr)
        print("Run Session 17 first to create the .imageset folders.", file=sys.stderr)
        return 1

    sheet = Image.open(sheet_path)
    if sheet.mode != "RGBA":
        sheet = sheet.convert("RGBA")
    print(f"Loaded sprite sheet: {sheet.size}")

    col_bounds, row_bounds, debug_info = derive_uniform_bounds(sheet)
    if debug:
        _print_debug(col_bounds, row_bounds, debug_info)

    nominal_w = debug_info["card_width"]
    nominal_h = debug_info["card_height"]

    # --- Pass 1: detect per-card tight bboxes; sanity-check; gather sizes ---
    bboxes: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    sanity_failures: list[str] = []
    for (row, col), (suit, rank) in sorted(LAYOUT.items()):
        bbox = detect_card_bbox(sheet, row, col, col_bounds, row_bounds)
        if bbox is None:
            sanity_failures.append(
                f"card_{suit}_{rank} @ grid({row},{col}): "
                f"NO opaque pixels in search region (empty cell?)"
            )
            continue
        bx0, by0, bx1, by1 = bbox
        bw = bx1 - bx0
        bh = by1 - by0
        # Sanity: bbox dims must be within BBOX_SANITY_FRACTION of nominal
        dw = abs(bw - nominal_w) / float(nominal_w)
        dh = abs(bh - nominal_h) / float(nominal_h)
        if dw > BBOX_SANITY_FRACTION or dh > BBOX_SANITY_FRACTION:
            sanity_failures.append(
                f"card_{suit}_{rank} @ grid({row},{col}): "
                f"bbox {bw}x{bh} differs from nominal {nominal_w}x{nominal_h} "
                f"by ({dw*100:.1f}%, {dh*100:.1f}%)"
            )
        bboxes[(row, col)] = bbox

    if sanity_failures:
        print(file=sys.stderr)
        print("=== BBOX SANITY FAILURE — aborting before any writes ===", file=sys.stderr)
        for msg in sanity_failures:
            print(f"  {msg}", file=sys.stderr)
        return 2

    # Target canvas dims = max bbox width/height across all detected cards.
    max_bw = max(bx1 - bx0 for (bx0, _by0, bx1, _by1) in bboxes.values())
    max_bh = max(by1 - by0 for (_bx0, by0, _bx1, by1) in bboxes.values())
    target_w = max_bw
    target_h = max_bh

    # bbox stats for debug + end-of-session report
    widths = [bx1 - bx0 for (bx0, _by0, bx1, _by1) in bboxes.values()]
    heights = [by1 - by0 for (_bx0, by0, _bx1, by1) in bboxes.values()]
    off_grid_count = 0  # bboxes whose center differs from uniform nominal by > 5 px
    for (row, col), (bx0, by0, bx1, by1) in bboxes.items():
        cs, ce = col_bounds[col - 1]
        rs, re = row_bounds[row - 1]
        nominal_cx = (cs + ce - 1) / 2.0
        nominal_cy = (rs + re - 1) / 2.0
        bb_cx = (bx0 + bx1 - 1) / 2.0
        bb_cy = (by0 + by1 - 1) / 2.0
        if abs(bb_cx - nominal_cx) > 5 or abs(bb_cy - nominal_cy) > 5:
            off_grid_count += 1

    if debug:
        print("=== PER-CARD BBOX DETECTION (--debug) ===")
        print(f"target canvas    = {target_w} x {target_h}  (max of all detected bboxes)")
        print(f"bbox width  range= {min(widths)} .. {max(widths)}  (avg {sum(widths)/len(widths):.2f})")
        print(f"bbox height range= {min(heights)} .. {max(heights)}  (avg {sum(heights)/len(heights):.2f})")
        print(f"cards w/ center >5 px from uniform nominal: {off_grid_count} / {len(bboxes)}")
        print()
        print(f"{'card':<22} {'grid':<7} {'bbox (l,t,r,b)':<28} {'w':>4} {'h':>4} {'dx':>5} {'dy':>5}")
        for (row, col), (suit, rank) in sorted(LAYOUT.items()):
            if (row, col) not in bboxes:
                continue
            bx0, by0, bx1, by1 = bboxes[(row, col)]
            bw = bx1 - bx0
            bh = by1 - by0
            cs, ce = col_bounds[col - 1]
            rs, re = row_bounds[row - 1]
            dx = ((bx0 + bx1 - 1) / 2.0) - ((cs + ce - 1) / 2.0)
            dy = ((by0 + by1 - 1) / 2.0) - ((rs + re - 1) / 2.0)
            label = f"card_{suit}_{rank}"
            print(f"{label:<22} ({row},{col})   ({bx0:>4},{by0:>4},{bx1:>4},{by1:>4})  "
                  f"{bw:>4} {bh:>4} {dx:+5.1f} {dy:+5.1f}")
        print("=========================================")
        print()

    # --- Pass 2: tight-crop, pad to uniform canvas, save ---
    successes = 0
    skipped_imagesets = []
    for (row, col), (suit, rank) in sorted(LAYOUT.items()):
        bbox = bboxes.get((row, col))
        if bbox is None:
            continue  # already reported / impossible after sanity gate
        tight = sheet.crop(bbox)
        padded = pad_to_canvas(tight, target_w, target_h)

        filename = f"card_{suit}_{rank}.png"
        imageset_dir = output_root / f"card_{suit}_{rank}.imageset"

        if not imageset_dir.exists():
            skipped_imagesets.append(imageset_dir.name)
            continue

        out_path = imageset_dir / filename
        padded.save(out_path, "PNG", optimize=True)
        successes += 1
        print(f"  wrote {imageset_dir.name}/{filename}")

    # Card back
    back_imageset = output_root / "card_back.imageset"
    if back_imageset.exists():
        back_img = Image.open(back_path)
        back_img.save(back_imageset / "card_back.png", "PNG", optimize=True)
        successes += 1
        print(f"  wrote card_back.imageset/card_back.png")
    else:
        skipped_imagesets.append("card_back.imageset")

    # Report
    print()
    print(f"=== RESULTS ===")
    print(f"Successfully wrote: {successes} files")
    if skipped_imagesets:
        print(f"Skipped (imageset folder missing): {len(skipped_imagesets)}")
        for name in skipped_imagesets:
            print(f"  - {name}")
        print("These imagesets must exist before the script can populate them.")

    if MISSING_CARDS:
        print()
        print(f"=== KNOWN DESIGNER DELIVERY BUG ===")
        print(f"The following {len(MISSING_CARDS)} card(s) are MISSING from the sprite sheet:")
        for suit, rank in sorted(MISSING_CARDS):
            print(f"  - {rank} of {suit}  (asset name: card_{suit}_{rank}.png)")
        print()
        print("Designer must deliver corrected sheet OR individual file(s) for these.")
        print("Until then, affected .imageset folder(s) will still contain placeholder PNGs.")

    return 0 if successes >= 50 else 1


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--input", required=True, type=Path, help="Path to poker cards@4x 1.png")
    p.add_argument("--back", required=True, type=Path, help="Path to Card back.png")
    p.add_argument("--output", required=True, type=Path, help="Path to App/Assets.xcassets/Cards")
    p.add_argument("--debug", action="store_true",
                   help="Print derived card_width/card_height/gaps and residual error vs legacy bounds")
    args = p.parse_args()
    sys.exit(slice_sheet(args.input, args.back, args.output, debug=args.debug))


if __name__ == "__main__":
    main()
