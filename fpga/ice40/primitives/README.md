# Vendored iCE40 VPR primitives

Leaf-cell `pb_type`/`model` fragments from
[f4pga-arch-defs](https://github.com/f4pga/f4pga-arch-defs)
(`lattice/ice40/primitives/`, master @ `3d4df2ea79dc`, ISC license).

These are the building blocks (LUT4, FF variants, carry, io pad); the PLB
composition and tile definitions are written here, not vendored. Upstream's
own composition lives in `lattice/ice40/cells/plb` — treat it as the answer
key, not the starting point. `mux2`/`mux4` have no static XML upstream
(generated at build time); write them inline where needed.

## Audit (against yosys ice40/cells_sim.v, the silicon-validated models)

- sb_ff: all 20 SB_DFF* variants present, names and family match 1:1.
- sb_carry: ports/logic exact match; its delay_constants are 10ps
  PLACEHOLDERS — real LP8K numbers are in ../timing-report.txt.
- sb_lut: structurally sound (the "LUT mode first" comment is a real VPR
  routing constraint, keep it).
- Timing annotations throughout are generic/unverified: replace with the
  icetime-derived numbers during composition.
- Upstream's open carry-chain issue (f4pga-arch-defs#140) concerns the
  packing/composition layer, not these leaves — relevant to OUR plb work
  (chain pack_patterns are the hard part), not to the vendored files.
