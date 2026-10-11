"""Export original electronics SVG to PNG at 3x; development tooling only.

Python 3.13 / resvg-py==0.2.0; Arial installed on the export machine.
Run from repository root: python tools/render_electronics_assets.py
SVG originals are edited directly; no application dependency is added.
"""

from pathlib import Path
import xml.etree.ElementTree as ET

from resvg_py import svg_to_bytes

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/images/electronics"


def main():
    for source in sorted((OUTPUT / "source").glob("*.svg")):
        svg = ET.parse(source).getroot()
        width, height = (int(svg.attrib[key]) for key in ("width", "height"))
        svg.set("width", str(width * 3))
        svg.set("height", str(height * 3))
        (OUTPUT / f"{source.stem}.png").write_bytes(
            svg_to_bytes(svg_string=ET.tostring(svg, encoding="unicode"))
        )
        print(f"{source.stem}: {width * 3} x {height * 3}")


if __name__ == "__main__":
    main()
