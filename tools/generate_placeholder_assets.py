#!/usr/bin/env python3
"""
Session 17 — Asset Pipeline Prep.

One-shot generator for the placeholder card / chip / stack imagesets that
will be replaced verbatim when the Fiverr designer's Phase 1 PNGs land.

Each imageset gets:
  - Contents.json with a `filename` field pointing to the expected
    Phase-1 designer filename (e.g., card_hearts_ace.png).
  - A 24x24 solid-color PNG at that filename so Xcode's asset-catalog
    compiler doesn't choke on a missing-image reference.

Designer drop-in: replace each placeholder PNG with the real one
(same filename) and the app picks it up with no code changes.

Re-running this script is idempotent — existing imagesets are
overwritten in place. Real designer PNGs that have already replaced
placeholders WILL be clobbered, so this is a one-shot tool, not a
build step.
"""

import json
import os
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_CATALOG = ROOT / "App" / "Assets.xcassets"

# ---- PNG generation -------------------------------------------------------

def png_bytes(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    """Hand-rolled minimal PNG (no PIL dependency). Solid color, 8-bit RGB."""
    sig = b"\x89PNG\r\n\x1a\n"

    def chunk(name: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(name + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", crc)

    # IHDR: width, height, bit depth (8), color type (2 = RGB), compression, filter, interlace
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)

    # IDAT: each row is a filter byte (0x00 = none) followed by RGB triples
    row = b"\x00" + bytes(rgb) * width
    raw = row * height
    idat = zlib.compress(raw, level=9)

    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


CONTENTS_JSON_TEMPLATE = {
    "images": [
        {"idiom": "universal", "filename": None, "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def write_imageset(dirpath: Path, filename: str, rgb: tuple[int, int, int]) -> None:
    dirpath.mkdir(parents=True, exist_ok=True)
    (dirpath / filename).write_bytes(png_bytes(24, 24, rgb))

    contents = {
        "images": [
            {"idiom": "universal", "filename": filename, "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (dirpath / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n"
    )


# ---- Slot definitions -----------------------------------------------------

SUITS = ["hearts", "diamonds", "clubs", "spades"]
RANKS_NUMERIC = ["2", "3", "4", "5", "6", "7", "8", "9", "10"]
RANKS_FACE = ["jack", "queen", "king", "ace"]
RANKS = RANKS_NUMERIC + RANKS_FACE

# Distinct colors per suit so placeholders are visually distinguishable
# during simulator runs (red hearts/diamonds, dark clubs/spades).
SUIT_COLORS = {
    "hearts":   (180, 40, 40),
    "diamonds": (200, 60, 60),
    "clubs":    (40, 40, 40),
    "spades":   (20, 20, 20),
}

# Casino-convention chip colors: red $5, green $25, black $100,
# purple $500, yellow $1000.
CHIP_COLORS = {
    5:    (200, 30, 30),
    25:   (30, 140, 65),
    100:  (30, 30, 30),
    500:  (115, 40, 140),
    1000: (240, 190, 50),
}

STACK_HEIGHTS = [1, 3, 5, 10, 20]


# ---- Generator entry ------------------------------------------------------

def generate() -> int:
    if not ASSET_CATALOG.exists():
        print(f"error: {ASSET_CATALOG} not found", file=sys.stderr)
        return 1

    cards_dir = ASSET_CATALOG / "Cards"
    chips_dir = ASSET_CATALOG / "Chips"
    stacks_dir = ASSET_CATALOG / "ChipStacks"

    # Folder Contents.json files (the asset catalog needs these for groups).
    folder_contents = {
        "info": {"author": "xcode", "version": 1},
        "properties": {"provides-namespace": False},
    }
    for folder in [cards_dir, chips_dir, stacks_dir]:
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "Contents.json").write_text(
            json.dumps(folder_contents, indent=2) + "\n"
        )

    # Cards: 52 + 1 back
    for suit in SUITS:
        rgb = SUIT_COLORS[suit]
        for rank in RANKS:
            name = f"card_{suit}_{rank}"
            write_imageset(cards_dir / f"{name}.imageset", f"{name}.png", rgb)

    write_imageset(cards_dir / "card_back.imageset", "card_back.png", (40, 60, 110))

    # Chips
    for denom, rgb in CHIP_COLORS.items():
        name = f"chip_{denom}"
        write_imageset(chips_dir / f"{name}.imageset", f"{name}.png", rgb)

    # Stacks: 5 denominations x 5 heights
    for denom, rgb in CHIP_COLORS.items():
        for height in STACK_HEIGHTS:
            name = f"stack_{denom}_h{height}"
            write_imageset(stacks_dir / f"{name}.imageset", f"{name}.png", rgb)

    # Summary
    cards = sum(1 for _ in cards_dir.glob("*.imageset"))
    chips = sum(1 for _ in chips_dir.glob("*.imageset"))
    stacks = sum(1 for _ in stacks_dir.glob("*.imageset"))
    print(f"Cards: {cards}, Chips: {chips}, Stacks: {stacks}")
    return 0


if __name__ == "__main__":
    sys.exit(generate())
