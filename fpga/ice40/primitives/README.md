# Vendored iCE40 VPR primitives

Leaf-cell `pb_type`/`model` fragments from
[f4pga-arch-defs](https://github.com/f4pga/f4pga-arch-defs)
(`lattice/ice40/primitives/`, master @ `3d4df2ea79dc`, ISC license).

These are the building blocks (LUT4, FF variants, carry, io pad); the PLB
composition and tile definitions are written here, not vendored. Upstream's
own composition lives in `lattice/ice40/cells/plb` — treat it as the answer
key, not the starting point. `mux2`/`mux4` have no static XML upstream
(generated at build time); write them inline where needed.
