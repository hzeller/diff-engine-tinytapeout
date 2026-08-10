#!/usr/bin/env python3
"""Fill VPR architecture timing from an icestorm/icetime timing database.

Parses the `CELL` blocks of a timings_<device>.txt dump (records like
`IOPATH in out rise-min:typ:max fall-min:typ:max`, picoseconds) and replaces
the @SPAN4_TDEL@/@SPAN12_TDEL@/@IPIN_TDEL@ markers:

  span4 segment mux  <- worst typ across Span4Mux* variants
  span12 segment mux <- worst typ across Span12Mux* variants
  ipin connection    <- LocalMux + InMux (typ), the local-track-to-input path

Also writes a report with every LogicCell40 record (LUT/FF/carry delays,
setup/hold) as reference material for the pb_type timing annotations.
"""

import argparse
import re
import sys

RECORD_RE = re.compile(
    r"^(IOPATH|SETUP|HOLD|RECOVERY|REMOVAL)\s+(\S+)\s+(\S+)\s+([-\d.:]+)(?:\s+([-\d.:]+))?"
)


def parse_db(path):
    cells = {}
    cell = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("CELL "):
                cell = line.split()[1]
                cells[cell] = []
            elif cell is not None:
                m = RECORD_RE.match(line)
                if m:
                    cells[cell].append(m.groups())
    return cells


def typ_ps(triple):
    """picoseconds 'min:typ:max' -> typ as float"""
    return float(triple.split(":")[1])


def worst_iopath_typ(cells, prefix):
    """Worst typical IOPATH delay (rise or fall) over cells matching prefix."""
    worst = None
    for name, records in cells.items():
        if not name.startswith(prefix):
            continue
        for kind, _src, _dst, rise, fall in records:
            if kind != "IOPATH":
                continue
            for triple in (rise, fall):
                if triple is None:
                    continue
                t = typ_ps(triple)
                worst = t if worst is None else max(worst, t)
    if worst is None:
        sys.exit(f"no IOPATH records found for cells matching {prefix!r}")
    return worst


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--timings", required=True, help="icetime db, e.g. timings_lp8k.txt")
    p.add_argument("--input", required=True, help="architecture XML with timing markers")
    p.add_argument("--output", required=True)
    p.add_argument("--report", help="write LogicCell40 timing reference here")
    args = p.parse_args()

    cells = parse_db(args.timings)

    span4 = worst_iopath_typ(cells, "Span4Mux")
    span12 = worst_iopath_typ(cells, "Span12Mux")
    ipin = worst_iopath_typ(cells, "LocalMux") + worst_iopath_typ(cells, "InMux")

    def sec(ps):
        return f"{ps * 1e-12:.3e}"

    with open(args.input) as f:
        xml = f.read()
    xml = (
        xml.replace("@SPAN4_TDEL@", sec(span4))
        .replace("@SPAN12_TDEL@", sec(span12))
        .replace("@IPIN_TDEL@", sec(ipin))
    )
    with open(args.output, "w") as f:
        f.write(xml)

    if args.report:
        with open(args.report, "w") as f:
            f.write(f"# extracted from {args.timings} (picoseconds, min:typ:max)\n")
            f.write(f"# routing numbers used in the arch:\n")
            f.write(f"#   span4 mux (worst typ):  {span4:.1f} ps\n")
            f.write(f"#   span12 mux (worst typ): {span12:.1f} ps\n")
            f.write(f"#   ipin (LocalMux+InMux):  {ipin:.1f} ps\n#\n")
            f.write("# LogicCell40 — reference for pb_type delay annotations:\n")
            for rec in cells.get("LogicCell40", []):
                kind, src, dst, rise, fall = rec
                f.write(f"{kind:9} {src:12} {dst:12} {rise}" + (f"  {fall}" if fall else "") + "\n")

    print(
        f"{args.output}: span4={span4:.1f}ps span12={span12:.1f}ps ipin={ipin:.1f}ps",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
