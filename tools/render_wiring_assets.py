"""Export authored SVG sources to PNG; no Flutter/runtime dependencies.

Tooling: Python 3.13, resvg-py==0.2.0. Arial must be available locally.
SVG files are the editable source of truth; never regenerate them from PNG.
Run from the repository root: python tools/render_wiring_assets.py
"""

from pathlib import Path
import xml.etree.ElementTree as ET

from resvg_py import svg_to_bytes


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/images/wiring/source"
OUTPUT = ROOT / "assets/images/wiring"


def main():
    for source in sorted(SOURCE.glob("*.svg")):
        svg = ET.parse(source).getroot()
        width, height = (int(svg.attrib[key]) for key in ("width", "height"))
        # resvg-py 0.2.0 width/height options scale drawing but leave the native
        # canvas size intact. Scale the root viewport while preserving viewBox.
        svg.set("width", str(width * 3))
        svg.set("height", str(height * 3))
        png = bytes(svg_to_bytes(svg_string=ET.tostring(svg, encoding="unicode")))
        target = OUTPUT / f"{source.stem}.png"
        target.write_bytes(png)
        print(f"{target.relative_to(ROOT)}: {width * 3} x {height * 3}")


if __name__ == "__main__":
    main()
