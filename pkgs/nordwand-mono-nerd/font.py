#!/usr/bin/env python3
"""Turn the upstream Nordwand Mono TTFs into Nerdwand Mono.

1. prepare:  slashed zero as the default `0`, and every ligature on by default.
2. patch:    nerd-font-patcher --complete --mono, one cell per icon.
3. finalize: undo --mono for the existing glyphs (it squeezes the two-cell
             ligatures) and set typographic names so all weights form one
             family, "Nerdwand Mono".

Usage: font.py <dir-with-ttfs> <output-dir>
"""

import glob
import os
import re
import subprocess
import sys
import tempfile

from fontTools.ttLib import TTFont

FAMILY = "Nerdwand Mono"
# Styles that Windows/fontconfig treat as first-class (name IDs 1+2).
RIBBI = {
    "Regular": "Regular",
    "Bold": "Bold",
    "Italic": "Italic",
    "BoldItalic": "Bold Italic",
}


def prepare(path):
    """Slashed zero, and the dlig joining forms enabled through `liga`."""
    font = TTFont(path)
    records = font["GSUB"].table.FeatureList.FeatureRecord
    liga = next(fr for fr in records if fr.FeatureTag == "liga")
    dlig = [fr for fr in records if fr.FeatureTag == "dlig"]
    assert dlig, f"{path}: no dlig feature"
    # HarfBuzz only applies its own default set, which excludes dlig/cvXX/ssXX:
    # upstream's joining forms for runs of =, -, _ and # are dead unless every
    # app opts in. Moving them into `liga` gets them everywhere.
    liga.Feature.LookupListIndex += sorted(
        {i for fr in dlig for i in fr.Feature.LookupListIndex}
    )
    assert "zero_slashed" in font["glyf"], f"{path}: no zero_slashed"
    font["glyf"]["zero"] = font["glyf"]["zero_slashed"]
    font["hmtx"]["zero"] = font["hmtx"]["zero_slashed"]
    font.save(path)


def patch(patcher, path, output_dir):
    style = os.path.basename(path).split("-", 1)[1].removesuffix(".ttf")
    # "SemiBoldItalic" -> "SemiBold Italic", so the patcher parses the style.
    spaced = re.sub(r"(?<=[a-z])(?=Italic)", " ", style)
    subprocess.run(
        [
            patcher,
            "--complete",
            "--careful",
            "--mono",
            "--quiet",
            "--no-progressbars",
            "--name",
            f"{FAMILY} {spaced}",
            "--outputdir",
            output_dir,
            path,
        ],
        check=True,
    )
    produced = glob.glob(os.path.join(output_dir, "*.ttf"))
    assert len(produced) == 1, f"{style}: expected one patched font, got {produced}"
    return style, produced[0]


def finalize(style, source, patched, out_path):
    font = TTFont(patched)
    italic = style.endswith("Italic")
    weight = style[: -len("Italic")] if italic else style
    subfamily = (weight + " Italic").strip() if italic else weight
    # --mono forces every existing glyph into one cell, squeezing the two-cell
    # ligatures and widening zero-width marks; only added icons should be 1 cell.
    for name, (advance, _) in TTFont(source)["hmtx"].metrics.items():
        if name in font["hmtx"].metrics:
            font["hmtx"][name] = (advance, font["hmtx"][name][1])
    assert 0xE0B0 in font.getBestCmap(), f"{style}: no nerd icons"
    names = {
        # legacy pair: a non-RIBBI style is folded into the family name
        1: FAMILY if style in RIBBI else f"{FAMILY} {subfamily}",
        2: RIBBI.get(style, "Regular"),
        4: f"{FAMILY} {subfamily}",
        6: f"NerdwandMono-{style}",
        # typographic family/style: one family, every weight as a style
        16: FAMILY,
        17: subfamily,
    }
    for name_id, value in names.items():
        for platform, encoding, lang in ((1, 0, 0), (3, 1, 0x409)):
            font["name"].setName(value, name_id, platform, encoding, lang)
    font.save(out_path)


def main():
    src, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(src, "*.ttf"))):
        prepare(path)
        with tempfile.TemporaryDirectory(dir=out) as work:
            style, patched = patch("nerd-font-patcher", path, work)
            finalize(style, path, patched, os.path.join(out, f"NerdwandMono-{style}.ttf"))


if __name__ == "__main__":
    main()
