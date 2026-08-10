#!/usr/bin/env python3
"""Generate a VPR architecture file for an iCE40 device from an icebox chipdb.

Reads the tile grid declarations (.io_tile/.logic_tile/.ramb_tile/...) from an
icestorm chipdb dump and expands the @WIDTH@/@HEIGHT@/@LAYOUT@ markers in the
XML template.

Milestone 1: only IO and logic tiles are placed; RAM/DSP/IPCON positions are
left EMPTY (VPR's default for unspecified grid locations).
"""

import argparse
import re
import sys

TILE_RE = re.compile(r"^\.(io|logic|ramb|ramt|dsp\d|ipcon)_tile\s+(\d+)\s+(\d+)")

# icebox tile kind -> VPR tile name (everything else becomes EMPTY).
TYPE_MAP = {
    "io": "io",
    "logic": "plb",
}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--chipdb", required=True, help="icebox chipdb dump (e.g. chipdb-8k.txt)")
    p.add_argument("--template", required=True, help="architecture XML template")
    p.add_argument("--output", required=True, help="output architecture XML")
    args = p.parse_args()

    tiles = {}
    with open(args.chipdb) as f:
        for line in f:
            m = TILE_RE.match(line)
            if m:
                key = (int(m.group(2)), int(m.group(3)))
                kind = m.group(1)
                if key in tiles and tiles[key] != kind:
                    print(f"warning: {key} declared as both {tiles[key]} and {kind}; keeping {kind}", file=sys.stderr)
                tiles[key] = kind

    if not tiles:
        sys.exit(f"no tile declarations found in {args.chipdb}")

    width = max(x for x, _ in tiles) + 1
    height = max(y for _, y in tiles) + 1

    singles = []
    counts = {}
    for (x, y), kind in sorted(tiles.items()):
        vpr_type = TYPE_MAP.get(kind, "EMPTY")
        counts[vpr_type] = counts.get(vpr_type, 0) + 1
        if vpr_type != "EMPTY":
            singles.append(f'      <single type="{vpr_type}" x="{x}" y="{y}" priority="10"/>')

    with open(args.template) as f:
        template = f.read()
    out = (
        template.replace("@WIDTH@", str(width))
        .replace("@HEIGHT@", str(height))
        .replace("@LAYOUT@", "\n".join(singles))
    )
    with open(args.output, "w") as f:
        f.write(out)

    summary = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    print(f"{args.output}: grid {width}x{height}, {summary}", file=sys.stderr)


if __name__ == "__main__":
    main()
