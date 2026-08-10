# iCE40 leg: derive a VPR architecture for the LP8K (TinyFPGA-BX) from the
# icestorm chipdb. Enter with `nix develop .#ice40`, then `make` here.
{ ... }:
{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells.ice40 = pkgs.mkShell {
        packages = [
          self'.packages.vtr
          pkgs.icestorm
          pkgs.python3
          # Generic LUT4 synthesis for the milestone-1 smoke test.
          pkgs.yosys
        ];
        ICESTORM = "${pkgs.icestorm}";
      };
    };
}
